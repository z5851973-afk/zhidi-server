import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/owner_after_sale_page.dart';
import 'package:zhidi_app/pages/home/owner_payment_page.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';
import 'package:zhidi_app/services/payment_api_client.dart';
import 'package:zhidi_app/services/worker_quote_api_client.dart';

void main() {
  testWidgets('loads payment page without inherited-widget lifecycle error', (
    tester,
  ) async {
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
          utf8.encode(
            jsonEncode({'code': 'OK', 'message': 'success', 'data': const []}),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: OwnerPaymentPage(bookingId: 'booking-1', paymentApi: api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无支付订单'), findsOneWidget);
    expect(find.text('生成支付订单'), findsOneWidget);
    expect(
      find.textContaining('dependOnInheritedWidgetOfExactType'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'notification target loads the exact payment order beyond the first page',
    (tester) async {
      final state = await _ownerState();
      final requestedPaths = <String>[];
      final api = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          requestedPaths.add(request.url.path);
          if (request.url.path ==
              '/api/v1/payment/orders/target-payment-order') {
            return _jsonResponse(
              _paymentEnvelope(
                id: 'target-payment-order',
                bookingId: 'booking-target',
                amount: 220,
              ),
            );
          }
          if (request.url.path ==
              '/api/v1/after-sales/booking-context/booking-target') {
            return _jsonResponse({
              'data': {
                ..._afterSaleContextJson(bookingStatus: 'COMPLETED'),
                'bookingId': 'booking-target',
                'paymentOrderId': 'target-payment-order',
              },
            });
          }
          if (request.url.path == '/api/v1/payment/orders') {
            return _jsonResponse({
              'data': {
                'content': [
                  _paymentJson(
                    id: 'older-payment-order',
                    bookingId: 'booking-target',
                    amount: 110,
                  ),
                  for (var index = 1; index < 20; index += 1)
                    _paymentJson(
                      id: 'unrelated-payment-$index',
                      bookingId: 'unrelated-booking-$index',
                      amount: index.toDouble(),
                    ),
                ],
              },
            });
          }
          fail('Unexpected request: ${request.url}');
        }),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: OwnerPaymentPage(
              bookingId: 'booking-target',
              initialPaymentOrderId: 'target-payment-order',
              paymentApi: api,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('target-p'), findsOneWidget);
      expect(find.text('older-p'), findsNothing);
      expect(find.text('¥220.00'), findsWidgets);
      expect(requestedPaths, [
        '/api/v1/payment/orders/target-payment-order',
        '/api/v1/after-sales/booking-context/booking-target',
      ]);
    },
  );

  testWidgets(
    'missing notification payment target is unavailable without create fallback',
    (tester) async {
      final state = await _ownerState();
      final requestedPaths = <String>[];
      final api = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          requestedPaths.add(request.url.path);
          if (request.url.path ==
              '/api/v1/payment/orders/missing-payment-order') {
            return _jsonResponse({
              'code': 'PAYMENT_ORDER_NOT_FOUND',
              'message': 'payment order not found',
            }, statusCode: 404);
          }
          if (request.url.path == '/api/v1/payment/orders') {
            return _jsonResponse({
              'data': {
                'content': [
                  _paymentJson(
                    id: 'replacement-payment-order',
                    bookingId: 'booking-target',
                    amount: 330,
                  ),
                ],
              },
            });
          }
          fail('Unexpected request: ${request.url}');
        }),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: OwnerPaymentPage(
              bookingId: 'booking-target',
              initialPaymentOrderId: 'missing-payment-order',
              paymentApi: api,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('该订单已更新或不再可用'), findsOneWidget);
      expect(find.text('生成支付订单'), findsNothing);
      expect(find.text('replacement-payment-order'), findsNothing);
      expect(requestedPaths, ['/api/v1/payment/orders/missing-payment-order']);
    },
  );

  testWidgets(
    'temporary notification target failure offers retry without create fallback',
    (tester) async {
      final state = await _ownerState();
      var detailCalls = 0;
      final api = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/api/v1/payment/orders/target-payment-order',
          );
          detailCalls += 1;
          if (detailCalls == 1) {
            return _jsonResponse({
              'code': 'TEMPORARILY_UNAVAILABLE',
              'message': 'try again',
            }, statusCode: 503);
          }
          return _jsonResponse(
            _paymentEnvelope(
              id: 'target-payment-order',
              bookingId: 'booking-target',
              amount: 220,
            ),
          );
        }),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: OwnerPaymentPage(
              bookingId: 'booking-target',
              initialPaymentOrderId: 'target-payment-order',
              paymentApi: api,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('暂时无法打开订单，请稍后重试'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('该订单已更新或不再可用'), findsNothing);
      expect(find.text('生成支付订单'), findsNothing);

      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();

      expect(find.text('target-p'), findsOneWidget);
      expect(detailCalls, 2);
    },
  );

  testWidgets(
    'notification payment target must belong to the requested booking',
    (tester) async {
      final state = await _ownerState();
      final api = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          expect(
            request.url.path,
            '/api/v1/payment/orders/target-payment-order',
          );
          return _jsonResponse(
            _paymentEnvelope(
              id: 'target-payment-order',
              bookingId: 'different-booking',
              amount: 440,
            ),
          );
        }),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: OwnerPaymentPage(
              bookingId: 'booking-target',
              initialPaymentOrderId: 'target-payment-order',
              paymentApi: api,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('该订单已更新或不再可用'), findsOneWidget);
      expect(find.text('生成支付订单'), findsNothing);
      expect(find.text('¥440.00'), findsNothing);
    },
  );

  testWidgets('shows quote total plus platform service fee to owner', (
    tester,
  ) async {
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
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': {
                'content': [
                  {
                    'id': 'payment-1',
                    'bookingId': 'booking-1',
                    'ownerUserId': 'owner-user-id',
                    'workerUserId': 'worker-user-id',
                    'quoteId': 'quote-1',
                    'amount': 6380,
                    'platformFee': 580,
                    'workerSettlement': 5220,
                    'warrantyRetention': 580,
                    'status': 'OWNER_REPORTED_PAID',
                    'paymentMethod': 'OFFLINE',
                    'createdAt': '2026-08-01T10:00:00Z',
                    'updatedAt': '2026-08-01T10:01:00Z',
                  },
                ],
              },
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final quoteApi = _quoteApi();

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: OwnerPaymentPage(
            bookingId: 'booking-1',
            paymentApi: api,
            quoteApi: quoteApi,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('报价清单总价'), findsOneWidget);
    expect(find.text('¥5800.00'), findsOneWidget);
    expect(find.text('平台服务费（10%）'), findsOneWidget);
    expect(find.text('¥580.00'), findsOneWidget);
    expect(find.text('¥6380.00'), findsOneWidget);
    expect(find.textContaining('工人可结算'), findsNothing);
    expect(find.textContaining('质保金冻结'), findsNothing);

    await tester.tap(find.text('查看报价明细'));
    await tester.pumpAndSettle();

    expect(find.text('人工明细'), findsOneWidget);
    expect(find.text('墙面刷漆'), findsOneWidget);
    expect(find.text('材料明细'), findsOneWidget);
    expect(find.text('乳胶漆材料'), findsOneWidget);
  });

  testWidgets('split order shows two recipients and one verification submit', (
    tester,
  ) async {
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
        if (request.url.path == '/api/v1/payment/orders') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'data': {
                  'content': [
                    {
                      'id': 'payment-v2',
                      'bookingId': 'booking-v2',
                      'ownerUserId': 'owner-user-id',
                      'workerUserId': 'worker-user-id',
                      'quoteId': 'quote-v2',
                      'amount': 11924,
                      'platformFee': 1084,
                      'workerSettlement': 10840,
                      'warrantyRetention': 0,
                      'fundingModel': 'OFFLINE_SPLIT_V2',
                      'quoteAmount': 10840,
                      'constructionPaymentStatus': 'NOT_REPORTED',
                      'platformFeeStatus': 'NOT_REPORTED',
                      'status': 'PENDING',
                      'paymentMethod': 'OFFLINE_SPLIT',
                      'createdAt': '2026-08-06T10:00:00Z',
                      'updatedAt': '2026-08-06T10:00:00Z',
                    },
                  ],
                },
              }),
            ),
            200,
          );
        }
        expect(request.url.path, '/api/v1/payment/offline-instructions');
        expect(request.url.queryParameters['orderId'], 'payment-v2');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'data': {
                'orderId': 'payment-v2',
                'quoteAmount': 10840,
                'platformFee': 1084,
                'constructionPayment': {
                  'amount': 10840,
                  'workerName': '张师傅',
                  'contactAction': 'CONTACT_WORKER_IN_APP',
                },
                'platformFeePayment': {
                  'amount': 1084,
                  'accountName': '知底科技有限公司',
                  'bankName': '中国银行成都分行',
                  'bankAccount': '1234567890',
                },
              },
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: OwnerPaymentPage(bookingId: 'booking-v2', paymentApi: api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('支付工程款给张师傅'), findsOneWidget);
    expect(find.text('¥10840.00'), findsWidgets);
    expect(find.text('支付平台服务费给知底'), findsOneWidget);
    expect(find.text('¥1084.00'), findsWidgets);
    expect(find.text('开户银行'), findsOneWidget);
    expect(find.text('应付合计 ¥11924.00'), findsOneWidget);
    expect(find.text('提交付款核验'), findsOneWidget);
    expect(find.text('线下付款与人工确认'), findsOneWidget);
    expect(find.textContaining('银行监管'), findsNothing);
    expect(find.textContaining('银行放款'), findsNothing);
    expect(find.textContaining('自动退款'), findsNothing);
    expect(find.textContaining('自动放款'), findsNothing);
    expect(find.textContaining('工人可结算90%'), findsNothing);
    expect(find.textContaining('质保金冻结10%'), findsNothing);
    expect(find.textContaining('我已线下付款'), findsNothing);
  });

  testWidgets(
    'platform-fee rejection only reopens and resubmits the platform component',
    (tester) async {
      final state = await _ownerState();
      Map<String, dynamic>? submittedBody;
      final api = _splitPaymentApi(
        constructionStatus: 'CONFIRMED',
        platformFeeStatus: 'REJECTED',
        onReport: (body) => submittedBody = body,
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: OwnerPaymentPage(bookingId: 'booking-v2', paymentApi: api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('construction-payment-reference')),
        findsNothing,
      );
      expect(find.byKey(const Key('platform-fee-reference')), findsOneWidget);
      expect(find.text('已确认的工程款不需要重新转账'), findsOneWidget);
      expect(find.text('重新提交平台服务费核验'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('platform-fee-reference')),
        'new-fee-ref',
      );
      await tester.tap(find.text('重新提交平台服务费核验'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.textContaining('工程款')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.textContaining('平台服务费')),
        findsWidgets,
      );

      await tester.tap(find.text('确认提交核验'));
      await tester.pumpAndSettle();

      expect(submittedBody, {
        'platformFeeChannel': '对公转账',
        'platformFeeReference': 'new-fee-ref',
      });
    },
  );

  testWidgets(
    'partial split order with rejected construction only resubmits construction',
    (tester) async {
      final state = await _ownerState();
      Map<String, dynamic>? submittedBody;
      final api = _splitPaymentApi(
        constructionStatus: 'REJECTED',
        platformFeeStatus: 'VERIFIED',
        onReport: (body) => submittedBody = body,
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: OwnerPaymentPage(bookingId: 'booking-v2', paymentApi: api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('construction-payment-reference')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('platform-fee-reference')), findsNothing);
      expect(find.text('已核验的平台服务费不需要重新转账'), findsOneWidget);
      expect(find.text('重新提交工程款核验'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('construction-payment-reference')),
        'new-worker-ref',
      );
      await tester.tap(find.text('重新提交工程款核验'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.textContaining('平台服务费')),
        findsNothing,
      );
      expect(
        find.descendant(of: dialog, matching: find.textContaining('工程款')),
        findsWidgets,
      );

      await tester.tap(find.text('确认提交核验'));
      await tester.pumpAndSettle();

      expect(submittedBody, {
        'constructionChannel': '银行卡转账',
        'constructionReference': 'new-worker-ref',
      });
    },
  );

  testWidgets('paid unfinished booking does not expose after-sale entry', (
    tester,
  ) async {
    final state = await _ownerState();
    final api = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/payment/orders') {
          return _jsonResponse({
            'data': {
              'content': [
                _paymentJson(
                  id: 'payment-paid',
                  bookingId: 'booking-paid',
                  amount: 6380,
                ),
              ],
            },
          });
        }
        if (request.url.path ==
            '/api/v1/after-sales/booking-context/booking-paid') {
          return _jsonResponse({
            'data': _afterSaleContextJson(bookingStatus: 'HIRED'),
          });
        }
        fail('Unexpected request: ${request.url}');
      }),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: OwnerPaymentPage(bookingId: 'booking-paid', paymentApi: api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已支付'), findsOneWidget);
    expect(find.text('申请售后（人工处理）'), findsNothing);
  });

  testWidgets('paid order opens booking-bound manual after-sale handling', (
    tester,
  ) async {
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
    final observer = _RecordingNavigatorObserver();
    final api = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        if (request.url.path ==
            '/api/v1/after-sales/booking-context/booking-paid') {
          return _jsonResponse({
            'data': _afterSaleContextJson(bookingStatus: 'COMPLETED'),
          });
        }
        expect(request.url.path, '/api/v1/payment/orders');
        return _jsonResponse({
          'data': {
            'content': [
              {
                'id': 'payment-paid',
                'bookingId': 'booking-paid',
                'ownerUserId': 'owner-user-id',
                'workerUserId': 'worker-user-id',
                'amount': 6380,
                'platformFee': 580,
                'workerSettlement': 5220,
                'warrantyRetention': 580,
                'status': 'PAID',
                'paymentMethod': 'OFFLINE',
                'createdAt': '2026-08-01T10:00:00Z',
                'updatedAt': '2026-08-01T10:01:00Z',
              },
            ],
          },
        });
      }),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          navigatorObservers: [observer],
          home: OwnerPaymentPage(bookingId: 'booking-paid', paymentApi: api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('申请售后（人工处理）'), findsOneWidget);
    expect(find.text('退款渠道尚未开通'), findsNothing);

    await tester.scrollUntilVisible(find.text('申请售后（人工处理）'), 300);
    await tester.tap(find.text('申请售后（人工处理）'));

    expect(observer.routes, hasLength(2));
    final route = observer.routes.last as MaterialPageRoute<dynamic>;
    final destination = route.builder(
      tester.element(find.byType(OwnerPaymentPage)),
    );
    expect(destination, isA<OwnerAfterSalePage>());
    expect((destination as OwnerAfterSalePage).bookingId, 'booking-paid');
  });
}

