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
      'workerSettlement': 90,
      'warrantyRetention': 10,
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

  test('lists warranty retentions for current user', () async {
    final client = PaymentApiClient(
      baseUrl: Uri.parse('https://example.test'),
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/warranty-retentions');
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'retention-1',
                'workerUserId': 'worker-1',
                'ownerUserId': 'owner-1',
                'bookingId': 'booking-1',
                'paymentOrderId': 'order-1',
                'amount': 10,
                'releasedAmount': 0,
                'deductedAmount': 0,
                'remainingAmount': 10,
                'status': 'HELD',
                'createdAt': '2026-07-30T00:00:00Z',
                'updatedAt': '2026-07-30T00:00:00Z',
              },
            ],
          }),
          200,
        );
      }),
    );

    final retentions = await client.listWarrantyRetentions('token');

    expect(retentions.single.statusLabel, '质保冻结中');
    expect(retentions.single.remainingAmount, 10);
  });

  test('reports split payments and confirms construction receipt', () async {
    var requestIndex = 0;
    final splitResponse = {
      'data': {
        ...response['data'] as Map<String, dynamic>,
        'fundingModel': 'OFFLINE_SPLIT_V2',
        'quoteAmount': 100,
        'amount': 110,
        'platformFee': 10,
        'workerSettlement': 100,
        'warrantyRetention': 0,
        'constructionPaymentStatus': 'REPORTED',
        'platformFeeStatus': 'REPORTED',
        'status': 'UNDER_REVIEW',
      },
    };
    final client = PaymentApiClient(
      baseUrl: Uri.parse('https://example.test'),
      httpClient: MockClient((request) async {
        requestIndex++;
        if (requestIndex == 1) {
          expect(
            request.url.path,
            '/api/v1/payment/orders/order-1/offline-split-report',
          );
          expect(jsonDecode(request.body), {
            'constructionChannel': '银行卡转账',
            'constructionReference': 'worker-ref',
            'platformFeeChannel': '对公转账',
            'platformFeeReference': 'fee-ref',
            'note': '均已转账',
          });
        } else {
          expect(
            request.url.path,
            '/api/v1/payment/orders/order-1/construction-receipt-confirmation',
          );
        }
        return http.Response(jsonEncode(splitResponse), 200);
      }),
    );

    final order = await client.reportSplitOfflinePayments(
      'token',
      'order-1',
      constructionChannel: '银行卡转账',
      constructionReference: 'worker-ref',
      platformFeeChannel: '对公转账',
      platformFeeReference: 'fee-ref',
      note: '均已转账',
    );
    await client.confirmConstructionReceipt('token', 'order-1');

    expect(order.isSplitOfflineV2, isTrue);
    expect(requestIndex, 2);
  });

  test('loads and reports worker warranty contribution', () async {
    var requestIndex = 0;
    final client = PaymentApiClient(
      baseUrl: Uri.parse('https://example.test'),
      httpClient: MockClient((request) async {
        requestIndex++;
        if (requestIndex == 1) {
          expect(request.url.path, '/api/v1/worker-warranty/account');
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'account-1',
                'workerUserId': 'worker-1',
                'effectiveBalance': 0,
                'deductedTotal': 0,
                'releasedTotal': 0,
                'capAmount': 10000,
                'outstandingAmount': 1084,
                'status': 'TOP_UP_REQUIRED',
                'canAcceptNewJobs': false,
              },
            }),
            200,
          );
        }
        expect(
          request.url.path,
          '/api/v1/worker-warranty/contributions/contribution-1/report',
        );
        expect(jsonDecode(request.body), {
          'channel': '对公转账',
          'reference': 'warranty-ref',
        });
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'contribution-1',
              'workerUserId': 'worker-1',
              'paymentOrderId': 'order-1',
              'bookingId': 'booking-1',
              'amountDue': 1084,
              'status': 'REPORTED',
            },
          }),
          200,
        );
      }),
    );

    final account = await client.getWorkerWarrantyAccount('token');
    final contribution = await client.reportWarrantyContribution(
      'token',
      'contribution-1',
      channel: '对公转账',
      reference: 'warranty-ref',
    );

    expect(account.outstandingAmount, 1084);
    expect(contribution.status, 'REPORTED');
  });

  test(
    'gets server-calculated after-sale top-up obligation without sending amount',
    () async {
      final client = PaymentApiClient(
        baseUrl: Uri.parse('https://example.test'),
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/api/v1/worker-warranty/account/top-up-obligation',
          );
          expect(request.headers['authorization'], 'Bearer worker-token');
          expect(request.body, isEmpty);
          return http.Response(
            jsonEncode({
              'data': {
                'id': 'after-sale-top-up-1',
                'workerUserId': 'worker-1',
                'paymentOrderId': null,
                'bookingId': null,
                'afterSaleId': 'after-sale-1',
                'amountDue': 10,
                'status': 'DUE',
              },
            }),
            200,
          );
        }),
      );

      final contribution = await client.ensureWorkerWarrantyTopUpObligation(
        'worker-token',
      );

      expect(contribution.paymentOrderId, isNull);
      expect(contribution.bookingId, isNull);
      expect(contribution.afterSaleId, 'after-sale-1');
      expect(contribution.amountDue, 10);
    },
  );

  test(
    'creates and collaborates on a booking-bound after-sale ticket',
    () async {
      var requestIndex = 0;
      final client = PaymentApiClient(
        baseUrl: Uri.parse('https://example.test'),
        httpClient: MockClient((request) async {
          requestIndex++;
          expect(request.headers['authorization'], 'Bearer token');
          if (requestIndex == 1) {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/v1/after-sales');
            expect(jsonDecode(request.body), {
              'bookingId': 'booking-1',
              'type': 'COMPLAINT',
              'reason': '木作开裂',
              'evidenceUrls': ['/uploads/after-sales/create.jpg'],
            });
            return _utf8JsonResponse({'data': _afterSaleTicket});
          }
          if (requestIndex == 2) {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/v1/after-sales/after-sale-1');
            return _utf8JsonResponse({'data': _afterSaleDetail});
          }
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/after-sales/after-sale-1/events');
          expect(jsonDecode(request.body), {
            'content': '已安排返修',
            'evidenceUrls': ['/uploads/after-sales/repair.jpg'],
            'idempotencyKey': 'worker-message-1',
          });
          return _utf8JsonResponse({'data': _afterSaleDetail['timeline'][1]});
        }),
      );

      final ticket = await client.createAfterSale(
        'token',
        bookingId: 'booking-1',
        type: 'COMPLAINT',
        reason: '木作开裂',
        evidenceUrls: const ['/uploads/after-sales/create.jpg'],
      );
      final detail = await client.getAfterSale('token', 'after-sale-1');
      final event = await client.appendAfterSaleEvent(
        'token',
        'after-sale-1',
        content: '已安排返修',
        evidenceUrls: const ['/uploads/after-sales/repair.jpg'],
        idempotencyKey: 'worker-message-1',
      );

      expect(ticket.workerUserId, 'worker-1');
      expect(detail.context.workerName, '李师傅');
      expect(detail.timeline.first.afterSaleId, 'after-sale-1');
      expect(event.actorRole, 'WORKER');
      expect(requestIndex, 3);
    },
  );

  test(
    'loads exact booking context before an owner creates a ticket',
    () async {
      final client = PaymentApiClient(
        baseUrl: Uri.parse('https://example.test'),
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.path,
            '/api/v1/after-sales/booking-context/booking-1',
          );
          expect(request.headers['authorization'], 'Bearer token');
          return _utf8JsonResponse({'data': _afterSaleDetail['context']});
        }),
      );

      final context = await client.getAfterSaleBookingContext(
        'token',
        'booking-1',
      );

      expect(context.workerName, '李师傅');
      expect(context.tradeLabel, '木工');
      expect(context.paymentLabel, '已支付');
      expect(context.inspection.label, '验收已通过');
    },
  );
}

