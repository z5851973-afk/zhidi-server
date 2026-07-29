import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/owner_payment_page.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';
import 'package:zhidi_app/services/payment_api_client.dart';

void main() {
  testWidgets('loads payment page without inherited-widget lifecycle error',
      (tester) async {
    final state = await OwnerAppState.memory(
      store: MemoryOwnerStore(),
      sessionStore: MemoryAuthSessionStore(
        AuthSession(
          accessToken: 'owner-token',
          tokenType: 'Bearer',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          userId: 'owner-user-id',
          phone: '13555555555',
          roles: const ['OWNER'],
        ),
      ),
      profileApi: _ProfileApi(),
      bookingApi: _BookingApi(),
    );
    final api = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/payment/orders');
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': const [],
          })),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: OwnerPaymentPage(
            bookingId: 'booking-1',
            paymentApi: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无支付订单'), findsOneWidget);
    expect(
      find.textContaining('dependOnInheritedWidgetOfExactType'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

final class _ProfileApi implements OwnerProfileApi {
  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async =>
      const RemoteOwnerProfile(
        userId: 'owner-user-id',
        phone: '13555555555',
        name: '测试业主',
        city: '成都',
        decorationType: null,
        address: '测试小区',
        area: null,
        profileComplete: true,
      );

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) => getCurrent(accessToken);
}

final class _BookingApi implements OwnerBookingApi {
  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(String accessToken) async =>
      const [];

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) => throw UnimplementedError();

  @override
  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();
}
