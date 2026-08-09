import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/worker_quote_api_client.dart';

void main() {
  test('rejects a booking-scoped quote with a mismatched booking id', () async {
    final client = WorkerQuoteApiClient(
      baseUrl: Uri.parse('https://example.test'),
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/bookings/booking-new/quotes');
        return http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': [
              {
                'id': 'quote-old',
                'bookingId': 'booking-old',
                'workerUserId': 'worker-1',
                'workerName': '木工师傅',
                'status': 'SUBMITTED',
                'items': [
                  {
                    'name': '木工施工',
                    'quantity': 1,
                    'unit': '项',
                    'unitPrice': 8240,
                    'subtotal': 8240,
                  },
                ],
                'createdAt': '2026-08-08T08:00:00Z',
                'updatedAt': '2026-08-08T08:00:00Z',
              },
            ],
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await expectLater(
      client.listQuotesForBooking('owner-token', 'booking-new'),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.code, 'code', 'INVALID_RESPONSE')
            .having((error) => error.statusCode, 'statusCode', 200),
      ),
    );
  });
}
