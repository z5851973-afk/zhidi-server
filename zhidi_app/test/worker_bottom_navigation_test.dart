import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/models/chat_models.dart';
import 'package:zhidi_app/models/payment_models.dart';
import 'package:zhidi_app/pages/home/owner_after_sale_page.dart';
import 'package:zhidi_app/pages/worker/inspection_page.dart';
import 'package:zhidi_app/pages/worker/order_detail_page.dart';
import 'package:zhidi_app/pages/worker/worker_home_page.dart';
import 'package:zhidi_app/pages/worker/worker_settlement_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/chat_api_client.dart';
import 'package:zhidi_app/services/inspection_api_client.dart';
import 'package:zhidi_app/services/payment_api_client.dart';
import 'package:zhidi_app/services/worker_booking_api_client.dart';
import 'package:zhidi_app/services/worker_quote_api_client.dart';

final _workerFeeSynonyms = RegExp('平台服务费|平台费|服务费|手续费|抽成|佣金');

void main() {
  test('worker messages restore legacy JSON without notification metadata', () {
    final message = WorkerMessage.fromJson({
      'id': 'legacy-worker-message',
      'title': '旧消息',
      'content': '旧版本保存的内容',
      'category': '系统',
      'createdAt': '2026-08-08T08:00:00.000Z',
      'isRead': false,
      'orderId': 'legacy-booking',
    });

    expect(message.eventType, isNull);
    expect(message.bookingId, 'legacy-booking');
    expect(message.serviceRequestId, isNull);
    expect(message.targetAction, isNull);
    expect(message.orderId, 'legacy-booking');
    expect(message.serverEventId, isNull);
    expect(message.aggregateType, isNull);
    expect(message.aggregateId, isNull);
  });

  test('worker messages persist exact business event identity', () {
    final message = WorkerMessage(
      id: 'business:event-worker-1',
      title: '验收需整改',
      content: '请按验收结果整改',
      category: '验收',
      createdAt: DateTime.utc(2026, 8, 9),
      serverEventId: 'event-worker-1',
      aggregateType: 'INSPECTION_NODE',
      aggregateId: 'node-worker-1',
      bookingId: 'booking-worker-1',
    );

    final restored = WorkerMessage.fromJson(message.toJson());

    expect(restored.serverEventId, 'event-worker-1');
    expect(restored.aggregateType, 'INSPECTION_NODE');
    expect(restored.aggregateId, 'node-worker-1');
  });

  test(
    'worker booking transitions emit one stable message per server event',
    () async {
      final api = _FakeWorkerBookingApi([
        _remoteWorkerBooking(id: 'worker-booking-main', status: 'PENDING'),
        _remoteWorkerBooking(
          id: 'worker-booking-not-selected',
          status: 'PENDING',
        ),
      ]);
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-token');
      state.initBookingApi(api: api, accessToken: 'worker-token');
      await state.fetchRemoteBookings();

      final transitions = <(String, String)>[
        ('VISIT_SCHEDULED', 'VISIT_CONFIRMED'),
        ('ARRIVAL_PENDING', 'ARRIVAL_PENDING'),
        ('ON_SITE', 'ARRIVAL_CONFIRMED'),
        ('HIRED', 'SELECTED'),
      ];
      for (final (status, eventType) in transitions) {
        api.bookings = [
          _remoteWorkerBooking(id: 'worker-booking-main', status: status),
          _remoteWorkerBooking(
            id: 'worker-booking-not-selected',
            status: 'PENDING',
          ),
        ];
        await state.fetchRemoteBookings();
        await state.fetchRemoteBookings();

        final messages = state.messages.where(
          (message) => message.id == 'worker:$eventType:worker-booking-main',
        );
        expect(messages, hasLength(1), reason: '$status must be idempotent');
        expect(messages.single.eventType, eventType);
        expect(messages.single.bookingId, 'worker-booking-main');
        expect(messages.single.serviceRequestId, 'service-request-1');
        expect(messages.single.targetAction, 'WORKER_ORDER');
      }

      api.bookings = [
        _remoteWorkerBooking(id: 'worker-booking-main', status: 'HIRED'),
        _remoteWorkerBooking(
          id: 'worker-booking-not-selected',
          status: 'NOT_SELECTED',
        ),
      ];
      await state.fetchRemoteBookings();
      await state.fetchRemoteBookings();

      expect(
        state.messages.where(
          (message) =>
              message.id == 'worker:NOT_SELECTED:worker-booking-not-selected',
        ),
        hasLength(1),
      );
      expect(
        state.messages.where(
          (message) => message.id == 'worker:PENDING:worker-booking-main',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'worker keeps payment snapshots but never fabricates inspection events',
    () async {
      final bookingApi = _FakeWorkerBookingApi([
        _remoteWorkerBooking(id: 'worker-business', status: 'HIRED'),
      ]);
      final inspectionApi = _FakeWorkerInspectionApi([
        _remoteWorkerInspectionNode(status: 'PENDING'),
        _remoteWorkerInspectionNode(
          id: 'unrelated-carpentry-node',
          name: '木工验收',
          status: 'FAILED',
        ),
      ]);
      var paymentStatus = 'PENDING';
      var constructionStatus = 'NOT_REPORTED';
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final Object data = switch (request.url.path) {
            '/api/v1/payment/orders' => {
              'content': [
                _workerPaymentOrderJson(
                  status: paymentStatus,
                  constructionPaymentStatus: constructionStatus,
                ),
              ],
            },
            '/api/v1/settlements' ||
            '/api/v1/warranty-retentions' ||
            '/api/v1/worker-warranty/contributions' => <Object>[],
            _ => <String, Object>{},
          };
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-token');
      state.initBookingApi(api: bookingApi, accessToken: 'worker-token');
      state.initPaymentApi(api: paymentApi, accessToken: 'worker-token');
      state.initInspectionApi(inspectionApi);
      await state.fetchRemoteBookings();
      await state.fetchRemoteInspections();
      await state.fetchRemotePayments();

      inspectionApi.nodes = [
        _remoteWorkerInspectionNode(status: 'FAILED'),
        _remoteWorkerInspectionNode(
          id: 'unrelated-carpentry-node',
          name: '木工验收',
          status: 'FAILED',
        ),
      ];
      paymentStatus = 'OWNER_REPORTED_PAID';
      constructionStatus = 'REPORTED';
      await state.fetchRemoteInspections();
      await state.fetchRemotePayments();
      await state.fetchRemoteInspections();
      await state.fetchRemotePayments();

      expect(
        state.messages.where(
          (message) =>
              message.id == 'worker:INSPECTION_RECTIFICATION:worker-business',
        ),
        isEmpty,
      );
      final paymentReported = state.messages.where(
        (message) => message.id == 'worker:PAYMENT_REPORTED:worker-business',
      );
      expect(paymentReported, hasLength(1));
      expect(paymentReported.single.paymentOrderId, 'worker-payment-1');
      expect(paymentReported.single.targetAction, 'WORKER_PAYMENT');

      inspectionApi.nodes = [
        _remoteWorkerInspectionNode(status: 'PASSED'),
        _remoteWorkerInspectionNode(
          id: 'unrelated-carpentry-node',
          name: '木工验收',
          status: 'FAILED',
        ),
      ];
      constructionStatus = 'CONFIRMED';
      paymentStatus = 'PAID';
      await state.fetchRemoteInspections();
      await state.fetchRemotePayments();

      expect(
        state.messages.where(
          (message) => message.id == 'worker:INSPECTION_PASSED:worker-business',
        ),
        isEmpty,
      );
      expect(
        state.messages.where(
          (message) => message.id == 'worker:RECEIPT_CONFIRMED:worker-business',
        ),
        hasLength(1),
      );
      expect(inspectionApi.bookingCalls, isEmpty);
    },
  );

  test(
    'worker legacy inspection refresh does not poll or create notifications',
    () async {
      final bookingApi = _FakeWorkerBookingApi([
        _remoteWorkerBooking(id: 'worker-first', status: 'HIRED'),
        _remoteWorkerBooking(id: 'worker-second', status: 'HIRED'),
      ]);
      final inspectionApi = _FakeWorkerInspectionApi(const []);
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-token');
      state.initBookingApi(api: bookingApi, accessToken: 'worker-token');
      state.initInspectionApi(inspectionApi);
      await state.fetchRemoteBookings();

      await state.fetchRemoteInspections();

      expect(inspectionApi.bookingCalls, isEmpty);
      expect(
        state.messages.where(
          (message) => message.eventType?.startsWith('INSPECTION_') ?? false,
        ),
        isEmpty,
      );
    },
  );

  testWidgets('pending order card describes needed trade without empty area', (
    tester,
  ) async {
    final state = WorkerAppState.fromJson({
      'profile': {
        'name': '',
        'phone': '',
        'avatar': '',
        'trade': 'painting',
        'tradeSelected': false,
        'serviceCity': '',
        'experienceYears': 0,
        'dailyRate': 0,
        'rating': 0,
        'totalOrders': 0,
        'certifications': <String>[],
        'serviceAreas': <String>[],
        'bio': '',
        'idCard': '',
        'isVerified': false,
      },
      'orders': [
        {
          'id': 'order-painting',
          'ownerName': 'ren',
          'ownerPhone': '13800000000',
          'ownerAddress': 'chengdu',
          'area': '',
          'requirement': '油漆师傅',
          'description': '',
          'trade': '油漆',
          'status': 'pending',
          'createdAt': DateTime.now().toIso8601String(),
          'images': <String>[],
        },
      ],
      'dailyReports': <Map<String, dynamic>>[],
      'inspectionRequests': <Map<String, dynamic>>[],
      'earnings': <Map<String, dynamic>>[],
      'messages': <Map<String, dynamic>>[],
      'settings': <String, dynamic>{},
      'quotations': <Map<String, dynamic>>[],
      'isLoggedIn': false,
      'remoteBookings': <Map<String, dynamic>>[],
    });

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerHomePage(chatApi: _FakeChatApi(rooms: const [])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('需要油漆师傅'), findsOneWidget);
    expect(find.textContaining('油漆师傅（）'), findsNothing);
  });

  testWidgets(
    'opening worker messages tab clears local unread notification badge',
    (tester) async {
      final state = WorkerAppState.fromJson({
        'profile': {
          'name': '',
          'phone': '',
          'avatar': '',
          'trade': 'demolition',
          'tradeSelected': false,
          'serviceCity': '',
          'experienceYears': 0,
          'dailyRate': 0,
          'rating': 0,
          'totalOrders': 0,
          'certifications': <String>[],
          'serviceAreas': <String>[],
          'bio': '',
          'idCard': '',
          'isVerified': false,
        },
        'orders': <Map<String, dynamic>>[],
        'dailyReports': <Map<String, dynamic>>[],
        'inspectionRequests': <Map<String, dynamic>>[],
        'earnings': <Map<String, dynamic>>[],
        'messages': [
          {
            'id': 'notice-1',
            'title': '新的预约待接单',
            'content': '业主预约了您的泥瓦服务，请及时处理。',
            'category': '订单',
            'createdAt': '2026-07-29T10:00:00.000',
            'isRead': false,
          },
        ],
        'settings': <String, dynamic>{},
        'quotations': <Map<String, dynamic>>[],
        'isLoggedIn': true,
        'remoteBookings': <Map<String, dynamic>>[],
      });
      state.loginWithToken('worker-token');

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: WorkerHomePage(chatApi: _FakeChatApi(rooms: const [])),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(state.unreadMessageCount, 1);

      await tester.tap(find.text('消息'));
      await tester.pumpAndSettle();

      expect(state.unreadMessageCount, 0);
      expect(find.textContaining('条通知未读'), findsNothing);
    },
  );

  testWidgets('payment notice opens the matching receipt details', (
    tester,
  ) async {
    final state = WorkerAppState.fromJson({
      'profile': {
        'name': '张师傅',
        'phone': '13800138000',
        'avatar': '',
        'trade': 'painting',
        'tradeSelected': true,
        'serviceCity': '成都',
        'experienceYears': 8,
        'dailyRate': 500,
        'rating': 0,
        'totalOrders': 0,
        'certifications': <String>[],
        'serviceAreas': <String>[],
        'bio': '油漆施工',
        'idCard': '',
        'isVerified': true,
      },
      'orders': <Map<String, dynamic>>[],
      'dailyReports': <Map<String, dynamic>>[],
      'inspectionRequests': <Map<String, dynamic>>[],
      'earnings': <Map<String, dynamic>>[],
      'messages': [
        {
          'id': 'payment-notice-1',
          'title': '业主已付款，待确认收款',
          'content': '请查看费用明细并确认收款。',
          'category': '收入',
          'createdAt': '2026-08-01T10:01:00Z',
          'isRead': false,
          'orderId': 'booking-1',
          'paymentOrderId': 'payment-1',
          'eventType': 'PAYMENT_REPORTED',
          'bookingId': 'booking-1',
          'serviceRequestId': 'service-request-1',
          'targetAction': 'WORKER_PAYMENT',
        },
      ],
      'settings': <String, dynamic>{},
      'quotations': <Map<String, dynamic>>[],
      'isLoggedIn': false,
      'remoteBookings': <Map<String, dynamic>>[],
    });
    state.loginWithToken('worker-token');
    final paymentApi = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/worker-warranty/account') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({'code': 'NOT_FOUND', 'message': 'not found'}),
            ),
            404,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final data = switch (request.url.path) {
          '/api/v1/payment/orders/payment-1' => _paymentOrderJson,
          '/api/v1/payment/orders' => {
            'content': [_paymentOrderJson],
          },
          '/api/v1/settlements' => <Map<String, dynamic>>[],
          '/api/v1/warranty-retentions' => <Map<String, dynamic>>[],
          '/api/v1/worker-warranty/contributions' => <Map<String, dynamic>>[],
          _ => <Map<String, dynamic>>[],
        };
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final quoteApi = WorkerQuoteApiClient(
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
                  'workerUserId': 'worker-1',
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

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerHomePage(
            chatApi: _FakeChatApi(rooms: const []),
            paymentApi: paymentApi,
            quoteApi: quoteApi,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('业主已付款，待确认收款'));
    await tester.pumpAndSettle();
    final receiptCard = find.byKey(
      const ValueKey('worker-pending-receipt-payment-1'),
    );
    expect(receiptCard, findsOneWidget);
    final receiptTextData = _nonEmptyTextDataWithin(receiptCard);
    expect(
      receiptTextData.where((text) => text.contains('¥')),
      unorderedEquals(['待结算 ¥5220.00', '¥5800.00', '¥5220.00', '¥580.00']),
    );
    expect(
      receiptTextData.where((text) => text.contains('%')),
      unorderedEquals(['可结算 90%', '质保金冻结 10%']),
    );
    expect(find.text('结算'), findsOneWidget);
    expect(find.text('费用明细'), findsOneWidget);
    expect(find.text('报价清单总价'), findsOneWidget);
    expect(find.text('¥5800.00'), findsOneWidget);
    expect(find.text('可结算 90%'), findsOneWidget);
    expect(find.text('¥5220.00'), findsOneWidget);
    expect(find.text('质保金冻结 10%'), findsOneWidget);
    expect(find.text('¥580.00'), findsOneWidget);
    _expectNoWorkerFeeText(receiptTextData);
    expect(find.text('查看报价明细'), findsOneWidget);

    await tester.tap(find.text('查看报价明细'));
    await tester.pumpAndSettle();
    expect(find.text('人工明细'), findsOneWidget);
    expect(find.text('墙面刷漆'), findsOneWidget);
    expect(find.text('材料明细'), findsOneWidget);
    expect(find.text('乳胶漆材料'), findsOneWidget);
  });

  testWidgets(
    'worker home and income entry show the real settlement and warranty amounts',
    (tester) async {
      final state = WorkerAppState.fromJson({
        'profile': {
          'name': 'zg',
          'phone': '13800138000',
          'avatar': '',
          'trade': 'painting',
          'tradeSelected': true,
          'serviceCity': '成都',
          'experienceYears': 8,
          'dailyRate': 500,
          'rating': 0,
          'totalOrders': 0,
          'certifications': <String>[],
          'serviceAreas': <String>[],
          'bio': '油漆施工',
          'idCard': '',
          'isVerified': true,
        },
        'orders': <Map<String, dynamic>>[],
        'dailyReports': <Map<String, dynamic>>[],
        'inspectionRequests': <Map<String, dynamic>>[],
        'earnings': <Map<String, dynamic>>[],
        'messages': <Map<String, dynamic>>[],
        'settings': <String, dynamic>{},
        'quotations': <Map<String, dynamic>>[],
        'isLoggedIn': false,
        'remoteBookings': <Map<String, dynamic>>[],
      });
      state.loginWithToken('worker-token');
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          if (request.url.path == '/api/v1/worker-warranty/account') {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({'code': 'NOT_FOUND', 'message': 'not found'}),
              ),
              404,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            );
          }
          final data = switch (request.url.path) {
            '/api/v1/payment/orders' => {'content': <Map<String, dynamic>>[]},
            '/api/v1/settlements' => [_settleableSettlementJson],
            '/api/v1/warranty-retentions' => [_heldWarrantyJson],
            '/api/v1/worker-warranty/contributions' => <Map<String, dynamic>>[],
            _ => <Map<String, dynamic>>[],
          };
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      state.initPaymentApi(api: paymentApi, accessToken: 'worker-token');

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: WorkerHomePage(
              chatApi: _FakeChatApi(rooms: const []),
              paymentApi: paymentApi,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('可结算'), findsOneWidget);
      expect(find.text('¥5220'), findsOneWidget);
      expect(find.text('质保金'), findsOneWidget);
      expect(find.text('¥580'), findsOneWidget);

      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('收入明细').last);
      await tester.pumpAndSettle();

      expect(find.text('结算'), findsOneWidget);
      expect(find.text('收款记录'), findsOneWidget);
      expect(find.text('¥5220.00'), findsOneWidget);
      expect(find.text('质保冻结中'), findsOneWidget);
      expect(find.text('¥580.00'), findsNWidgets(2));
    },
  );

  testWidgets('worker order notice opens the exact order detail', (
    tester,
  ) async {
    final state = _workerStateWithNotification(
      includeOrder: true,
      bookingId: 'booking-exact',
    );
    state.loginWithToken('worker-token');

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerHomePage(chatApi: _FakeChatApi(rooms: const [])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上门时间已确认'));
    await tester.pumpAndSettle();

    expect(find.byType(OrderDetailPage), findsOneWidget);
    expect(
      tester.widget<OrderDetailPage>(find.byType(OrderDetailPage)).orderId,
      'booking-exact',
    );
  });

  testWidgets('stale worker order notice never falls back to another order', (
    tester,
  ) async {
    final state = _workerStateWithNotification(
      includeOrder: false,
      bookingId: 'booking-missing',
    );
    state.loginWithToken('worker-token');

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerHomePage(chatApi: _FakeChatApi(rooms: const [])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('上门时间已确认'));
    await tester.pumpAndSettle();

    expect(find.text('该记录已更新或不再可用'), findsOneWidget);
    expect(find.byType(OrderDetailPage), findsNothing);
  });

  testWidgets(
    'stale worker inspection notice never creates missing inspection nodes',
    (tester) async {
      final state = _workerStateWithNotification(
        includeOrder: true,
        bookingId: 'booking-inspection-missing',
        eventType: 'INSPECTION_RECTIFICATION',
        targetAction: 'WORKER_INSPECTION',
        title: '验收需整改',
      );
      state.loginWithToken('worker-token');
      final inspectionApi = _FakeWorkerInspectionApi(const []);

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: WorkerHomePage(
              chatApi: _FakeChatApi(rooms: const []),
              inspectionApi: inspectionApi,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('消息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('验收需整改'));
      await tester.pumpAndSettle();

      expect(find.text('该记录已更新或不再可用'), findsOneWidget);
      expect(find.byType(InspectionPage), findsNothing);
    },
  );

  testWidgets('worker inspection event opens its exact node and booking', (
    tester,
  ) async {
    final state = _workerStateWithNotification(
      includeOrder: true,
      bookingId: 'booking-inspection-exact',
      eventType: 'INSPECTION_RECTIFICATION_REQUIRED',
      targetAction: 'WORKER_INSPECTION',
      title: '精确验收节点',
      aggregateType: 'INSPECTION_NODE',
      aggregateId: 'node-exact',
    );
    final api = _FakeWorkerInspectionApi([
      _remoteWorkerInspectionNode(
        status: 'FAILED',
        id: 'node-exact',
        bookingId: 'booking-inspection-exact',
      ),
      _remoteWorkerInspectionNode(
        status: 'FAILED',
        id: 'node-other',
        bookingId: 'booking-inspection-exact',
      ),
    ]);

    await _pumpWorkerNotification(tester, state: state, inspectionApi: api);
    await tester.tap(find.text('精确验收节点'));
    await tester.pumpAndSettle();

    final page = tester.widget<InspectionPage>(find.byType(InspectionPage));
    expect(page.orderId, 'booking-inspection-exact');
    expect(page.initialNodeId, 'node-exact');
  });

  testWidgets('worker inspection event rejects a node from another booking', (
    tester,
  ) async {
    final state = _workerStateWithNotification(
      includeOrder: true,
      bookingId: 'booking-inspection-target',
      eventType: 'INSPECTION_PASSED',
      targetAction: 'WORKER_INSPECTION',
      title: '错配验收节点',
      aggregateType: 'INSPECTION_NODE',
      aggregateId: 'node-mismatch',
    );
    final api = _FakeWorkerInspectionApi([
      _remoteWorkerInspectionNode(
        status: 'PASSED',
        id: 'node-mismatch',
        bookingId: 'booking-other',
      ),
    ]);

    await _pumpWorkerNotification(tester, state: state, inspectionApi: api);
    await tester.tap(find.text('错配验收节点'));
    await tester.pumpAndSettle();

    expect(find.text('该记录已更新或不再可用'), findsOneWidget);
    expect(find.byType(InspectionPage), findsNothing);
  });

  testWidgets(
    'worker inspection event distinguishes temporary network failure',
    (tester) async {
      final state = _workerStateWithNotification(
        includeOrder: true,
        bookingId: 'booking-inspection-network',
        eventType: 'INSPECTION_PASSED',
        targetAction: 'WORKER_INSPECTION',
        title: '验收网络失败',
        aggregateType: 'INSPECTION_NODE',
        aggregateId: 'node-network',
      );
      final api = _FakeWorkerInspectionApi(
        const [],
        error: StateError('temporary failure'),
      );

      await _pumpWorkerNotification(tester, state: state, inspectionApi: api);
      await tester.tap(find.text('验收网络失败'));
      await tester.pumpAndSettle();

      expect(find.text('暂时无法打开，请稍后重试'), findsOneWidget);
      expect(find.byType(InspectionPage), findsNothing);
    },
  );

  testWidgets('worker inspection event treats a target 404 as stale', (
    tester,
  ) async {
    final state = _workerStateWithNotification(
      includeOrder: true,
      bookingId: 'booking-inspection-missing',
      eventType: 'INSPECTION_PASSED',
      targetAction: 'WORKER_INSPECTION',
      title: '验收目标已失效',
      aggregateType: 'INSPECTION_NODE',
      aggregateId: 'node-missing',
    );
    final api = _FakeWorkerInspectionApi(
      const [],
      error: const AuthApiException(
        code: 'INSPECTION_NODE_NOT_FOUND',
        message: '验收节点不存在',
        statusCode: 404,
      ),
    );

    await _pumpWorkerNotification(tester, state: state, inspectionApi: api);
    await tester.tap(find.text('验收目标已失效'));
    await tester.pumpAndSettle();

    expect(find.text('该记录已更新或不再可用'), findsOneWidget);
    expect(find.byType(InspectionPage), findsNothing);
  });

  testWidgets('worker booking refresh failure never looks like a stale event', (
    tester,
  ) async {
    final state = _workerStateWithNotification(
      includeOrder: false,
      bookingId: 'booking-not-cached',
      eventType: 'INSPECTION_RECTIFICATION_REQUIRED',
      targetAction: 'WORKER_INSPECTION',
      title: '工人预约刷新失败',
      aggregateType: 'INSPECTION_NODE',
      aggregateId: 'node-not-cached',
    );
    state.initBookingApi(
      api: _FakeWorkerBookingApi(
        const [],
        error: const AuthApiException(
          code: 'BOOKING_UNAVAILABLE',
          message: '服务繁忙',
          statusCode: 503,
        ),
      ),
      accessToken: 'worker-token',
    );
    final api = _FakeWorkerInspectionApi([
      _remoteWorkerInspectionNode(
        status: 'FAILED',
        id: 'node-not-cached',
        bookingId: 'booking-not-cached',
      ),
    ]);

    await _pumpWorkerNotification(tester, state: state, inspectionApi: api);
    await tester.tap(find.text('工人预约刷新失败'));
    await tester.pumpAndSettle();

    expect(find.text('暂时无法打开，请稍后重试'), findsOneWidget);
    expect(find.text('该记录已更新或不再可用'), findsNothing);
    expect(find.byType(InspectionPage), findsNothing);
  });

  testWidgets('worker after-sale event opens its exact ticket detail', (
    tester,
  ) async {
    final state = _workerStateWithNotification(
      includeOrder: true,
      bookingId: 'booking-after-sale-exact',
      eventType: 'AFTER_SALE_CREATED',
      targetAction: 'WORKER_AFTER_SALE',
      title: '精确售后工单',
      aggregateType: 'AFTER_SALE',
      aggregateId: 'after-sale-exact',
    );
    final api = _WorkerMessageAfterSaleApi(
      _workerAfterSaleDetail(
        afterSaleId: 'after-sale-exact',
        bookingId: 'booking-after-sale-exact',
      ),
    );

    await _pumpWorkerNotification(tester, state: state, paymentApi: api);
    await tester.tap(find.text('精确售后工单'));
    await tester.pumpAndSettle();

    final page = tester.widget<AfterSaleDetailPage>(
      find.byType(AfterSaleDetailPage),
    );
    expect(page.afterSaleId, 'after-sale-exact');
  });

  testWidgets('worker after-sale event rejects a ticket from another booking', (
    tester,
  ) async {
    final state = _workerStateWithNotification(
      includeOrder: true,
      bookingId: 'booking-after-sale-target',
      eventType: 'AFTER_SALE_RESOLVED',
      targetAction: 'WORKER_AFTER_SALE',
      title: '错配售后工单',
      aggregateType: 'AFTER_SALE',
      aggregateId: 'after-sale-mismatch',
    );
    final api = _WorkerMessageAfterSaleApi(
      _workerAfterSaleDetail(
        afterSaleId: 'after-sale-mismatch',
        bookingId: 'booking-other',
      ),
    );

    await _pumpWorkerNotification(tester, state: state, paymentApi: api);
    await tester.tap(find.text('错配售后工单'));
    await tester.pumpAndSettle();

    expect(find.text('该记录已更新或不再可用'), findsOneWidget);
    expect(find.byType(AfterSaleDetailPage), findsNothing);
  });

  testWidgets(
    'worker after-sale event distinguishes temporary network failure',
    (tester) async {
      final state = _workerStateWithNotification(
        includeOrder: true,
        bookingId: 'booking-after-sale-network',
        eventType: 'AFTER_SALE_CLOSED',
        targetAction: 'WORKER_AFTER_SALE',
        title: '售后网络失败',
        aggregateType: 'AFTER_SALE',
        aggregateId: 'after-sale-network',
      );
      final api = _WorkerMessageAfterSaleApi(
        null,
        error: const PaymentApiException(statusCode: 503, message: '服务繁忙'),
      );

      await _pumpWorkerNotification(tester, state: state, paymentApi: api);
      await tester.tap(find.text('售后网络失败'));
      await tester.pumpAndSettle();

      expect(find.text('暂时无法打开，请稍后重试'), findsOneWidget);
      expect(find.byType(AfterSaleDetailPage), findsNothing);
    },
  );

  testWidgets('worker after-sale event treats a target 404 as stale', (
    tester,
  ) async {
    final state = _workerStateWithNotification(
      includeOrder: true,
      bookingId: 'booking-after-sale-missing',
      eventType: 'AFTER_SALE_CLOSED',
      targetAction: 'WORKER_AFTER_SALE',
      title: '售后目标已失效',
      aggregateType: 'AFTER_SALE',
      aggregateId: 'after-sale-missing',
    );
    final api = _WorkerMessageAfterSaleApi(
      null,
      error: const PaymentApiException(statusCode: 404, message: '工单不存在'),
    );

    await _pumpWorkerNotification(tester, state: state, paymentApi: api);
    await tester.tap(find.text('售后目标已失效'));
    await tester.pumpAndSettle();

    expect(find.text('该记录已更新或不再可用'), findsOneWidget);
    expect(find.byType(AfterSaleDetailPage), findsNothing);
  });

  testWidgets(
    'worker payment notice rejects a payment order from another booking',
    (tester) async {
      final state = _workerStateWithNotification(
        includeOrder: false,
        bookingId: 'booking-expected',
        eventType: 'PAYMENT_REPORTED',
        targetAction: 'WORKER_PAYMENT',
        title: '错配收款通知',
        paymentOrderId: 'payment-wrong-booking',
      );
      state.loginWithToken('worker-token');
      final wrongOrder = _workerPaymentOrderJson(
        status: 'OWNER_REPORTED_PAID',
        constructionPaymentStatus: 'REPORTED',
        id: 'payment-wrong-booking',
        bookingId: 'booking-other',
      );
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final Object data = switch (request.url.path) {
            '/api/v1/payment/orders/payment-wrong-booking' => wrongOrder,
            '/api/v1/payment/orders' => {
              'content': [wrongOrder],
            },
            '/api/v1/settlements' ||
            '/api/v1/warranty-retentions' ||
            '/api/v1/worker-warranty/contributions' => <Object>[],
            _ => <String, Object>{},
          };
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: WorkerHomePage(
              chatApi: _FakeChatApi(rooms: const []),
              paymentApi: paymentApi,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('消息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('错配收款通知'));
      await tester.pumpAndSettle();

      expect(find.text('该记录已更新或不再可用'), findsOneWidget);
      expect(find.byType(WorkerSettlementPage), findsNothing);
    },
  );

  testWidgets(
    'worker payment notice reports temporary API failure without stale fallback',
    (tester) async {
      final state = _workerStateWithNotification(
        includeOrder: false,
        bookingId: 'booking-payment-temporary',
        eventType: 'PAYMENT_REPORTED',
        targetAction: 'WORKER_PAYMENT',
        title: '待确认收款通知',
        paymentOrderId: 'payment-temporary',
      );
      state.loginWithToken('worker-token');
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient(
          (request) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'TEMPORARILY_UNAVAILABLE',
                'message': 'try again',
              }),
            ),
            503,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: WorkerHomePage(
              chatApi: _FakeChatApi(rooms: const []),
              paymentApi: paymentApi,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('消息'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('待确认收款通知'));
      await tester.pumpAndSettle();

      expect(find.text('暂时无法打开，请稍后重试'), findsOneWidget);
      expect(find.text('该记录已更新或不再可用'), findsNothing);
      expect(find.byType(WorkerSettlementPage), findsNothing);
    },
  );

  testWidgets(
    'split receipt confirmation keeps exact worker copy and review funds',
    (tester) async {
      final state = WorkerAppState.fromJson({
        'profile': {
          'name': '木工张师傅',
          'phone': '13800138000',
          'avatar': '',
          'trade': 'carpentry',
          'tradeSelected': true,
          'serviceCity': '成都',
          'experienceYears': 8,
          'dailyRate': 500,
          'rating': 0,
          'totalOrders': 0,
          'certifications': <String>[],
          'serviceAreas': <String>[],
          'bio': '木工施工',
          'idCard': '',
          'isVerified': true,
        },
        'orders': <Map<String, dynamic>>[],
        'dailyReports': <Map<String, dynamic>>[],
        'inspectionRequests': <Map<String, dynamic>>[],
        'earnings': <Map<String, dynamic>>[],
        'messages': <Map<String, dynamic>>[],
        'settings': <String, dynamic>{},
        'quotations': <Map<String, dynamic>>[],
        'isLoggedIn': false,
        'remoteBookings': <Map<String, dynamic>>[],
      });
      state.loginWithToken('worker-token');
      var receiptConfirmed = false;
      var confirmationRequests = 0;
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final confirmedOrder = {
            ..._splitPaymentOrderJson,
            'constructionPaymentStatus': 'CONFIRMED',
            'status': 'UNDER_REVIEW',
            'constructionConfirmedAt': '2026-08-06T10:02:00Z',
            'updatedAt': '2026-08-06T10:02:00Z',
          };
          if (request.method == 'POST' &&
              request.url.path ==
                  '/api/v1/payment/orders/payment-split-1/construction-receipt-confirmation') {
            confirmationRequests += 1;
            receiptConfirmed = true;
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'code': 'OK',
                  'message': 'success',
                  'data': confirmedOrder,
                }),
              ),
              200,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            );
          }
          final data = switch (request.url.path) {
            '/api/v1/payment/orders' => {
              'content': [
                receiptConfirmed ? confirmedOrder : _splitPaymentOrderJson,
              ],
            },
            '/api/v1/settlements' => <Map<String, dynamic>>[],
            '/api/v1/warranty-retentions' => <Map<String, dynamic>>[],
            '/api/v1/worker-warranty/account' => _workerWarrantyAccountJson,
            '/api/v1/worker-warranty/contributions' => [
              _workerWarrantyContributionJson,
            ],
            _ => <Map<String, dynamic>>[],
          };
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      state.initPaymentApi(api: paymentApi, accessToken: 'worker-token');

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: WorkerHomePage(
              chatApi: _FakeChatApi(rooms: const []),
              paymentApi: paymentApi,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('履约质保金'), findsOneWidget);
      expect(find.text('¥3084'), findsOneWidget);

      await tester.tap(find.text('收入明细'));
      await tester.pumpAndSettle();
      final receiptCard = find.byKey(
        const ValueKey('worker-pending-receipt-payment-split-1'),
      );
      expect(receiptCard, findsOneWidget);
      final receiptTextData = _nonEmptyTextDataWithin(receiptCard);
      expect(
        receiptTextData.where((text) => text.contains('¥')),
        unorderedEquals(['本单应收 ¥10840.00', '¥10840.00', '¥10840.00']),
      );
      expect(receiptTextData.where((text) => text.contains('%')), isEmpty);
      _expectNoWorkerFeeText(receiptTextData);

      expect(find.text('本单应收 ¥10840.00'), findsOneWidget);
      expect(find.text('履约质保金账户'), findsOneWidget);
      expect(find.text('待补金额'), findsOneWidget);

      await tester.tap(find.text('查看无误，确认收款'));
      await tester.pumpAndSettle();

      expect(find.text('确认收款信息'), findsOneWidget);
      expect(
        find.text('请先核对报价明细和实际到账。本单工程款应全额收到 ¥10840.00，确认后将记录工程款到账状态。'),
        findsOneWidget,
      );

      await tester.tap(find.text('确认无误'));
      await tester.pumpAndSettle();

      expect(confirmationRequests, 1);
      expect(find.text('已确认工程款到账，付款状态核验中'), findsOneWidget);
      final reviewCard = find.byKey(
        const ValueKey('worker-payment-review-payment-split-1'),
      );
      expect(reviewCard, findsOneWidget);
      final reviewTextData = _nonEmptyTextDataWithin(reviewCard);
      expect(reviewTextData.where((text) => text.contains('¥')), [
        '工程款 ¥10840.00 已确认到账',
      ]);
      expect(reviewTextData.where((text) => text.contains('%')), isEmpty);
      _expectNoWorkerFeeText(reviewTextData);
    },
  );

  testWidgets(
    'completed job shows its real income and opens the completed archive',
    (tester) async {
      final state = WorkerAppState.fromJson({
        'profile': {
          'name': 'zg',
          'phone': '13800138000',
          'avatar': '',
          'trade': 'painting',
          'tradeSelected': true,
          'serviceCity': '成都',
          'experienceYears': 8,
          'dailyRate': 500,
          'rating': 0,
          'totalOrders': 0,
          'certifications': <String>[],
          'serviceAreas': <String>[],
          'bio': '油漆施工',
          'idCard': '',
          'isVerified': true,
        },
        'orders': [
          {
            'id': 'booking-1',
            'ownerName': 'ren',
            'ownerPhone': '13800000000',
            'ownerAddress': '成都高新区',
            'area': '80㎡',
            'requirement': '油漆师傅',
            'description': '全屋墙面翻新',
            'trade': '油漆',
            'status': 'completed',
            'createdAt': '2026-08-01T08:00:00Z',
            'images': <String>[],
          },
        ],
        'dailyReports': <Map<String, dynamic>>[],
        'inspectionRequests': <Map<String, dynamic>>[],
        'earnings': <Map<String, dynamic>>[],
        'messages': <Map<String, dynamic>>[],
        'settings': <String, dynamic>{},
        'quotations': <Map<String, dynamic>>[],
        'isLoggedIn': false,
        'remoteBookings': <Map<String, dynamic>>[],
      });
      state.loginWithToken('worker-token');
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final data = switch (request.url.path) {
            '/api/v1/payment/orders' => {'content': <Map<String, dynamic>>[]},
            '/api/v1/settlements' => [_settleableSettlementJson],
            '/api/v1/warranty-retentions' => [_heldWarrantyJson],
            _ => <Map<String, dynamic>>[],
          };
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      state.initPaymentApi(api: paymentApi, accessToken: 'worker-token');
      await state.fetchRemotePayments();

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: WorkerHomePage(
              chatApi: _FakeChatApi(rooms: const []),
              paymentApi: paymentApi,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('收入明细'), findsOneWidget);

      await tester.tap(find.text('已完成'));
      await tester.pumpAndSettle();

      expect(find.text('本单可结算 ¥5220'), findsOneWidget);
      expect(find.text('质保金 ¥580'), findsOneWidget);
      expect(find.text('查看完工档案'), findsOneWidget);

      await tester.tap(find.text('查看完工档案'));
      await tester.pumpAndSettle();

      expect(find.text('完工档案'), findsOneWidget);
    },
  );

  testWidgets('worker bottom navigation stays above Android system inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await WorkerAppState.memory();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(bottom: 48),
              viewPadding: const EdgeInsets.only(bottom: 48),
            ),
            child: child!,
          ),
          home: const WorkerHomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final navigation = find.byKey(
      const Key('worker-bottom-navigation-content'),
    );
    expect(navigation, findsOneWidget);
    expect(tester.getBottomRight(navigation).dy, 752);
  });

  testWidgets('worker messages tab shows remote chat room previews', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    await state.loginOnline(_workerLoginResponse);
    final api = _FakeChatApi();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(home: WorkerHomePage(chatApi: api)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();

    expect(find.text('wz'), findsOneWidget);
    expect(find.text('hhh'), findsOneWidget);
    expect(find.text('暂无消息'), findsNothing);

    await tester.tap(find.text('wz'));
    await tester.pumpAndSettle();

    expect(api.markedRoomIds, contains('room-1'));
    expect(find.text('1'), findsNothing);
  });
}

