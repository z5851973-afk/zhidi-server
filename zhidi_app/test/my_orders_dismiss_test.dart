import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/app/owner_appointment.dart';
import 'package:zhidi_app/pages/order/my_orders_page.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';

void main() {
  testWidgets(
    'remote appointment opens the exact service request and booking',
    (tester) async {
      final bookingApi = _DelayedCancellationBookingApi();
      final state = await OwnerAppState.memory(
        sessionStore: MemoryAuthSessionStore(_session()),
        bookingApi: bookingApi,
      );
      String? openedRequestId;
      String? openedBookingId;

      await tester.pumpWidget(
        MaterialApp(
          home: OwnerAppScope(
            state: state,
            child: MyOrdersPage(
              bookingDetailsBuilder: (requestId, bookingId) {
                openedRequestId = requestId;
                openedBookingId = bookingId;
                return const Scaffold(body: Text('精确预约详情'));
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('约定上门时间'), findsOneWidget);
      expect(find.text('2026-08-09 09:30'), findsOneWidget);
      expect(find.text('实际到场时间'), findsOneWidget);
      expect(find.text('2026-08-09 10:00'), findsOneWidget);

      await tester.tap(find.text('远程测试师傅'));
      await tester.pumpAndSettle();

      expect(openedRequestId, 'request-1');
      expect(openedBookingId, 'booking-1');
      expect(find.text('精确预约详情'), findsOneWidget);
    },
  );

  testWidgets(
    'confirming deletion removes the appointment without Dismissible error',
    (tester) async {
      final state = await OwnerAppState.memory();
      await state.addAppointment(
        OrderItem(
          id: 'local-order-1',
          workerName: '测试师傅',
          customerName: '测试业主',
          phone: '13800000000',
          address: '测试地址',
          area: '80㎡',
          description: '测试预约',
          visitTime: '明天 10:00',
          status: '待师傅确认',
          createdAt: DateTime(2026, 7, 19),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OwnerAppScope(state: state, child: const MyOrdersPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.text('测试师傅'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '删除'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('测试师傅'), findsNothing);
      expect(state.appointments, isEmpty);
    },
  );

  testWidgets('remote appointment stays valid while cancellation is pending', (
    tester,
  ) async {
    final bookingApi = _DelayedCancellationBookingApi();
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(_session()),
      bookingApi: bookingApi,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OwnerAppScope(state: state, child: const MyOrdersPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('远程测试师傅'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '取消预约'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull);
    expect(find.text('远程测试师傅'), findsOneWidget);

    bookingApi.completeCancellation();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('远程测试师傅'), findsNothing);
  });

  testWidgets('rejected remote appointment cannot be swiped to cancel again', (
    tester,
  ) async {
    final bookingApi = _TerminalBookingApi();
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(_session()),
      bookingApi: bookingApi,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OwnerAppScope(state: state, child: const MyOrdersPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已拒绝'), findsOneWidget);
    await tester.drag(find.text('终态师傅'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('确认取消预约'), findsNothing);
    expect(bookingApi.cancelCalls, 0);
  });
}

AuthSession _session() => AuthSession(
  accessToken: 'test-token',
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  userId: 'owner-1',
  phone: '13800000000',
  roles: const ['OWNER'],
);

final class _DelayedCancellationBookingApi implements OwnerBookingApi {
  final _cancellation = Completer<RemoteOwnerBooking>();

  RemoteOwnerBooking get booking => RemoteOwnerBooking(
    id: 'booking-1',
    ownerUserId: 'owner-1',
    workerUserId: 'worker-1',
    workerName: '远程测试师傅',
    trade: 'plumbing',
    serviceCity: '成都',
    serviceAddress: '测试地址',
    remark: '测试预约',
    status: 'PENDING',
    serviceRequestId: 'request-1',
    scheduledVisitAt: DateTime.utc(2026, 8, 9, 1, 30),
    actualOnSiteAt: DateTime.utc(2026, 8, 9, 2),
    createdAt: DateTime(2026, 7, 19),
    updatedAt: DateTime(2026, 7, 19),
  );

  void completeCancellation() => _cancellation.complete(booking);

  @override
  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => _cancellation.future;

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) => throw UnimplementedError();

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(
    String accessToken,
  ) async => [booking];
}

final class _TerminalBookingApi implements OwnerBookingApi {
  int cancelCalls = 0;

  RemoteOwnerBooking get booking => RemoteOwnerBooking(
    id: 'booking-terminal',
    ownerUserId: 'owner-1',
    workerUserId: 'worker-terminal',
    workerName: '终态师傅',
    trade: 'painting',
    serviceCity: '成都',
    serviceAddress: '测试地址',
    remark: '测试预约',
    status: 'REJECTED',
    serviceRequestId: 'request-terminal',
    createdAt: DateTime(2026, 8, 5),
    updatedAt: DateTime(2026, 8, 5),
  );

  @override
  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) async {
    cancelCalls += 1;
    return booking;
  }

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) => throw UnimplementedError();

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(
    String accessToken,
  ) async => [booking];
}
