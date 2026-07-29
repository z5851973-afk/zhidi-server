import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/models/renovation.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/worker_booking_api_client.dart';

void main() {
  test(
    'worker online login stores secure session and logout clears it',
    () async {
      final sessions = MemoryAuthSessionStore();
      final state = await WorkerAppState.memory(sessionStore: sessions);
      const response = OwnerLoginResponse(
        accessToken: 'worker-jwt',
        tokenType: 'Bearer',
        expiresInSeconds: 3600,
        user: AuthUser(
          id: 'worker-id',
          phone: '13800138102',
          status: 'ACTIVE',
          roles: ['WORKER'],
        ),
      );

      await state.loginOnline(response);

      expect(state.isLoggedIn, isTrue);
      expect((await sessions.read())?.accessToken, 'worker-jwt');
      expect(state.toJson(), isNot(contains('accessToken')));

      await state.logout();

      expect(state.isLoggedIn, isFalse);
      expect(await sessions.read(), isNull);
    },
  );

  test('restoring worker session refreshes complete remote profile', () async {
    final sessions = MemoryAuthSessionStore();
    final state = await WorkerAppState.memory(sessionStore: sessions);
    await state.loginOnline(_loginResponse);
    await state.logout();
    await sessions.save(AuthSession.fromLogin(_loginResponse));

    final restored = await state.restoreOnlineSession(
      api: _RecordingWorkerProfileApi(
        remoteProfile: const RemoteWorkerProfile(
          phone: '13800138102',
          name: '模拟器闭环木工',
          serviceCity: '成都',
          primaryTrade: 'carpentry',
          experienceYears: 8,
          dailyRate: 500,
          bio: '擅长全屋定制和柜体安装',
          profileComplete: true,
        ),
      ),
    );

    expect(restored, isTrue);
    expect(state.isLoggedIn, isTrue);
    expect(state.profile.name, '模拟器闭环木工');
    expect(state.profile.trade, Trade.carpentry);
    expect(state.profile.isProfileComplete, isTrue);
  });

  test(
    'worker profile is persisted remotely before local state changes',
    () async {
      final sessions = MemoryAuthSessionStore();
      final state = await WorkerAppState.memory(sessionStore: sessions);
      final api = _RecordingWorkerProfileApi();
      await state.loginOnline(_loginResponse);
      final next = state.profile.copyWith(
        name: '张师傅',
        serviceCity: '成都',
        trade: Trade.plumbing,
        tradeSelected: true,
        experienceYears: 8,
        dailyRate: 500,
        bio: '擅长旧房水电改造',
      );

      await state.updateProfile(next, api: api);

      expect(api.updatedBody, {
        'name': '张师傅',
        'serviceCity': '成都',
        'primaryTrade': Trade.plumbing.name,
        'experienceYears': 8,
        'dailyRate': 500.0,
        'bio': '擅长旧房水电改造',
      });
      expect(state.profile.isProfileComplete, isTrue);
      expect(state.profile.name, '张师傅');
    },
  );

  test('failed remote profile save leaves local profile unchanged', () async {
    final state = await WorkerAppState.memory();
    await state.loginOnline(_loginResponse);
    final before = state.profile;

    await expectLater(
      state.updateProfile(
        before.copyWith(name: '不应保存'),
        api: _RecordingWorkerProfileApi(failUpdate: true),
      ),
      throwsA(isA<AuthApiException>()),
    );

    expect(state.profile.name, before.name);
  });

  test(
    'local persistence mutations preserve the active server session',
    () async {
      final state = await WorkerAppState.memory();
      await state.loginOnline(_loginResponse);

      await state.updateSettings(
        state.settings.copyWith(acceptOrders: !state.settings.acceptOrders),
      );

      expect(state.accessToken, _loginResponse.accessToken);
      expect(state.isLoggedIn, isTrue);
    },
  );

  test(
    'remote booking trade is displayed as Chinese worker order trade',
    () async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');

      state.initBookingApi(
        api: _FakeWorkerBookingApi([
          RemoteWorkerBooking(
            id: 'booking-1',
            ownerUserId: 'owner-1',
            ownerName: '业主',
            ownerPhone: '13800000000',
            serviceRequestId: 'request-1',
            workerUserId: 'worker-1',
            workerName: '模拟器闭环木工',
            trade: 'carpentry',
            serviceCity: '成都',
            serviceAddress: 'Android Studio 模拟器小区',
            status: 'ACCEPTED',
            createdAt: DateTime.utc(2026, 7, 18),
            updatedAt: DateTime.utc(2026, 7, 18),
          ),
        ]),
        accessToken: 'worker-jwt',
      );
      await state.fetchRemoteBookings();

      expect(state.remoteBookings.single.trade, 'carpentry');
      expect(state.orders.single.trade, '木工');
      expect(state.orders.single.requirement, '木工师傅');
    },
  );

  test(
    'new remote pending booking creates one unread worker message',
    () async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final api = _FakeWorkerBookingApi([]);
      state.initBookingApi(api: api, accessToken: 'worker-jwt');
      await state.fetchRemoteBookings();

      api.bookings = [
        RemoteWorkerBooking(
          id: 'booking-new',
          ownerUserId: 'owner-1',
          ownerName: 'kkkkk',
          ownerPhone: '13555555555',
          serviceRequestId: 'request-1',
          workerUserId: 'worker-gt',
          workerName: 'GT',
          trade: 'plumbing',
          serviceCity: '成都',
          serviceAddress: 'fghfdg',
          status: 'PENDING',
          createdAt: DateTime.utc(2026, 7, 18),
          updatedAt: DateTime.utc(2026, 7, 18),
        ),
      ];

      await state.fetchRemoteBookings();
      await state.fetchRemoteBookings();

      expect(state.pendingOrders.single.id, 'booking-new');
      expect(
        state.messages.where((m) => m.orderId == 'booking-new'),
        hasLength(1),
      );
      expect(state.messages.single.title, '新的预约待接单');
      expect(state.messages.single.isRead, isFalse);
    },
  );

  test(
    'concurrent remote booking refresh does not duplicate new order message',
    () async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final api = _FakeWorkerBookingApi([
        RemoteWorkerBooking(
          id: 'booking-race',
          ownerUserId: 'owner-1',
          ownerName: '业主',
          ownerPhone: '13800000000',
          serviceRequestId: 'request-1',
          workerUserId: 'worker-1',
          workerName: 'GT',
          trade: 'plumbing',
          serviceCity: '成都',
          serviceAddress: 'fghfdg',
          status: 'PENDING',
          createdAt: DateTime.utc(2026, 7, 18),
          updatedAt: DateTime.utc(2026, 7, 18),
        ),
      ], delay: const Duration(milliseconds: 10));
      state.initBookingApi(api: api, accessToken: 'worker-jwt');

      await Future.wait([
        state.fetchRemoteBookings(),
        state.fetchRemoteBookings(),
      ]);

      expect(
        state.messages.where((m) => m.orderId == 'booking-race'),
        hasLength(1),
      );
    },
  );

  test('remote booking refresh replaces stale local order state', () async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _FakeWorkerBookingApi([
      RemoteWorkerBooking(
        id: 'booking-1',
        ownerUserId: 'owner-1',
        ownerName: '业主',
        ownerPhone: '13800000000',
        serviceRequestId: 'request-1',
        workerUserId: 'worker-1',
        workerName: '模拟器闭环木工',
        trade: 'carpentry',
        serviceCity: '成都',
        serviceAddress: 'Android Studio 模拟器小区',
        status: 'ACCEPTED',
        createdAt: DateTime.utc(2026, 7, 18),
        updatedAt: DateTime.utc(2026, 7, 18),
      ),
    ]);
    state.initBookingApi(api: api, accessToken: 'worker-jwt');
    await state.fetchRemoteBookings();

    final proposedTime = DateTime.utc(2026, 7, 19, 1);
    api.bookings = [
      RemoteWorkerBooking(
        id: 'booking-1',
        ownerUserId: 'owner-1',
        ownerName: '业主',
        ownerPhone: '13800000000',
        serviceRequestId: 'request-1',
        workerUserId: 'worker-1',
        workerName: '模拟器闭环木工',
        trade: 'carpentry',
        serviceCity: '成都',
        serviceAddress: 'Android Studio 模拟器小区',
        status: 'VISIT_SCHEDULED',
        proposedTime: proposedTime,
        createdAt: DateTime.utc(2026, 7, 18),
        updatedAt: DateTime.utc(2026, 7, 18, 1),
      ),
    ];

    await state.fetchRemoteBookings();

    expect(state.orders.single.status, WorkerOrderStatus.visitScheduled);
    expect(state.orders.single.proposedTime, proposedTime);
    expect(state.activeOrders.single.status, WorkerOrderStatus.visitScheduled);
  });

  test('arrival pending status label tells worker confirmation is pending', () {
    final order = WorkerOrder(
      id: 'booking-1',
      ownerName: '业主',
      ownerPhone: '13800000000',
      ownerAddress: '成都 1 栋 101',
      area: '80㎡',
      requirement: '木工师傅',
      description: '柜体安装',
      trade: '木工',
      status: WorkerOrderStatus.arrivalPending,
      arrivalConfirmedByWorker: true,
      arrivalConfirmedByOwner: false,
    );

    expect(order.statusLabel, '等待到场确认');
  });

  test(
    'server terminal and ready statuses never become pending orders',
    () async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final now = DateTime.utc(2026, 7, 22);
      state.initBookingApi(
        api: _FakeWorkerBookingApi([
          for (final entry in const {
            'not-selected': 'NOT_SELECTED',
            'rejected': 'REJECTED',
            'cancelled': 'CANCELLED',
            'ready': 'READY_TO_START',
          }.entries)
            RemoteWorkerBooking(
              id: entry.key,
              ownerUserId: 'owner-1',
              ownerName: '业主',
              ownerPhone: '13800000000',
              serviceRequestId: 'request-1',
              workerUserId: 'worker-1',
              workerName: '张师傅',
              trade: 'plumbing',
              serviceCity: '成都',
              status: entry.value,
              createdAt: now,
              updatedAt: now,
            ),
        ]),
        accessToken: 'worker-jwt',
      );

      await state.fetchRemoteBookings();

      expect(state.pendingOrders, isEmpty);
      expect(
        state.orders.firstWhere((order) => order.id == 'not-selected').status,
        WorkerOrderStatus.cancelled,
      );
      expect(
        state.orders.firstWhere((order) => order.id == 'ready').status,
        WorkerOrderStatus.hired,
      );
    },
  );
}

