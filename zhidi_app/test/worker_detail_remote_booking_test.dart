import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/models/renovation.dart';
import 'package:zhidi_app/pages/renovation/worker_detail_page.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';
import 'package:zhidi_app/services/worker_directory_api_client.dart';

void main() {
  testWidgets(
    'remote worker detail creates server booking before success flow',
    (tester) async {
      final bookingApi = _FakeOwnerBookingApi();
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: bookingApi,
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: WorkerDetailPage(
              workerName: '服务端周师傅',
              trade: Trade.masonry,
              remoteProfile: const RemoteWorkerDirectoryProfile(
                userId: 'server-worker-user-id',
                name: '服务端周师傅',
                serviceCity: '杭州',
                primaryTrade: '泥工',
                experienceYears: 12,
                dailyRate: 680,
                bio: '擅长瓷砖铺贴',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('立即预约师傅'));
      await tester.pump(const Duration(milliseconds: 200));

      expect(bookingApi.requests, hasLength(1));
      expect(bookingApi.requests.single.workerUserId, 'server-worker-user-id');
      expect(bookingApi.requests.single.serviceCity, '杭州');
      expect(
        state.bookedWorkers.any(
          (worker) => worker.id == 'server-worker-user-id',
        ),
        isTrue,
      );
    },
  );
}

AuthSession _session() => AuthSession(
  accessToken: 'jwt-token',
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(const Duration(days: 1)),
  userId: 'owner-user-id',
  phone: '13800138000',
  roles: const ['OWNER'],
);

final class _FakeOwnerBookingApi implements OwnerBookingApi {
  final requests = <OwnerBookingCreateRequest>[];

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) async {
    requests.add(request);
    return RemoteOwnerBooking(
      id: 'booking-1',
      ownerUserId: 'owner-user-id',
      workerUserId: request.workerUserId,
      workerName: '服务端周师傅',
      trade: request.trade ?? '泥工师傅',
      serviceCity: request.serviceCity ?? '杭州',
      serviceAddress: request.serviceAddress,
      remark: request.remark,
      serviceRequestId: 'sr-test-1',
      status: 'PENDING',
      createdAt: DateTime.utc(2026, 7, 15, 10),
      updatedAt: DateTime.utc(2026, 7, 15, 10),
    );
  }

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(String accessToken) async {
    return [];
  }

  @override
  Future<RemoteOwnerBooking> cancelBooking(
      String accessToken, String bookingId, String reason) async {
    return RemoteOwnerBooking(
      id: bookingId,
      ownerUserId: 'owner-user-id',
      workerUserId: 'server-worker-user-id',
      workerName: '服务端周师傅',
      trade: '泥工',
      serviceCity: '杭州',
      serviceAddress: null,
      remark: null,
      serviceRequestId: 'sr-test-1',
      cancelledBy: null,
      cancelReason: null,
      cancelledAt: null,
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
