import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/renovation/trade_select_page.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';
import 'package:zhidi_app/services/service_request_api_client.dart';
import 'package:zhidi_app/services/worker_directory_api_client.dart';

void main() {
  testWidgets('trade cards show renovation sequence badges in process order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: TradeSelectPage()));
    await tester.pumpAndSettle();

    expect(find.text('拆除师傅'), findsOneWidget);
    expect(find.text('水电师傅'), findsOneWidget);
    expect(find.text('防水师傅'), findsOneWidget);
    expect(find.text('泥瓦师傅'), findsOneWidget);
    expect(find.text('第一步'), findsOneWidget);
    expect(find.text('第二步'), findsOneWidget);
    expect(find.text('第三步'), findsOneWidget);
    expect(find.text('第四步'), findsOneWidget);
    expect(find.text('报价'), findsOneWidget);
    expect(find.text('第五步'), findsOneWidget);
    expect(find.text('第六步'), findsOneWidget);
    expect(find.text('第七步'), findsOneWidget);
    expect(find.text('第八步'), findsOneWidget);
  });

  testWidgets('trade cards show owner-led availability copy from remote counts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: TradeSelectPage(workerDirectoryApi: _FakeWorkerDirectoryApi()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1位可预约'), findsWidgets);
    expect(find.text('暂无可约 · 先看工价'), findsWidgets);
    expect(find.text('看资料、看案例、看工价，自己选师傅'), findsOneWidget);
  });

  testWidgets('trade selection creates service request with owner city', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = await OwnerAppState.memory(
      store: MemoryOwnerStore(),
      sessionStore: MemoryAuthSessionStore(_ownerSession()),
      profileApi: _FakeOwnerProfileApi(),
      bookingApi: _NoopOwnerBookingApi(),
    );
    final serviceApi = _RecordingServiceRequestApi();

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: TradeSelectPage(
            workerDirectoryApi: _FakeWorkerDirectoryApi(),
            serviceRequestApi: serviceApi,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('木工师傅'));
    await tester.tap(find.text('木工师傅'));
    await tester.pumpAndSettle();

    expect(serviceApi.createdDraft?.trade, 'carpentry');
    expect(serviceApi.createdDraft?.serviceCity, '成都');
  });
}

final class _FakeWorkerDirectoryApi implements WorkerDirectoryApi {
  @override
  Future<List<RemoteWorkerDirectoryProfile>> listWorkers() async => const [
    RemoteWorkerDirectoryProfile(
      userId: 'worker-carpentry',
      name: '模拟器闭环木工',
      serviceCity: '成都',
      primaryTrade: 'carpentry',
      experienceYears: 8,
      dailyRate: 500,
      bio: '擅长全屋定制',
    ),
    RemoteWorkerDirectoryProfile(
      userId: 'worker-plumbing',
      name: '模拟器闭环水电',
      serviceCity: '成都',
      primaryTrade: 'plumbing',
      experienceYears: 6,
      dailyRate: 500,
      bio: '擅长旧房水电',
    ),
  ];

  @override
  Future<RemoteWorkerDirectoryProfile> getWorker(String userId) =>
      throw UnimplementedError();
}

final class _RecordingServiceRequestApi implements ServiceRequestApi {
  ServiceRequestDraft? createdDraft;

  @override
  Future<RemoteServiceRequest> createRequest(
    String accessToken,
    ServiceRequestDraft draft,
  ) async {
    createdDraft = draft;
    return RemoteServiceRequest(
      id: 'request-1',
      ownerUserId: 'owner-1',
      trade: draft.trade,
      serviceCity: draft.serviceCity,
      serviceAddress: draft.serviceAddress,
      remark: draft.remark,
      status: 'OPEN',
      candidates: const [],
      createdAt: DateTime.utc(2026, 7, 18),
      updatedAt: DateTime.utc(2026, 7, 18),
    );
  }

  @override
  Future<RemoteServiceRequest> addCandidate(
    String accessToken,
    String requestId,
    String workerUserId,
  ) =>
      throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> acceptVisit(String accessToken, String bookingId) =>
      throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> cancelAsOwner(
    String accessToken,
    String bookingId,
    String reason,
  ) =>
      throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> cancelAsWorker(
    String accessToken,
    String bookingId,
    String reason,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<RemoteServiceRequest>> listOwnerRequests(String accessToken) =>
      throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> ownerArrive(String accessToken, String bookingId) =>
      throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> ownerConfirmArrival(
    String accessToken,
    String bookingId,
  ) =>
      throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> proposeVisit(
    String accessToken,
    String bookingId,
    DateTime proposedTime,
  ) =>
      throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> rejectVisit(
    String accessToken,
    String bookingId,
    String reason,
  ) =>
      throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> workerArrive(String accessToken, String bookingId) =>
      throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> workerConfirmArrival(
    String accessToken,
    String bookingId,
  ) =>
      throw UnimplementedError();
}

final class _FakeOwnerProfileApi implements OwnerProfileApi {
  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async =>
      const RemoteOwnerProfile(
        userId: 'owner-1',
        phone: '13812345678',
        name: '模拟器业主',
        city: '成都',
        decorationType: '旧房翻新',
        address: 'Android Studio 模拟器小区 1 栋 101',
        area: 88,
        profileComplete: true,
      );

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) =>
      throw UnimplementedError();
}

final class _NoopOwnerBookingApi implements OwnerBookingApi {
  @override
  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) =>
      throw UnimplementedError();

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(String accessToken) async =>
      const [];
}

AuthSession _ownerSession() => AuthSession(
  accessToken: 'owner-token',
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  userId: 'owner-1',
  phone: '13812345678',
  roles: const ['OWNER'],
);
