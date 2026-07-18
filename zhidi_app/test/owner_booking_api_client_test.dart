import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';

void main() {
  final baseUrl = Uri.parse('https://api.example.test/root/');

  test('POST booking sends bearer token and parses booking response', () async {
    late http.Request captured;
    final client = OwnerBookingApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {
              'id': 'booking-1',
              'ownerUserId': 'owner-1',
              'workerUserId': 'worker-1',
              'workerName': '周师傅',
              'trade': '泥工',
              'serviceCity': '杭州',
              'serviceAddress': null,
              'remark': '来自安卓业主端',
              'serviceRequestId': 'sr-test-1',
              'cancelledBy': null,
              'cancelReason': null,
              'cancelledAt': null,
              'status': 'PENDING',
              'createdAt': '2026-07-15T10:00:00Z',
              'updatedAt': '2026-07-15T10:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    final booking = await client.createBooking(
      'jwt-token',
      const OwnerBookingCreateRequest(
        workerUserId: 'worker-1',
        trade: '泥工',
        serviceCity: '杭州',
        remark: '来自安卓业主端',
      ),
    );

    expect(captured.method, 'POST');
    expect(captured.url, Uri.parse('https://api.example.test/api/v1/bookings'));
    expect(captured.headers['accept'], 'application/json');
    expect(captured.headers['authorization'], 'Bearer jwt-token');
    expect(captured.headers['content-type'], 'application/json');
    expect(jsonDecode(captured.body), {
      'workerUserId': 'worker-1',
      'trade': '泥工',
      'serviceCity': '杭州',
      'serviceAddress': null,
      'remark': '来自安卓业主端',
    });
    expect(booking.id, 'booking-1');
    expect(booking.workerName, '周师傅');
    expect(booking.status, 'PENDING');
  });

  test('preserves backend error when booking fails', () async {
    final client = OwnerBookingApiClient(
      baseUrl: baseUrl,
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'WORKER_NOT_FOUND',
            'message': 'worker is not available',
            'data': null,
          }),
          404,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await expectLater(
      client.createBooking(
        'jwt-token',
        const OwnerBookingCreateRequest(workerUserId: 'missing-worker'),
      ),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.code, 'code', 'WORKER_NOT_FOUND')
            .having(
              (error) => error.message,
              'message',
              'worker is not available',
            )
            .having((error) => error.statusCode, 'statusCode', 404),
      ),
    );
  });
}