Future<OwnerAppState> _ownerState() => OwnerAppState.memory(
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

http.Response _jsonResponse(
  Map<String, dynamic> body, {
  int statusCode = 200,
}) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  statusCode,
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _paymentEnvelope({
  required String id,
  required String bookingId,
  required double amount,
}) => {
  'code': 'OK',
  'message': 'success',
  'data': _paymentJson(id: id, bookingId: bookingId, amount: amount),
};

Map<String, dynamic> _paymentJson({
  required String id,
  required String bookingId,
  required double amount,
}) => {
  'id': id,
  'bookingId': bookingId,
  'ownerUserId': 'owner-user-id',
  'workerUserId': 'worker-user-id',
  'amount': amount,
  'platformFee': 0,
  'workerSettlement': amount,
  'warrantyRetention': 0,
  'status': 'PAID',
  'paymentMethod': 'OFFLINE',
  'createdAt': '2026-08-01T10:00:00Z',
  'updatedAt': '2026-08-01T10:01:00Z',
};

Map<String, dynamic> _afterSaleContextJson({required String bookingStatus}) => {
  'bookingId': 'booking-paid',
  'bookingStatus': bookingStatus,
  'trade': 'carpentry',
  'ownerName': '张女士',
  'workerName': '李师傅',
  'serviceCity': '成都市',
  'serviceAddress': '武侯区一号',
  'paymentOrderId': 'payment-paid',
  'paymentAmount': 6380,
  'paymentStatus': 'PAID',
  'inspection': {'status': 'PASSED', 'passedCount': 1, 'totalCount': 1},
};

final class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> routes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    routes.add(route);
    super.didPush(route, previousRoute);
  }
}

