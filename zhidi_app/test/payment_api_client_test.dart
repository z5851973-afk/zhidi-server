import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/services/payment_api_client.dart';

void main() {
  const response = {
    'data': {
      'id': 'order-1',
      'bookingId': 'booking-1',
      'ownerUserId': 'owner-1',
      'workerUserId': 'worker-1',
      'amount': 100,
      'platformFee': 0,
      'workerSettlement': 100,
      'status': 'OWNER_REPORTED_PAID',
      'paymentMethod': 'OFFLINE',
      'createdAt': '2026-07-22T00:00:00Z',
      'updatedAt': '2026-07-22T00:00:00Z',
    },
  };

  test('reports offline payment to the owner-only endpoint', () async {
    final client = PaymentApiClient(
      baseUrl: Uri.parse('https://example.test'),
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/v1/payment/orders/order-1/offline-payment-report',
        );
        expect(jsonDecode(request.body), {
          'channel': '银行卡转账',
          'reference': '尾号 2318',
          'note': '已转账',
        });
        return http.Response(jsonEncode(response), 200);
      }),
    );

    final order = await client.reportOfflinePayment(
      'token',
      'order-1',
      channel: '银行卡转账',
      reference: '尾号 2318',
      note: '已转账',
    );

    expect(order.isAwaitingWorkerReceipt, isTrue);
  });

  test('worker confirms actual receipt through a separate endpoint', () async {
    final client = PaymentApiClient(
      baseUrl: Uri.parse('https://example.test'),
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/v1/payment/orders/order-1/receipt-confirmation',
        );
        return http.Response(jsonEncode(response), 200);
      }),
    );

    await client.confirmOfflineReceipt('token', 'order-1');
  });
}
