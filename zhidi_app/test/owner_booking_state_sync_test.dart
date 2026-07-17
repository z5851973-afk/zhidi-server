import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';

void main() {
  test(
    'bookWorker creates remote booking before local booking for server worker',
    () async {
      final sessionStore = MemoryAuthSessionStore(_session());
      final bookingApi = _FakeOwnerBookingApi();
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: sessionStore,
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: bookingApi,
      );
      bookingApi.tokens.clear();
      bookingApi.requests.clear();

      await state.bookWorker(
        _worker(id: 'remote-worker-user-id'),
        remoteWorkerUserId: 'remote-worker-user-id',
        serviceCity: '杭州',
      );

      expect(bookingApi.tokens, ['jwt-token']);
      expect(bookingApi.requests, hasLength(1));
      expect(bookingApi.requests.single.workerUserId, 'remote-worker-user-id');
      expect(bookingApi.requests.single.trade, '泥工师傅');
      expect(bookingApi.requests.single.serviceCity, '杭州');
      expect(bookingApi.requests.single.remark, '来自安卓业主端');
      final booked = state.bookedWorkers.firstWhere(
        (worker) => worker.id == 'remote-worker-user-id',
      );
      expect(booked.name, '周师傅');
      expect(
        state.appointments.any(
          (appointment) => appointment.workerName == '周师傅',
        ),
        isTrue,
      );
    },
  );

  test(
    'bookWorker keeps local-only booking path when server worker id is absent',
    () async {
      final bookingApi = _FakeOwnerBookingApi();
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: bookingApi,
      );

      await state.bookWorker(_worker(id: 'mock-worker-1'));

      expect(bookingApi.requests, isEmpty);
      expect(
        state.bookedWorkers.any((worker) => worker.id == 'mock-worker-1'),
        isTrue,
      );
    },
  );

  test(
    'fetchRemoteBookings adds owner message when remote booking is accepted',
    () async {
      final bookingApi = _FakeOwnerBookingApi()
        ..remoteBookings = [
          RemoteOwnerBooking(
            id: 'remote-booking-accepted',
            ownerUserId: 'owner-user-id',
            workerUserId: 'worker-user-id',
            workerName: '模拟器闭环工人',
            trade: '水电',
            serviceCity: '成都',
            serviceAddress: 'Android Studio 模拟器小区 2 栋 202',
            remark: '第二次模拟器 UI 点击接单验证。',
            status: 'ACCEPTED',
            createdAt: DateTime.utc(2026, 7, 16, 9, 42),
            updatedAt: DateTime.utc(2026, 7, 16, 9, 43),
          ),
        ];
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: bookingApi,
      );

      await state.fetchRemoteBookings();
      await state.fetchRemoteBookings();

      expect(
        state.appointments
            .singleWhere(
              (appointment) => appointment.id == 'rm-remote-booking-accepted',
            )
            .status,
        '已确认',
      );
      final feedbackMessages = state.messages.where(
        (message) =>
            message.id == 'msg-remote-booking-accepted-remote-booking-accepted',
      );
      expect(feedbackMessages, hasLength(1));
      expect(feedbackMessages.single.title, '工人已接单');
      expect(feedbackMessages.single.category, '预约');
      expect(feedbackMessages.single.isRead, isFalse);
      expect(feedbackMessages.single.content, contains('模拟器闭环工人'));
      expect(feedbackMessages.single.content, contains('水电'));
      expect(
        feedbackMessages.single.content,
        contains('Android Studio 模拟器小区 2 栋 202'),
      );
    },
  );
}

BookedWorker _worker({required String id}) => BookedWorker(
  id: id,
  name: '周师傅',
  trade: '泥工师傅',
  phaseName: '泥工',
  phaseIndex: 3,
  rating: 4.8,
  completedOrders: 20,
  years: 8,
  avatarEmoji: '🧱',
  skills: const ['贴砖'],
);

AuthSession _session() => AuthSession(
  accessToken: 'jwt-token',
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(const Duration(days: 1)),
  userId: 'owner-user-id',
  phone: '13800138000',
  roles: const ['OWNER'],
);

final class _FakeOwnerBookingApi implements OwnerBookingApi {
  final tokens = <String>[];
  final requests = <OwnerBookingCreateRequest>[];
  List<RemoteOwnerBooking> remoteBookings = const [];

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) async {
    tokens.add(accessToken);
    requests.add(request);
    return RemoteOwnerBooking(
      id: 'booking-1',
      ownerUserId: 'owner-user-id',
      workerUserId: request.workerUserId,
      workerName: '周师傅',
      trade: request.trade ?? '泥工师傅',
      serviceCity: request.serviceCity ?? '杭州',
      serviceAddress: request.serviceAddress,
      remark: request.remark,
      status: 'PENDING',
      createdAt: DateTime.utc(2026, 7, 15, 10),
      updatedAt: DateTime.utc(2026, 7, 15, 10),
    );
  }

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(String accessToken) async {
    tokens.add(accessToken);
    return remoteBookings;
  }

  @override
  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
  ) async {
    tokens.add(accessToken);
    return RemoteOwnerBooking(
      id: bookingId,
      ownerUserId: 'owner-user-id',
      workerUserId: 'worker-1',
      workerName: '周师傅',
      trade: '泥工师傅',
      serviceCity: '杭州',
      serviceAddress: null,
      remark: null,
      status: 'CANCELLED',
      createdAt: DateTime.utc(2026, 7, 15, 10),
      updatedAt: DateTime.utc(2026, 7, 15, 11),
    );
  }
}

final class _FakeOwnerProfileApi implements OwnerProfileApi {
  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async =>
      const RemoteOwnerProfile(
        userId: 'owner-user-id',
        phone: '13800138000',
        name: '王先生',
        city: '成都',
        decorationType: '旧房翻新',
        address: '杭州市西湖区测试路 1 号',
        area: 88,
        profileComplete: true,
      );

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) async => RemoteOwnerProfile(
    userId: 'owner-user-id',
    phone: '13800138000',
    name: request.name,
    city: request.city,
    decorationType: request.decorationType,
    address: request.address,
    area: request.area,
    profileComplete: true,
  );
}