PaymentApiClient _splitPaymentApi({
  required String constructionStatus,
  required String platformFeeStatus,
  required ValueChanged<Map<String, dynamic>> onReport,
}) {
  Map<String, dynamic> order({required bool afterReport}) => {
    'id': 'payment-v2',
    'bookingId': 'booking-v2',
    'ownerUserId': 'owner-user-id',
    'workerUserId': 'worker-user-id',
    'quoteId': 'quote-v2',
    'amount': 11924,
    'platformFee': 1084,
    'workerSettlement': 10840,
    'warrantyRetention': 0,
    'fundingModel': 'OFFLINE_SPLIT_V2',
    'quoteAmount': 10840,
    'constructionPaymentStatus': afterReport && constructionStatus == 'REJECTED'
        ? 'REPORTED'
        : constructionStatus,
    'platformFeeStatus': afterReport && platformFeeStatus == 'REJECTED'
        ? 'REPORTED'
        : platformFeeStatus,
    'status': afterReport ? 'UNDER_REVIEW' : 'PARTIALLY_REPORTED',
    'paymentMethod': 'OFFLINE_SPLIT',
    if (constructionStatus == 'CONFIRMED')
      'constructionPaymentReference': 'confirmed-worker-ref',
    if (platformFeeStatus == 'VERIFIED')
      'platformFeeReference': 'verified-fee-ref',
    'createdAt': '2026-08-06T10:00:00Z',
    'updatedAt': afterReport ? '2026-08-06T10:10:00Z' : '2026-08-06T10:00:00Z',
  };

  return PaymentApiClient(
    baseUrl: Uri.parse('http://example.test'),
    httpClient: MockClient((request) async {
      if (request.url.path == '/api/v1/payment/orders') {
        return _jsonResponse({
          'data': {
            'content': [order(afterReport: false)],
          },
        });
      }
      if (request.url.path == '/api/v1/payment/offline-instructions') {
        return _jsonResponse({
          'data': {
            'orderId': 'payment-v2',
            'quoteAmount': 10840,
            'platformFee': 1084,
            'constructionPayment': {
              'amount': 10840,
              'workerName': '张师傅',
              'contactAction': 'CONTACT_WORKER_IN_APP',
            },
            'platformFeePayment': {
              'amount': 1084,
              'accountName': '知底科技有限公司',
              'bankName': '中国银行成都分行',
              'bankAccount': '1234567890',
            },
          },
        });
      }
      expect(
        request.url.path,
        '/api/v1/payment/orders/payment-v2/offline-split-report',
      );
      final body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      onReport(body);
      return _jsonResponse({'data': order(afterReport: true)});
    }),
  );
}

