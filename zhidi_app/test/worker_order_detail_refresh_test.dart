import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/pages/worker/order_detail_page.dart';
import 'package:zhidi_app/services/worker_booking_api_client.dart';

void main() {
  testWidgets('order detail refreshes remote status after opening', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _FakeWorkerBookingApi([
      _booking(status: 'ARRIVAL_PENDING'),
    ]);
    state.initBookingApi(api: api, accessToken: 'worker-jwt');
    await state.fetchRemoteBookings();
    api.bookings = [_booking(status: 'ON_SITE')];

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: const MaterialApp(home: OrderDetailPage(orderId: 'booking-1')),
      ),
    );

    expect(find.text('确认业主已到场'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.text('提交报价单'), findsOneWidget);
    expect(find.text('确认业主已到场'), findsNothing);
  });

  testWidgets('hired order detail exposes construction actions', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    state.initBookingApi(
      api: _FakeWorkerBookingApi([_booking(status: 'HIRED')]),
      accessToken: 'worker-jwt',
    );
    await state.fetchRemoteBookings();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: const MaterialApp(
          home: OrderDetailPage(
            orderId: 'booking-1',
            refreshInterval: null,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('已被选中'), findsWidgets);
    expect(find.text('提交日报'), findsOneWidget);
    expect(find.text('发起验收'), findsOneWidget);
    expect(find.text('联系业主'), findsOneWidget);
    expect(find.text('查看结算'), findsOneWidget);
  });
}

RemoteWorkerBooking _booking({required String status}) => RemoteWorkerBooking(
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
      status: status,
      arrivalConfirmedByOwner: status == 'ON_SITE',
      arrivalConfirmedByWorker: true,
      onSiteAt: status == 'ON_SITE' ? DateTime.utc(2026, 7, 18, 10) : null,
      createdAt: DateTime.utc(2026, 7, 18),
      updatedAt: DateTime.utc(2026, 7, 18, 10),
    );

final class _FakeWorkerBookingApi implements WorkerBookingApi {
  _FakeWorkerBookingApi(this.bookings);

  List<RemoteWorkerBooking> bookings;

  @override
  Future<List<RemoteWorkerBooking>> listWorkerBookings(String accessToken) async =>
      bookings;

  @override
  Future<RemoteWorkerBooking> acceptBooking(String accessToken, String bookingId) =>
      throw UnimplementedError();

  @override
  Future<RemoteWorkerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) =>
      throw UnimplementedError();

  @override
  Future<RemoteWorkerBooking> rejectBooking(String accessToken, String bookingId) =>
      throw UnimplementedError();
}