const _loginResponse = OwnerLoginResponse(
  accessToken: 'worker-jwt',
  tokenType: 'Bearer',
  expiresInSeconds: 3600,
  user: AuthUser(
    id: 'worker-id',
    phone: '13800138102',
    status: 'ACTIVE',
    roles: ['WORKER'],
  ),
);

final class _RecordingWorkerProfileApi implements OwnerAuthApi {
  _RecordingWorkerProfileApi({this.failUpdate = false, this.remoteProfile});

  final bool failUpdate;
  final RemoteWorkerProfile? remoteProfile;
  Map<String, dynamic>? updatedBody;

  @override
  Future<void> updateWorkerProfile(
    String token,
    Map<String, dynamic> body,
  ) async {
    if (failUpdate) {
      throw const AuthApiException(code: 'UPDATE_FAILED', message: '更新资料失败');
    }
    updatedBody = Map<String, dynamic>.from(body);
  }

  @override
  Future<RemoteWorkerProfile> getWorkerProfile(String token) async =>
      remoteProfile ??
      const RemoteWorkerProfile(
        phone: '13800138102',
        name: '张师傅',
        serviceCity: '成都',
        primaryTrade: 'plumber',
        experienceYears: 8,
        dailyRate: 500,
        bio: '擅长旧房水电改造',
        profileComplete: true,
      );

  @override
  Future<OwnerLoginResponse> loginOwner(String phone, String code) =>
      throw UnimplementedError();

  @override
  Future<OwnerLoginResponse> loginWorker(String phone, String code) =>
      throw UnimplementedError();

  @override
  Future<SmsCodeResponse> requestSmsCode(String phone) =>
      throw UnimplementedError();
}

final class _FakeWorkerBookingApi implements WorkerBookingApi {
  _FakeWorkerBookingApi(this.bookings, {this.delay = Duration.zero});

  List<RemoteWorkerBooking> bookings;
  final Duration delay;

  @override
  Future<List<RemoteWorkerBooking>> listWorkerBookings(
    String accessToken,
  ) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    return bookings;
  }

  @override
  Future<RemoteWorkerBooking> acceptBooking(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteWorkerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();

  @override
  Future<RemoteWorkerBooking> rejectBooking(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();
}