http.Response _utf8JsonResponse(Map<String, dynamic> body) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

const _afterSaleTicket = <String, dynamic>{
  'id': 'after-sale-1',
  'bookingId': 'booking-1',
  'ownerUserId': 'owner-1',
  'workerUserId': 'worker-1',
  'type': 'COMPLAINT',
  'reason': '木作开裂',
  'evidenceUrls': <String>[],
  'status': 'OPEN',
  'dueAt': '2026-08-12T01:00:00Z',
  'lastActivityAt': '2026-08-09T01:00:00Z',
  'createdAt': '2026-08-09T01:00:00Z',
  'updatedAt': '2026-08-09T01:00:00Z',
};

const _afterSaleDetail = <String, dynamic>{
  'ticket': _afterSaleTicket,
  'context': {
    'bookingId': 'booking-1',
    'trade': 'carpentry',
    'ownerName': '张女士',
    'workerName': '李师傅',
    'serviceCity': '成都市',
    'serviceAddress': '武侯区一号',
    'quoteId': 'quote-1',
    'quoteAmount': 10840,
    'paymentOrderId': 'payment-1',
    'paymentAmount': 11924,
    'paymentStatus': 'PAID',
    'inspection': {'status': 'PASSED', 'passedCount': 1, 'totalCount': 1},
  },
  'timeline': [
    {
      'id': 'event-1',
      'afterSaleId': 'after-sale-1',
      'actorUserId': 'owner-1',
      'actorRole': 'OWNER',
      'type': 'CREATED',
      'content': '木作开裂',
      'evidenceUrls': <String>[],
      'idempotencyKey': 'created-after-sale-1',
      'createdAt': '2026-08-09T01:00:00Z',
    },
    {
      'id': 'event-2',
      'afterSaleId': 'after-sale-1',
      'actorUserId': 'worker-1',
      'actorRole': 'WORKER',
      'type': 'PARTICIPANT_MESSAGE',
      'content': '已安排返修',
      'evidenceUrls': ['/uploads/after-sales/repair.jpg'],
      'idempotencyKey': 'worker-message-1',
      'createdAt': '2026-08-09T02:00:00Z',
    },
  ],
};
