import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/pages/worker/worker_settlement_page.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/payment_api_client.dart';
import 'package:zhidi_app/services/worker_quote_api_client.dart';

void main() {
  testWidgets(
    'notification target loads exact payment order outside the default page',
    (tester) async {
      final state = await _workerState();
      final requestedPaths = <String>[];
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          requestedPaths.add(request.url.path);
          return switch (request.url.path) {
            '/api/v1/payment/orders/target-payment-order' => _jsonResponse(
              _paymentEnvelope(
                id: 'target-payment-order',
                bookingId: 'booking-target',
                status: 'OWNER_REPORTED_PAID',
              ),
            ),
            '/api/v1/payment/orders' => _jsonResponse({
              'data': {
                'content': [
                  for (var index = 0; index < 20; index += 1)
                    _paymentJson(
                      id: 'unrelated-payment-$index',
                      bookingId: 'unrelated-booking-$index',
                      status: 'PENDING',
                    ),
                ],
              },
            }),
            '/api/v1/settlements' ||
            '/api/v1/warranty-retentions' ||
            '/api/v1/worker-warranty/contributions' => _jsonResponse({
              'data': const [],
            }),
            '/api/v1/worker-warranty/account' => _jsonResponse({
              'code': 'NOT_FOUND',
              'message': 'no warranty account',
            }, statusCode: 404),
            _ => throw StateError('Unexpected request: ${request.url}'),
          };
        }),
      );

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: WorkerSettlementPage(
              paymentApi: paymentApi,
              quoteApi: _emptyQuoteApi(),
              initialPaymentOrderId: 'target-payment-order',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('worker-pending-receipt-target-payment-order'),
        ),
        findsOneWidget,
      );
      expect(find.text('待结算 ¥90.00'), findsOneWidget);
      expect(
        requestedPaths,
        contains('/api/v1/payment/orders/target-payment-order'),
      );
    },
  );

  testWidgets('missing notification payment target shows unavailable state', (
    tester,
  ) async {
    final state = await _workerState();
    final paymentApi = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        return switch (request.url.path) {
          '/api/v1/payment/orders/missing-payment-order' => _jsonResponse({
            'code': 'PAYMENT_ORDER_NOT_FOUND',
            'message': 'payment order not found',
          }, statusCode: 404),
          '/api/v1/payment/orders' => _jsonResponse({
            'data': {
              'content': [
                _paymentJson(
                  id: 'replacement-payment-order',
                  bookingId: 'booking-target',
                  status: 'OWNER_REPORTED_PAID',
                ),
              ],
            },
          }),
          '/api/v1/settlements' ||
          '/api/v1/warranty-retentions' ||
          '/api/v1/worker-warranty/contributions' => _jsonResponse({
            'data': const [],
          }),
          '/api/v1/worker-warranty/account' => _jsonResponse({
            'code': 'NOT_FOUND',
            'message': 'no warranty account',
          }, statusCode: 404),
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
      }),
    );

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerSettlementPage(
            paymentApi: paymentApi,
            quoteApi: _emptyQuoteApi(),
            initialPaymentOrderId: 'missing-payment-order',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('该订单已更新或不再可用'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey('worker-pending-receipt-replacement-payment-order'),
      ),
      findsNothing,
    );
  });

  testWidgets('temporary notification target failure can be retried', (
    tester,
  ) async {
    final state = await _workerState();
    var detailCalls = 0;
    final paymentApi = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        return switch (request.url.path) {
          '/api/v1/payment/orders/target-payment-order' => () {
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
                status: 'OWNER_REPORTED_PAID',
              ),
            );
          }(),
          '/api/v1/payment/orders' => _jsonResponse({
            'data': {'content': const []},
          }),
          '/api/v1/settlements' ||
          '/api/v1/warranty-retentions' ||
          '/api/v1/worker-warranty/contributions' => _jsonResponse({
            'data': const [],
          }),
          '/api/v1/worker-warranty/account' => _jsonResponse({
            'code': 'NOT_FOUND',
            'message': 'no warranty account',
          }, statusCode: 404),
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
      }),
    );

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerSettlementPage(
            paymentApi: paymentApi,
            quoteApi: _emptyQuoteApi(),
            initialPaymentOrderId: 'target-payment-order',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂时无法打开订单，请稍后重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('该订单已更新或不再可用'), findsNothing);

    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('worker-pending-receipt-target-payment-order')),
      findsOneWidget,
    );
    expect(detailCalls, 2);
  });

  testWidgets('confirmed paid notification keeps its exact order visible', (
    tester,
  ) async {
    final state = await _workerState();
    final paidOrder = {
      ..._paymentJson(
        id: 'paid-payment-order',
        bookingId: 'booking-paid',
        status: 'PAID',
      ),
      'fundingModel': 'OFFLINE_SPLIT_V2',
      'quoteAmount': 100,
      'constructionPaymentStatus': 'CONFIRMED',
      'platformFeeStatus': 'VERIFIED',
      'constructionConfirmedAt': '2026-08-01T10:02:00Z',
    };
    final paymentApi = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        return switch (request.url.path) {
          '/api/v1/payment/orders/paid-payment-order' => _jsonResponse({
            'code': 'OK',
            'message': 'success',
            'data': paidOrder,
          }),
          '/api/v1/payment/orders' => _jsonResponse({
            'data': {'content': const []},
          }),
          '/api/v1/settlements' ||
          '/api/v1/warranty-retentions' ||
          '/api/v1/worker-warranty/contributions' => _jsonResponse({
            'data': const [],
          }),
          '/api/v1/worker-warranty/account' => _jsonResponse({
            'code': 'NOT_FOUND',
            'message': 'no warranty account',
          }, statusCode: 404),
          _ => throw StateError('Unexpected request: ${request.url}'),
        };
      }),
    );

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerSettlementPage(
            paymentApi: paymentApi,
            quoteApi: _emptyQuoteApi(),
            initialPaymentOrderId: 'paid-payment-order',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('worker-payment-target-paid-payment-order')),
      findsOneWidget,
    );
    expect(find.text('已支付'), findsOneWidget);
    expect(find.text('支付订单 paid-payment-order'), findsOneWidget);
  });

  testWidgets(
    'submitting a due warranty contribution closes the dialog and refreshes safely',
    (tester) async {
      final state = await _workerState();
      var reportCalls = 0;
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'POST' &&
              path ==
                  '/api/v1/worker-warranty/contributions/contribution-due/report') {
            reportCalls += 1;
            expect(jsonDecode(request.body), {
              'channel': 'WECHAT_TRANSFER',
              'reference': 'warranty-proof-001',
            });
            return _jsonResponse({
              'code': 'OK',
              'data': _warrantyContributionJson(status: 'REPORTED'),
            });
          }
          return switch (path) {
            '/api/v1/payment/orders' => _jsonResponse({
              'data': {'content': const []},
            }),
            '/api/v1/settlements' ||
            '/api/v1/warranty-retentions' => _jsonResponse({'data': const []}),
            '/api/v1/worker-warranty/account' => _jsonResponse({
              'code': 'OK',
              'data': _warrantyAccountJson(),
            }),
            '/api/v1/worker-warranty/contributions' => _jsonResponse({
              'code': 'OK',
              'data': [
                _warrantyContributionJson(
                  status: reportCalls == 0 ? 'DUE' : 'REPORTED',
                ),
              ],
            }),
            '/api/v1/worker-warranty/payment-instructions' => _jsonResponse({
              'code': 'OK',
              'data': const {
                'accountName': '知底履约质保金专户',
                'bankName': '测试银行',
                'bankAccount': '6222000000000000',
              },
            }),
            _ => throw StateError(
              'Unexpected request: ${request.method} ${request.url}',
            ),
          };
        }),
      );

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: WorkerSettlementPage(
              paymentApi: paymentApi,
              quoteApi: _emptyQuoteApi(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('补充质保金'));
      await tester.pumpAndSettle();
      expect(find.text('补充履约质保金'), findsOneWidget);
      expect(find.text('本次应补充 ¥186.00'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, '转账单号或凭证编号'),
        'warranty-proof-001',
      );
      await tester.tap(find.text('提交平台核验'));
      await tester.pumpAndSettle();

      expect(reportCalls, 1);
      expect(find.text('补充履约质保金'), findsNothing);
      expect(find.text('补充记录已提交，等待平台核验'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'top-up-required account creates exact obligation and completes report flow',
    (tester) async {
      final state = await _workerState();
      var accountCalls = 0;
      var contributionListCalls = 0;
      var ensureCalls = 0;
      var reportCalls = 0;
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'POST' &&
              path == '/api/v1/worker-warranty/account/top-up-obligation') {
            ensureCalls += 1;
            expect(request.body, isEmpty);
            return _jsonResponse({
              'code': 'OK',
              'data': _afterSaleTopUpContributionJson(status: 'DUE'),
            });
          }
          if (request.method == 'POST' &&
              path ==
                  '/api/v1/worker-warranty/contributions/after-sale-top-up/report') {
            reportCalls += 1;
            expect(jsonDecode(request.body), {
              'channel': 'WECHAT_TRANSFER',
              'reference': 'after-sale-top-up-proof',
            });
            return _jsonResponse({
              'code': 'OK',
              'data': _afterSaleTopUpContributionJson(status: 'REPORTED'),
            });
          }
          return switch (path) {
            '/api/v1/payment/orders' => _jsonResponse({
              'data': {'content': const []},
            }),
            '/api/v1/settlements' ||
            '/api/v1/warranty-retentions' => _jsonResponse({'data': const []}),
            '/api/v1/worker-warranty/account' => () {
              accountCalls += 1;
              return _jsonResponse({
                'code': 'OK',
                'data': _warrantyAccountJson(
                  outstandingAmount: accountCalls == 1 ? 0 : 10,
                ),
              });
            }(),
            '/api/v1/worker-warranty/contributions' => () {
              contributionListCalls += 1;
              return _jsonResponse({
                'code': 'OK',
                'data': contributionListCalls == 1
                    ? const []
                    : [
                        _afterSaleTopUpContributionJson(
                          status: reportCalls == 0 ? 'DUE' : 'REPORTED',
                        ),
                      ],
              });
            }(),
            '/api/v1/worker-warranty/payment-instructions' => _jsonResponse({
              'code': 'OK',
              'data': const {
                'accountName': '知底履约质保金专户',
                'bankName': '测试银行',
                'bankAccount': '6222000000000000',
              },
            }),
            _ => throw StateError(
              'Unexpected request: ${request.method} ${request.url}',
            ),
          };
        }),
      );

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: WorkerSettlementPage(
              paymentApi: paymentApi,
              quoteApi: _emptyQuoteApi(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(ensureCalls, 1);
      expect(find.text('待补金额'), findsOneWidget);
      expect(find.text('¥10.00'), findsOneWidget);
      expect(find.text('补充质保金'), findsOneWidget);

      await tester.tap(find.text('补充质保金'));
      await tester.pumpAndSettle();
      expect(find.text('本次应补充 ¥10.00'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, '转账单号或凭证编号'),
        'after-sale-top-up-proof',
      );
      await tester.tap(find.text('提交平台核验'));
      await tester.pumpAndSettle();

      expect(ensureCalls, 1);
      expect(reportCalls, 1);
      expect(find.text('补充记录已提交，等待平台核验'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching worker session discards the old load and never ensures with old token',
    (tester) async {
      final firstState = await _workerState(
        token: 'worker-token-a',
        userId: 'worker-a',
      );
      final secondState = await _workerState(
        token: 'worker-token-b',
        userId: 'worker-b',
      );
      final firstSettlementsStarted = Completer<void>();
      final releaseFirstSettlements = Completer<http.Response>();
      final ensureAuthorizations = <String?>[];
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final authorization = request.headers['authorization'];
          final path = request.url.path;
          if (path == '/api/v1/settlements' &&
              authorization == 'Bearer worker-token-a') {
            if (!firstSettlementsStarted.isCompleted) {
              firstSettlementsStarted.complete();
            }
            return releaseFirstSettlements.future;
          }
          if (path == '/api/v1/worker-warranty/account/top-up-obligation') {
            ensureAuthorizations.add(authorization);
            return _jsonResponse({
              'code': 'OK',
              'data': _afterSaleTopUpContributionJson(status: 'DUE'),
            });
          }
          return switch (path) {
            '/api/v1/payment/orders' => _jsonResponse({
              'data': {'content': const []},
            }),
            '/api/v1/settlements' ||
            '/api/v1/warranty-retentions' ||
            '/api/v1/worker-warranty/contributions' => _jsonResponse({
              'data': const [],
            }),
            '/api/v1/worker-warranty/account' => _jsonResponse({
              'code': 'OK',
              'data': _activeWarrantyAccountJson(
                workerUserId: authorization == 'Bearer worker-token-b'
                    ? 'worker-b'
                    : 'worker-a',
                effectiveBalance: authorization == 'Bearer worker-token-b'
                    ? 222
                    : 111,
              ),
            }),
            _ => throw StateError(
              'Unexpected request: ${request.method} ${request.url}',
            ),
          };
        }),
      );

      Widget app(WorkerAppState state) => WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerSettlementPage(
            key: const ValueKey('worker-settlement-session-test'),
            paymentApi: paymentApi,
            quoteApi: _emptyQuoteApi(),
          ),
        ),
      );

      await tester.pumpWidget(app(firstState));
      await tester.pump();
      await firstSettlementsStarted.future;

      await tester.pumpWidget(app(secondState));
      await tester.pumpAndSettle();
      expect(find.text('¥222.00'), findsOneWidget);
      expect(find.text('¥111.00'), findsNothing);

      releaseFirstSettlements.complete(_jsonResponse({'data': const []}));
      await tester.pumpAndSettle();

      expect(find.text('¥222.00'), findsOneWidget);
      expect(find.text('¥111.00'), findsNothing);
      expect(ensureAuthorizations, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'switching worker while top-up dialog is open blocks old report',
    (tester) async {
      final firstState = await _workerState(
        token: 'worker-token-a',
        userId: 'worker-a',
      );
      final secondState = await _workerState(
        token: 'worker-token-b',
        userId: 'worker-b',
      );
      final reportAuthorizations = <String?>[];
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final authorization = request.headers['authorization'];
          final path = request.url.path;
          if (request.method == 'POST' && path.endsWith('/report')) {
            reportAuthorizations.add(authorization);
            return _jsonResponse({
              'code': 'OK',
              'data': _warrantyContributionJson(status: 'REPORTED'),
            });
          }
          return switch (path) {
            '/api/v1/payment/orders' => _jsonResponse({
              'data': {'content': const []},
            }),
            '/api/v1/settlements' ||
            '/api/v1/warranty-retentions' => _jsonResponse({'data': const []}),
            '/api/v1/worker-warranty/account' => _jsonResponse({
              'code': 'OK',
              'data': authorization == 'Bearer worker-token-a'
                  ? _warrantyAccountJson()
                  : _activeWarrantyAccountJson(
                      workerUserId: 'worker-b',
                      effectiveBalance: 300,
                    ),
            }),
            '/api/v1/worker-warranty/contributions' => _jsonResponse({
              'code': 'OK',
              'data': authorization == 'Bearer worker-token-a'
                  ? [_warrantyContributionJson(status: 'DUE')]
                  : const [],
            }),
            '/api/v1/worker-warranty/payment-instructions' => _jsonResponse({
              'code': 'OK',
              'data': const {
                'accountName': '知底履约质保金专户',
                'bankName': '测试银行',
                'bankAccount': '6222000000000000',
              },
            }),
            _ => throw StateError(
              'Unexpected request: ${request.method} ${request.url}',
            ),
          };
        }),
      );

      Widget app(WorkerAppState state) => WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerSettlementPage(
            key: const ValueKey('worker-settlement-report-session-test'),
            paymentApi: paymentApi,
            quoteApi: _emptyQuoteApi(),
          ),
        ),
      );

      await tester.pumpWidget(app(firstState));
      await tester.pumpAndSettle();
      await tester.tap(find.text('补充质保金'));
      await tester.pumpAndSettle();
      expect(find.text('补充履约质保金'), findsOneWidget);

      await tester.pumpWidget(app(secondState));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '转账单号或凭证编号'),
        'stale-worker-proof',
      );
      await tester.tap(find.text('提交平台核验'));
      await tester.pumpAndSettle();

      expect(reportAuthorizations, isEmpty);
      expect(find.text('¥300.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'temporary warranty account failure shows retry and never ensures',
    (tester) async {
      final state = await _workerState();
      var accountCalls = 0;
      var ensureCalls = 0;
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path == '/api/v1/worker-warranty/account/top-up-obligation') {
            ensureCalls += 1;
          }
          return switch (path) {
            '/api/v1/payment/orders' => _jsonResponse({
              'data': {'content': const []},
            }),
            '/api/v1/settlements' ||
            '/api/v1/warranty-retentions' ||
            '/api/v1/worker-warranty/contributions' => _jsonResponse({
              'data': const [],
            }),
            '/api/v1/worker-warranty/account' => () {
              accountCalls += 1;
              if (accountCalls == 1) {
                return _jsonResponse({
                  'code': 'TEMPORARILY_UNAVAILABLE',
                  'message': 'warranty account unavailable',
                }, statusCode: 503);
              }
              return _jsonResponse({
                'code': 'OK',
                'data': _activeWarrantyAccountJson(
                  workerUserId: 'worker-user-id',
                  effectiveBalance: 500,
                ),
              });
            }(),
            _ => throw StateError(
              'Unexpected request: ${request.method} ${request.url}',
            ),
          };
        }),
      );

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: WorkerSettlementPage(
              paymentApi: paymentApi,
              quoteApi: _emptyQuoteApi(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('暂无结算记录'), findsNothing);
      expect(ensureCalls, 0);

      await tester.tap(find.text('重试'));
      await tester.pumpAndSettle();
      expect(find.text('¥500.00'), findsOneWidget);
      expect(ensureCalls, 0);
    },
  );

  testWidgets(
    'temporary warranty contribution failure shows retry and never ensures',
    (tester) async {
      final state = await _workerState();
      var contributionCalls = 0;
      var ensureCalls = 0;
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path == '/api/v1/worker-warranty/account/top-up-obligation') {
            ensureCalls += 1;
            return _jsonResponse({
              'code': 'OK',
              'data': _afterSaleTopUpContributionJson(status: 'DUE'),
            });
          }
          return switch (path) {
            '/api/v1/payment/orders' => _jsonResponse({
              'data': {'content': const []},
            }),
            '/api/v1/settlements' ||
            '/api/v1/warranty-retentions' => _jsonResponse({'data': const []}),
            '/api/v1/worker-warranty/account' => _jsonResponse({
              'code': 'OK',
              'data': _warrantyAccountJson(outstandingAmount: 0),
            }),
            '/api/v1/worker-warranty/contributions' => () {
              contributionCalls += 1;
              if (contributionCalls == 1) {
                return _jsonResponse({
                  'code': 'TEMPORARILY_UNAVAILABLE',
                  'message': 'warranty contributions unavailable',
                }, statusCode: 503);
              }
              return _jsonResponse({'code': 'OK', 'data': const []});
            }(),
            _ => throw StateError(
              'Unexpected request: ${request.method} ${request.url}',
            ),
          };
        }),
      );

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: WorkerSettlementPage(
              paymentApi: paymentApi,
              quoteApi: _emptyQuoteApi(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('加载失败'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
      expect(find.text('暂无结算记录'), findsNothing);
      expect(ensureCalls, 0);
    },
  );
}