Future<void> _pumpWorkerNotification(
  WidgetTester tester, {
  required WorkerAppState state,
  InspectionApi? inspectionApi,
  PaymentApiClient? paymentApi,
}) async {
  state.loginWithToken('worker-token');
  await tester.pumpWidget(
    WorkerAppScope(
      state: state,
      child: MaterialApp(
        home: WorkerHomePage(
          chatApi: _FakeChatApi(rooms: const []),
          inspectionApi: inspectionApi,
          paymentApi: paymentApi,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('消息'));
  await tester.pumpAndSettle();
}

AfterSaleDetailModel _workerAfterSaleDetail({
  required String afterSaleId,
  required String bookingId,
}) => AfterSaleDetailModel(
  ticket: AfterSaleModel(
    id: afterSaleId,
    bookingId: bookingId,
    ownerUserId: 'owner-user-id',
    workerUserId: 'worker-user-id',
    type: 'COMPLAINT',
    reason: '精确工单',
    status: 'OPEN',
    createdAt: '2026-08-09T08:00:00Z',
    updatedAt: '2026-08-09T08:00:00Z',
  ),
  context: AfterSaleOrderContextModel(
    bookingId: bookingId,
    trade: 'painting',
    inspection: const AfterSaleInspectionSummaryModel(
      status: 'PASSED',
      passedCount: 1,
      totalCount: 1,
    ),
  ),
  timeline: const [],
);

final class _WorkerMessageAfterSaleApi extends PaymentApiClient {
  _WorkerMessageAfterSaleApi(this.detail, {this.error});

  final AfterSaleDetailModel? detail;
  final Object? error;

  @override
  Future<AfterSaleDetailModel> getAfterSale(
    String accessToken,
    String id,
  ) async {
    if (error case final failure?) throw failure;
    return detail!;
  }
}

WorkerAppState _workerStateWithNotification({
  required bool includeOrder,
  required String bookingId,
  String eventType = 'VISIT_CONFIRMED',
  String targetAction = 'WORKER_ORDER',
  String title = '上门时间已确认',
  String? paymentOrderId,
  String? aggregateType,
  String? aggregateId,
}) => WorkerAppState.fromJson({
  'profile': {
    'name': '张师傅',
    'phone': '13800138000',
    'avatar': '',
    'trade': 'painting',
    'tradeSelected': true,
    'serviceCity': '成都',
    'experienceYears': 8,
    'dailyRate': 500,
    'rating': 0,
    'totalOrders': 0,
    'certifications': <String>[],
    'serviceAreas': <String>[],
    'bio': '油漆施工',
    'idCard': '',
    'isVerified': true,
  },
  'orders': [
    if (includeOrder)
      {
        'id': bookingId,
        'ownerName': '王先生',
        'ownerPhone': '13800000000',
        'ownerAddress': '成都高新区',
        'area': '80㎡',
        'requirement': '油漆师傅',
        'description': '全屋墙面翻新',
        'trade': '油漆',
        'status': 'visitScheduled',
        'createdAt': '2026-08-08T08:00:00Z',
        'images': <String>[],
      },
  ],
  'dailyReports': <Map<String, dynamic>>[],
  'inspectionRequests': <Map<String, dynamic>>[],
  'earnings': <Map<String, dynamic>>[],
  'messages': [
    {
      'id': 'worker:$eventType:$bookingId',
      'title': title,
      'content': '业主已确认上门时间，请按时到达。',
      'category': '订单',
      'createdAt': '2026-08-08T09:00:00Z',
      'isRead': false,
      'eventType': eventType,
      'bookingId': bookingId,
      'serviceRequestId': 'service-request-1',
      // ignore: use_null_aware_elements
      if (paymentOrderId != null) 'paymentOrderId': paymentOrderId,
      'targetAction': targetAction,
      // ignore: use_null_aware_elements
      if (aggregateType != null) 'aggregateType': aggregateType,
      // ignore: use_null_aware_elements
      if (aggregateId != null) 'aggregateId': aggregateId,
    },
  ],
  'settings': <String, dynamic>{},
  'quotations': <Map<String, dynamic>>[],
  'isLoggedIn': false,
  'sessionUserId': 'worker-user-id',
  'remoteBookings': <Map<String, dynamic>>[],
});

RemoteWorkerBooking _remoteWorkerBooking({
  required String id,
  required String status,
}) => RemoteWorkerBooking(
  id: id,
  ownerUserId: 'owner-user-id',
  ownerName: '王先生',
  ownerPhone: '13800138000',
  serviceRequestId: 'service-request-1',
  workerUserId: 'worker-user-id',
  workerName: '张师傅',
  trade: 'painting',
  serviceCity: '成都',
  serviceAddress: '成都高新区',
  remark: '全屋墙面翻新',
  status: status,
  createdAt: DateTime.utc(2026, 8, 8, 8),
  updatedAt: DateTime.utc(2026, 8, 8, 9),
);

RemoteInspectionNode _remoteWorkerInspectionNode({
  required String status,
  String id = 'worker-inspection-1',
  String name = '油漆验收',
  String bookingId = 'worker-business',
}) => RemoteInspectionNode(
  id: id,
  bookingId: bookingId,
  name: name,
  status: status,
  sortOrder: 1,
  createdAt: DateTime.utc(2026, 8, 8, 9),
  updatedAt: DateTime.utc(2026, 8, 8, 10),
);

Map<String, dynamic> _workerPaymentOrderJson({
  required String status,
  required String constructionPaymentStatus,
  String id = 'worker-payment-1',
  String bookingId = 'worker-business',
}) => {
  'id': id,
  'bookingId': bookingId,
  'ownerUserId': 'owner-user-id',
  'workerUserId': 'worker-user-id',
  'quoteId': 'quote-1',
  'amount': 1100,
  'platformFee': 100,
  'workerSettlement': 1000,
  'warrantyRetention': 0,
  'fundingModel': 'OFFLINE_SPLIT_V2',
  'quoteAmount': 1000,
  'constructionPaymentStatus': constructionPaymentStatus,
  'platformFeeStatus': 'NOT_REPORTED',
  'status': status,
  'paymentMethod': 'OFFLINE',
  'constructionConfirmedAt': constructionPaymentStatus == 'CONFIRMED'
      ? '2026-08-08T10:30:00Z'
      : null,
  'createdAt': '2026-08-08T09:00:00Z',
  'updatedAt': '2026-08-08T10:00:00Z',
};

final class _FakeWorkerBookingApi implements WorkerBookingApi {
  _FakeWorkerBookingApi(this.bookings, {this.error});

  List<RemoteWorkerBooking> bookings;
  final Object? error;

  @override
  Future<List<RemoteWorkerBooking>> listWorkerBookings(
    String accessToken,
  ) async {
    if (error case final failure?) throw failure;
    return bookings;
  }

  @override
  Future<RemoteWorkerBooking> acceptBooking(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteWorkerBooking> rejectBooking(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteWorkerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();
}

final class _FakeWorkerInspectionApi implements InspectionApi {
  _FakeWorkerInspectionApi(this.nodes, {this.error});

  List<RemoteInspectionNode> nodes;
  final Object? error;
  Completer<List<RemoteInspectionNode>>? nextGet;
  final bookingCalls = <String>[];

  @override
  Future<List<RemoteInspectionNode>> getNodes(
    String accessToken,
    String bookingId,
  ) async {
    bookingCalls.add(bookingId);
    if (error case final failure?) throw failure;
    final pending = nextGet;
    if (pending != null) {
      nextGet = null;
      return pending.future;
    }
    return nodes.where((node) => node.bookingId == bookingId).toList();
  }

  @override
  Future<List<RemoteInspectionNode>> createNodes(
    String accessToken,
    String bookingId,
    List<Map<String, dynamic>> nodes,
  ) => throw UnimplementedError();

  @override
  Future<RemoteInspectionNode> requestInspection(
    String accessToken,
    String nodeId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteInspectionRecord> inspect(
    String accessToken,
    String nodeId,
    String result,
    String? comment,
    List<String> photos,
  ) => throw UnimplementedError();

  @override
  Future<List<RemoteInspectionRecord>> getRecords(
    String accessToken,
    String nodeId,
  ) => throw UnimplementedError();
}

List<String> _nonEmptyTextDataWithin(Finder scope) {
  final textData = <String>[];
  final elements = find
      .descendant(
        of: scope,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Text || widget is SelectableText || widget is RichText,
        ),
      )
      .evaluate();
  for (final element in elements) {
    final widget = element.widget;
    String? value;
    if (widget is Text) {
      value = widget.data ?? widget.textSpan?.toPlainText();
    } else if (widget is SelectableText) {
      value = widget.data ?? widget.textSpan?.toPlainText();
    } else if (widget is RichText) {
      var nestedUnderTextWidget = false;
      element.visitAncestorElements((ancestor) {
        if (ancestor.widget is Text || ancestor.widget is SelectableText) {
          nestedUnderTextWidget = true;
          return false;
        }
        return true;
      });
      if (!nestedUnderTextWidget) value = widget.text.toPlainText();
    }
    if (value != null && value.isNotEmpty) textData.add(value);
  }
  return textData;
}

void _expectNoWorkerFeeText(List<String> textData) {
  expect(
    _workerFeeSynonyms.hasMatch(textData.join('\n')),
    isFalse,
    reason: 'worker-scoped copy must not expose fee-attribution synonyms',
  );
}

const _paymentOrderJson = {
  'id': 'payment-1',
  'bookingId': 'booking-1',
  'ownerUserId': 'owner-1',
  'workerUserId': 'worker-1',
  'quoteId': 'quote-1',
  'amount': 6380,
  'platformFee': 580,
  'workerSettlement': 5220,
  'warrantyRetention': 580,
  'status': 'OWNER_REPORTED_PAID',
  'paymentMethod': 'OFFLINE',
  'createdAt': '2026-08-01T10:00:00Z',
  'updatedAt': '2026-08-01T10:01:00Z',
};

const _splitPaymentOrderJson = {
  'id': 'payment-split-1',
  'bookingId': 'booking-split-1',
  'ownerUserId': 'owner-1',
  'workerUserId': 'worker-1',
  'quoteId': 'quote-split-1',
  'amount': 11924,
  'platformFee': 1084,
  'workerSettlement': 10840,
  'warrantyRetention': 0,
  'fundingModel': 'OFFLINE_SPLIT_V2',
  'quoteAmount': 10840,
  'constructionPaymentStatus': 'REPORTED',
  'platformFeeStatus': 'REPORTED',
  'status': 'UNDER_REVIEW',
  'paymentMethod': 'OFFLINE',
  'constructionPaymentChannel': 'BANK_TRANSFER',
  'constructionPaymentReference': 'CONSTRUCTION-001',
  'createdAt': '2026-08-06T10:00:00Z',
  'updatedAt': '2026-08-06T10:01:00Z',
};

const _workerWarrantyAccountJson = {
  'id': 'warranty-account-1',
  'workerUserId': 'worker-1',
  'effectiveBalance': 3084,
  'deductedTotal': 0,
  'releasedTotal': 0,
  'capAmount': 10000,
  'outstandingAmount': 1084,
  'status': 'ACTIVE',
  'canAcceptNewJobs': false,
  'createdAt': '2026-08-06T10:00:00Z',
  'updatedAt': '2026-08-06T10:01:00Z',
};

const _workerWarrantyContributionJson = {
  'id': 'warranty-contribution-1',
  'workerUserId': 'worker-1',
  'paymentOrderId': 'payment-split-1',
  'bookingId': 'booking-split-1',
  'amountDue': 1084,
  'status': 'DUE',
  'createdAt': '2026-08-06T10:00:00Z',
  'updatedAt': '2026-08-06T10:01:00Z',
};

const _settleableSettlementJson = {
  'id': 'settlement-1',
  'workerUserId': 'worker-1',
  'bookingId': 'booking-1',
  'paymentOrderId': 'payment-1',
  'amount': 5220,
  'status': 'SETTLEABLE',
  'frozenReason': null,
  'settledAt': null,
  'createdAt': '2026-08-02T01:46:02Z',
  'updatedAt': '2026-08-02T01:46:02Z',
};

const _heldWarrantyJson = {
  'id': 'warranty-1',
  'workerUserId': 'worker-1',
  'ownerUserId': 'owner-1',
  'bookingId': 'booking-1',
  'paymentOrderId': 'payment-1',
  'amount': 580,
  'releasedAmount': 0,
  'deductedAmount': 0,
  'remainingAmount': 580,
  'status': 'HELD',
  'deductionReason': null,
  'releasedAt': null,
  'createdAt': '2026-08-02T01:46:02Z',
  'updatedAt': '2026-08-02T01:46:02Z',
};

const _workerLoginResponse = OwnerLoginResponse(
  accessToken: 'worker-token',
  tokenType: 'Bearer',
  expiresInSeconds: 3600,
  user: AuthUser(
    id: 'worker-id',
    phone: '19800000000',
    status: 'ACTIVE',
    roles: ['WORKER'],
  ),
);

final class _FakeChatApi implements ChatApi {
  _FakeChatApi({this.rooms});

  final List<ChatRoomModel>? rooms;

  @override
  Future<ChatRoomModel> getOrCreateRoom(String accessToken, String bookingId) =>
      throw UnimplementedError();

  final List<String> markedRoomIds = [];

  @override
  Future<List<ChatRoomModel>> getRooms(String accessToken) async {
    expect(accessToken, 'worker-token');
    if (rooms != null) return rooms!;
    return [
      ChatRoomModel(
        id: 'room-1',
        bookingId: 'booking-1',
        ownerUserId: 'owner-id',
        workerUserId: 'worker-id',
        otherUserId: 'owner-id',
        otherUserName: 'wz',
        lastMessageText: 'hhh',
        lastMessageAt: DateTime(2026, 7, 29, 13, 58),
        unreadCount: 1,
        createdAt: DateTime(2026, 7, 29, 13),
      ),
    ];
  }

  @override
  Future<void> markRoomRead(String accessToken, String roomId) async {
    markedRoomIds.add(roomId);
  }

  @override
  Future<List<ChatMessageModel>> getMessages(
    String accessToken,
    String roomId, {
    int page = 0,
    int size = 30,
  }) async => const [];

  @override
  Future<ChatMessageModel> sendMessage(
    String accessToken,
    String roomId, {
    required String content,
    String type = 'TEXT',
    String? imageUrl,
  }) => throw UnimplementedError();
}