WorkerQuoteApiClient _quoteApi() => WorkerQuoteApiClient(
  baseUrl: Uri.parse('http://example.test'),
  httpClient: MockClient((request) async {
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'code': 'OK',
          'message': 'success',
          'data': [
            {
              'id': 'quote-1',
              'bookingId': 'booking-1',
              'workerUserId': 'worker-user-id',
              'items': [
                {
                  'name': '墙面刷漆',
                  'quantity': 100,
                  'unit': '平米',
                  'unitPrice': 40,
                  'subtotal': 4000,
                  'laborFee': 4000,
                  'auxiliaryFee': 0,
                  'mainMaterialFee': 0,
                },
                {
                  'name': '乳胶漆材料',
                  'quantity': 6,
                  'unit': '桶',
                  'unitPrice': 300,
                  'subtotal': 1800,
                  'laborFee': 0,
                  'auxiliaryFee': 1800,
                  'mainMaterialFee': 0,
                },
              ],
              'status': 'ACCEPTED',
              'createdAt': '2026-08-01T09:00:00Z',
              'updatedAt': '2026-08-01T09:01:00Z',
            },
          ],
        }),
      ),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

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
  Future<List<RemoteOwnerBooking>> listOwnerBookings(
    String accessToken,
  ) async => const [];

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