Future<WorkerAppState> _workerState({
  String token = 'worker-token',
  String userId = 'worker-user-id',
}) => WorkerAppState.memory(
  sessionStore: MemoryAuthSessionStore(
    AuthSession(
      accessToken: token,
      tokenType: 'Bearer',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      userId: userId,
      phone: '13666666666',
      roles: const ['WORKER'],
    ),
  ),
);

WorkerQuoteApiClient _emptyQuoteApi() => WorkerQuoteApiClient(
  baseUrl: Uri.parse('http://example.test'),
  httpClient: MockClient(
    (request) async => _jsonResponse({'code': 'OK', 'data': const []}),
  ),
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
  required String status,
}) => {
  'code': 'OK',
  'message': 'success',
  'data': _paymentJson(id: id, bookingId: bookingId, status: status),
};

Map<String, dynamic> _paymentJson({
  required String id,
  required String bookingId,
  required String status,
}) => {
  'id': id,
  'bookingId': bookingId,
  'ownerUserId': 'owner-user-id',
  'workerUserId': 'worker-user-id',
  'amount': 100,
  'platformFee': 0,
  'workerSettlement': 90,
  'warrantyRetention': 10,
  'status': status,
  'paymentMethod': 'OFFLINE',
  'offlinePaymentChannel': '银行卡转账',
  'paymentReference': 'reference-$id',
  'createdAt': '2026-08-01T10:00:00Z',
  'updatedAt': '2026-08-01T10:01:00Z',
};

