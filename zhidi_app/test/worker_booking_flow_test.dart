import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/models/house_info.dart';
import 'package:zhidi_app/pages/home/worker/worker_detail_page.dart';
import 'package:zhidi_app/pages/order/create_order_page.dart';
import 'package:zhidi_app/pages/worker/worker_home_page.dart';
import 'package:zhidi_app/services/worker_booking_api_client.dart';

void main() {
  testWidgets('legacy worker detail cannot create a local appointment', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(store: MemoryOwnerStore());

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(
          home: WorkerDetailPage(
            workerId: 'worker-li',
            name: '李师傅',
            workerJob: '拆除师傅',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('立即预约'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateOrderPage), findsNothing);
    expect(state.appointments, isEmpty);
    expect(find.text('请从“找师傅”选择真实师傅后预约'), findsOneWidget);
  });

  testWidgets('pending worker card shows canonical house summary', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final now = DateTime.utc(2026, 8, 9);
    state.initBookingApi(
      api: _SingleBookingApi(
        RemoteWorkerBooking(
          id: 'booking-house',
          ownerUserId: 'owner-1',
          ownerName: '林业主',
          ownerPhone: '13800000000',
          serviceRequestId: 'request-1',
          workerUserId: 'worker-1',
          workerName: '周师傅',
          trade: 'painting',
          serviceCity: '成都市',
          houseInfo: const HouseInfo(
            areaSqm: 98.5,
            bedroomCount: 3,
            livingRoomCount: 2,
            kitchenCount: 1,
            bathroomCount: 2,
          ),
          status: 'PENDING',
          createdAt: now,
          updatedAt: now,
        ),
      ),
      accessToken: 'worker-jwt',
    );
    await state.fetchRemoteBookings();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: const MaterialApp(home: WorkerHomePage()),
      ),
    );
    await tester.pump();

    expect(find.text('98.5㎡ · 3室2厅1厨2卫'), findsOneWidget);
  });
}

final class _SingleBookingApi implements WorkerBookingApi {
  const _SingleBookingApi(this.booking);
  final RemoteWorkerBooking booking;

  @override
  Future<List<RemoteWorkerBooking>> listWorkerBookings(
    String accessToken,
  ) async => [booking];

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