Map<String, dynamic> _warrantyAccountJson({double outstandingAmount = 186}) => {
  'id': 'warranty-account-id',
  'workerUserId': 'worker-user-id',
  'effectiveBalance': 0,
  'deductedTotal': 0,
  'releasedTotal': 0,
  'capAmount': 10000,
  'outstandingAmount': outstandingAmount,
  'status': 'TOP_UP_REQUIRED',
  'canAcceptNewJobs': false,
  'createdAt': '2026-08-01T10:00:00Z',
  'updatedAt': '2026-08-01T10:01:00Z',
};

Map<String, dynamic> _activeWarrantyAccountJson({
  required String workerUserId,
  required double effectiveBalance,
}) => {
  'id': 'warranty-account-$workerUserId',
  'workerUserId': workerUserId,
  'effectiveBalance': effectiveBalance,
  'deductedTotal': 0,
  'releasedTotal': 0,
  'capAmount': 10000,
  'outstandingAmount': 0,
  'status': 'ACTIVE',
  'canAcceptNewJobs': true,
  'createdAt': '2026-08-01T10:00:00Z',
  'updatedAt': '2026-08-01T10:01:00Z',
};

Map<String, dynamic> _warrantyContributionJson({required String status}) => {
  'id': 'contribution-due',
  'workerUserId': 'worker-user-id',
  'paymentOrderId': 'payment-order-id',
  'bookingId': 'booking-id',
  'amountDue': 186,
  'status': status,
  if (status == 'REPORTED') ...{
    'paymentChannel': 'WECHAT_TRANSFER',
    'paymentReference': 'warranty-proof-001',
    'reportedAt': '2026-08-01T10:02:00Z',
  },
  'createdAt': '2026-08-01T10:00:00Z',
  'updatedAt': '2026-08-01T10:02:00Z',
};

Map<String, dynamic> _afterSaleTopUpContributionJson({
  required String status,
}) => {
  'id': 'after-sale-top-up',
  'workerUserId': 'worker-user-id',
  'paymentOrderId': null,
  'bookingId': null,
  'afterSaleId': 'after-sale-id',
  'amountDue': 10,
  'status': status,
  if (status == 'REPORTED') ...{
    'paymentChannel': 'WECHAT_TRANSFER',
    'paymentReference': 'after-sale-top-up-proof',
    'reportedAt': '2026-08-01T10:02:00Z',
  },
  'createdAt': '2026-08-01T10:00:00Z',
  'updatedAt': '2026-08-01T10:02:00Z',
};
