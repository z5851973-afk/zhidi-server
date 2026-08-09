import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/models/chat_models.dart';
import 'package:zhidi_app/models/payment_models.dart';
import 'package:zhidi_app/pages/chat/chat_detail_page.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';
import 'package:zhidi_app/pages/home/owner_after_sale_page.dart';
import 'package:zhidi_app/pages/home/owner_inspection_page.dart';
import 'package:zhidi_app/pages/home/owner_quote_compare_page.dart';
import 'package:zhidi_app/pages/home/owner_payment_page.dart';
import 'package:zhidi_app/pages/message/message_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/chat_api_client.dart';
import 'package:zhidi_app/services/daily_report_api_client.dart';
import 'package:zhidi_app/services/inspection_api_client.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';
import 'package:zhidi_app/services/payment_api_client.dart';
import 'package:zhidi_app/services/service_request_api_client.dart';
import 'package:zhidi_app/services/worker_quote_api_client.dart';

void main() {
  testWidgets('owner interaction messages show remote chat room previews', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(
        AuthSession(
          accessToken: 'owner-token',
          tokenType: 'Bearer',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          userId: 'owner-id',
          phone: '19900000000',
          roles: const ['OWNER'],
        ),
      ),
    );
    final api = _FakeChatApi(rooms: [_room()]);

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: MessagePage(chatApi: api, initialCategory: '互动消息'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(api.getRoomsCalls, 1);
    expect(find.text('ren'), findsOneWidget);
    expect(find.text('8dian'), findsOneWidget);
    expect(find.text('暂无消息'), findsNothing);
  });

  testWidgets('empty server rooms never fall back to local old chats', (
    tester,
  ) async {
    final state = await _ownerState();
    await state.addChatMessage(
      'legacy-worker',
      ChatMessage(
        id: 'local-message',
        workerId: 'legacy-worker',
        workerName: '本地假师傅',
        text: '这是旧的本地聊天',
        isMe: true,
        createdAt: DateTime(2026, 8, 1, 9),
      ),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: MessagePage(
            chatApi: _FakeChatApi(rooms: const []),
            initialCategory: '互动消息',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本地假师傅'), findsNothing);
    expect(find.text('这是旧的本地聊天'), findsNothing);
    expect(find.text('暂无匹配消息'), findsOneWidget);
  });

  testWidgets('tapping a real room opens ChatDetailPage', (tester) async {
    final state = await _ownerState();
    final api = _FakeChatApi(rooms: [_room()]);

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: MessagePage(chatApi: api, initialCategory: '互动消息'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ren'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ChatDetailPage), findsOneWidget);
    final page = tester.widget<ChatDetailPage>(find.byType(ChatDetailPage));
    expect(page.roomId, 'room-1');
    expect(page.currentUserId, 'owner-id');
  });

  testWidgets('quote notification opens its exact service request comparison', (
    tester,
  ) async {
    final state = await _ownerStateWithNotification(
      message: _ownerNotification(
        eventType: 'QUOTE_SUBMITTED',
        bookingId: 'booking-quote',
        serviceRequestId: 'request-quote',
        targetAction: 'OWNER_QUOTE_COMPARISON',
        title: '报价已提交',
      ),
      bookings: [
        _ownerBooking(
          id: 'booking-quote',
          serviceRequestId: 'request-quote',
          status: 'QUOTE_PENDING',
        ),
      ],
    );
    final quoteApi = _emptyQuoteApi();

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: MessagePage(
            chatApi: _FakeChatApi(rooms: const []),
            serviceRequestApi: _MessageServiceRequestApi([
              _serviceRequest(
                id: 'request-quote',
                candidate: _candidateBooking(
                  id: 'booking-quote',
                  serviceRequestId: 'request-quote',
                  status: 'QUOTE_PENDING',
                  workerName: '周师傅',
                ),
              ),
            ]),
            quoteApi: quoteApi,
            initialCategory: '订单通知',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('报价已提交'));
    await tester.pumpAndSettle();

    expect(find.byType(OwnerQuoteComparePage), findsOneWidget);
    expect(
      tester
          .widget<OwnerQuoteComparePage>(find.byType(OwnerQuoteComparePage))
          .serviceRequestId,
      'request-quote',
    );
  });

  testWidgets(
    'quote notification rejects a mismatched service request and booking',
    (tester) async {
      final state = await _ownerStateWithNotification(
        message: _ownerNotification(
          eventType: 'QUOTE_SUBMITTED',
          bookingId: 'booking-quote-stale',
          serviceRequestId: 'request-stale',
          targetAction: 'OWNER_QUOTE_COMPARISON',
          title: '失效报价通知',
        ),
        bookings: [
          _ownerBooking(
            id: 'booking-quote-stale',
            serviceRequestId: 'request-actual',
            status: 'QUOTE_PENDING',
          ),
        ],
      );
      final actualRequest = _serviceRequest(
        id: 'request-actual',
        candidate: _candidateBooking(
          id: 'booking-quote-stale',
          serviceRequestId: 'request-actual',
          status: 'QUOTE_PENDING',
          workerName: '周师傅',
        ),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: MessagePage(
              chatApi: _FakeChatApi(rooms: const []),
              serviceRequestApi: _MessageServiceRequestApi([actualRequest]),
              quoteApi: _emptyQuoteApi(),
              initialCategory: '订单通知',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('失效报价通知'));
      await tester.pumpAndSettle();

      expect(find.text('该记录已更新或不再可用'), findsOneWidget);
      expect(find.byType(OwnerQuoteComparePage), findsNothing);
    },
  );

  testWidgets('arrival notification opens the exact candidate detail', (
    tester,
  ) async {
    final candidate = _candidateBooking(
      id: 'booking-arrival',
      serviceRequestId: 'request-arrival',
      status: 'ARRIVAL_PENDING',
      workerName: '精确师傅',
    );
    final request = _serviceRequest(
      id: 'request-arrival',
      candidate: candidate,
    );
    final state = await _ownerStateWithNotification(
      message: _ownerNotification(
        eventType: 'ARRIVAL_PENDING',
        bookingId: 'booking-arrival',
        serviceRequestId: 'request-arrival',
        targetAction: 'OWNER_BOOKING',
        title: '待确认到场',
      ),
      bookings: [
        _ownerBooking(
          id: 'booking-arrival',
          serviceRequestId: 'request-arrival',
          status: 'ARRIVAL_PENDING',
          workerName: '精确师傅',
        ),
      ],
    );
    final serviceRequestApi = _MessageServiceRequestApi([request]);
    final paymentApi = _emptyPaymentApi();

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: MessagePage(
            chatApi: _FakeChatApi(rooms: const []),
            serviceRequestApi: serviceRequestApi,
            paymentApi: paymentApi,
            quoteApi: _emptyQuoteApi(),
            initialCategory: '订单通知',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('待确认到场'));
    await tester.pumpAndSettle();

    expect(find.byType(MyHomePage), findsOneWidget);
    expect(find.text('精确师傅'), findsOneWidget);
    expect(find.text('确认师傅已到场'), findsOneWidget);
    final page = tester.widget<MyHomePage>(find.byType(MyHomePage));
    expect(page.initialServiceRequestId, 'request-arrival');
    expect(page.initialBookingId, 'booking-arrival');
  });

  testWidgets('stale owner notification shows unavailable without fallback', (
    tester,
  ) async {
    final state = await _ownerStateWithNotification(
      message: _ownerNotification(
        eventType: 'ARRIVAL_PENDING',
        bookingId: 'booking-missing',
        serviceRequestId: 'request-missing',
        targetAction: 'OWNER_BOOKING',
        title: '失效订单通知',
      ),
      bookings: const [],
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: MessagePage(
            chatApi: _FakeChatApi(rooms: const []),
            serviceRequestApi: _MessageServiceRequestApi(const []),
            initialCategory: '订单通知',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('失效订单通知'));
    await tester.pumpAndSettle();

    expect(find.text('该记录已更新或不再可用'), findsOneWidget);
    expect(find.byType(MyHomePage), findsNothing);
  });

  testWidgets(
    'stale owner payment notice does not create a replacement order',
    (tester) async {
      final state = await _ownerStateWithNotification(
        message: _ownerNotification(
          eventType: 'RECEIPT_CONFIRMED',
          bookingId: 'booking-payment-missing',
          serviceRequestId: 'request-payment',
          targetAction: 'OWNER_PAYMENT',
          title: '失效付款通知',
        ),
        bookings: [
          _ownerBooking(
            id: 'booking-payment-missing',
            serviceRequestId: 'request-payment',
            status: 'HIRED',
          ),
        ],
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: MessagePage(
              chatApi: _FakeChatApi(rooms: const []),
              paymentApi: _emptyPaymentApi(),
              initialCategory: '订单通知',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('失效付款通知'));
      await tester.pumpAndSettle();

      expect(find.text('该记录已更新或不再可用'), findsOneWidget);
      expect(find.byType(OwnerPaymentPage), findsNothing);
    },
  );

  testWidgets(
    'owner payment notice rejects another payment order for the same booking',
    (tester) async {
      final state = await _ownerStateWithNotification(
        message: _ownerNotification(
          eventType: 'RECEIPT_CONFIRMED',
          bookingId: 'booking-payment-exact',
          serviceRequestId: 'request-payment',
          paymentOrderId: 'payment-missing',
          targetAction: 'OWNER_PAYMENT',
          title: '错配付款通知',
        ),
        bookings: [
          _ownerBooking(
            id: 'booking-payment-exact',
            serviceRequestId: 'request-payment',
            status: 'HIRED',
          ),
        ],
      );
      final paymentApi = _paymentApiWithOrders([
        _ownerPaymentOrderJson(
          id: 'payment-other',
          bookingId: 'booking-payment-exact',
        ),
      ]);

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: MessagePage(
              chatApi: _FakeChatApi(rooms: const []),
              paymentApi: paymentApi,
              initialCategory: '订单通知',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('错配付款通知'));
      await tester.pumpAndSettle();

      expect(find.text('该记录已更新或不再可用'), findsOneWidget);
      expect(find.byType(OwnerPaymentPage), findsNothing);
    },
  );

  testWidgets('owner payment notice passes its exact payment order target', (
    tester,
  ) async {
    final order = _ownerPaymentOrderJson(
      id: 'payment-exact',
      bookingId: 'booking-payment-exact',
    );
    final state = await _ownerStateWithNotification(
      message: _ownerNotification(
        eventType: 'RECEIPT_CONFIRMED',
        bookingId: 'booking-payment-exact',
        serviceRequestId: 'request-payment',
        paymentOrderId: 'payment-exact',
        targetAction: 'OWNER_PAYMENT',
        title: '精确付款通知',
      ),
      bookings: [
        _ownerBooking(
          id: 'booking-payment-exact',
          serviceRequestId: 'request-payment',
          status: 'HIRED',
        ),
      ],
    );
    final paymentApi = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        final Object data =
            request.url.path == '/api/v1/payment/orders/payment-exact'
            ? order
            : {
                'content': [order],
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
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: MessagePage(
            chatApi: _FakeChatApi(rooms: const []),
            paymentApi: paymentApi,
            initialCategory: '订单通知',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('精确付款通知'));
    await tester.pumpAndSettle();

    final page = tester.widget<OwnerPaymentPage>(find.byType(OwnerPaymentPage));
    expect(page.initialPaymentOrderId, 'payment-exact');
  });

  testWidgets(
    'legacy owner payment notice resolves its exact order beyond page twenty',
    (tester) async {
      final targetOrder = _ownerPaymentOrderJson(
        id: 'payment-legacy-target',
        bookingId: 'booking-payment-legacy',
      );
      final unrelated = [
        for (var index = 0; index < 20; index += 1)
          _ownerPaymentOrderJson(
            id: 'payment-unrelated-$index',
            bookingId: 'booking-unrelated-$index',
          ),
      ];
      final state = await _ownerStateWithNotification(
        message: _ownerNotification(
          eventType: 'RECEIPT_CONFIRMED',
          bookingId: 'booking-payment-legacy',
          serviceRequestId: 'request-payment',
          targetAction: 'OWNER_PAYMENT',
          title: '旧版付款通知',
        ),
        bookings: [
          _ownerBooking(
            id: 'booking-payment-legacy',
            serviceRequestId: 'request-payment',
            status: 'HIRED',
          ),
        ],
      );
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final Object data;
          if (request.url.path ==
              '/api/v1/payment/orders/payment-legacy-target') {
            data = targetOrder;
          } else if (request.url.path == '/api/v1/payment/orders') {
            data = {
              'content': request.url.queryParameters['size'] == '100'
                  ? [...unrelated, targetOrder]
                  : unrelated,
            };
          } else {
            data = <Object>[];
          }
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
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: MessagePage(
              chatApi: _FakeChatApi(rooms: const []),
              paymentApi: paymentApi,
              initialCategory: '订单通知',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('旧版付款通知'));
      await tester.pumpAndSettle();

      final page = tester.widget<OwnerPaymentPage>(
        find.byType(OwnerPaymentPage),
      );
      expect(page.initialPaymentOrderId, 'payment-legacy-target');
      expect(find.text('生成支付订单'), findsNothing);
    },
  );

  testWidgets('daily-report event opens its exact report and booking', (
    tester,
  ) async {
    final state = await _ownerStateWithNotification(
      message: _ownerNotification(
        eventType: 'DAILY_REPORT_SUBMITTED',
        bookingId: 'booking-daily',
        serviceRequestId: 'request-daily',
        targetAction: 'OWNER_DAILY_REPORT',
        aggregateType: 'DAILY_REPORT',
        aggregateId: 'report-exact',
        title: '精确日报通知',
      ),
      bookings: [
        _ownerBooking(
          id: 'booking-daily',
          serviceRequestId: 'request-daily',
          status: 'HIRED',
        ),
      ],
    );
    final api = _MessageDailyReportApi([
      _remoteDailyReport(id: 'report-exact', bookingId: 'booking-daily'),
      _remoteDailyReport(id: 'report-other', bookingId: 'booking-daily'),
    ]);

    await _pumpOwnerMessagePage(tester, state: state, dailyReportApi: api);
    await tester.tap(find.text('精确日报通知'));
    await tester.pumpAndSettle();

    final page = tester.widget<OwnerDailyReportViewPage>(
      find.byType(OwnerDailyReportViewPage),
    );
    expect(page.bookingId, 'booking-daily');
    expect(page.initialReportId, 'report-exact');
    expect(find.text('第 report-exact 版日报'), findsOneWidget);
    expect(find.text('第 report-other 版日报'), findsNothing);
  });

  testWidgets(
    'daily-report event rejects an id that belongs to another booking',
    (tester) async {
      final state = await _exactOwnerTargetState(
        title: '错配日报通知',
        action: 'OWNER_DAILY_REPORT',
        aggregateType: 'DAILY_REPORT',
        aggregateId: 'report-mismatch',
      );
      final api = _MessageDailyReportApi([
        _remoteDailyReport(id: 'report-mismatch', bookingId: 'booking-other'),
      ]);

      await _pumpOwnerMessagePage(tester, state: state, dailyReportApi: api);
      await tester.tap(find.text('错配日报通知'));
      await tester.pumpAndSettle();

      expect(find.text('该记录已更新或不再可用'), findsOneWidget);
      expect(find.byType(OwnerDailyReportViewPage), findsNothing);
    },
  );

  testWidgets('daily-report event distinguishes a temporary network failure', (
    tester,
  ) async {
    final state = await _exactOwnerTargetState(
      title: '日报网络失败',
      action: 'OWNER_DAILY_REPORT',
      aggregateType: 'DAILY_REPORT',
      aggregateId: 'report-network',
    );
    final api = _MessageDailyReportApi(
      const [],
      error: StateError('temporary failure'),
    );

    await _pumpOwnerMessagePage(tester, state: state, dailyReportApi: api);
    await tester.tap(find.text('日报网络失败'));
    await tester.pumpAndSettle();

    expect(find.text('暂时无法打开，请稍后重试'), findsOneWidget);
    expect(find.byType(OwnerDailyReportViewPage), findsNothing);
  });

  testWidgets('daily-report event treats a target 404 as stale', (
    tester,
  ) async {
    final state = await _exactOwnerTargetState(
      title: '日报目标已失效',
      action: 'OWNER_DAILY_REPORT',
      aggregateType: 'DAILY_REPORT',
      aggregateId: 'report-missing',
    );
    const api = _MessageDailyReportApi(
      [],
      error: AuthApiException(
        code: 'DAILY_REPORT_NOT_FOUND',
        message: '日报不存在',
        statusCode: 404,
      ),
    );

    await _pumpOwnerMessagePage(tester, state: state, dailyReportApi: api);
    await tester.tap(find.text('日报目标已失效'));
    await tester.pumpAndSettle();

    expect(find.text('该记录已更新或不再可用'), findsOneWidget);
    expect(find.byType(OwnerDailyReportViewPage), findsNothing);
  });

  testWidgets('booking refresh failure never classifies a new event as stale', (
    tester,
  ) async {
    final state = await _ownerStateWithNotification(
      message: _ownerNotification(
        eventType: 'DAILY_REPORT_SUBMITTED',
        bookingId: 'booking-not-cached',
        serviceRequestId: 'request-not-cached',
        targetAction: 'OWNER_DAILY_REPORT',
        aggregateType: 'DAILY_REPORT',
        aggregateId: 'report-not-cached',
        title: '预约刷新失败',
      ),
      bookings: const [],
      bookingError: const AuthApiException(
        code: 'BOOKING_UNAVAILABLE',
        message: '服务繁忙',
        statusCode: 503,
      ),
    );

    await _pumpOwnerMessagePage(
      tester,
      state: state,
      dailyReportApi: _MessageDailyReportApi([
        _remoteDailyReport(
          id: 'report-not-cached',
          bookingId: 'booking-not-cached',
        ),
      ]),
    );
    await tester.tap(find.text('预约刷新失败'));
    await tester.pumpAndSettle();

    expect(find.text('暂时无法打开，请稍后重试'), findsOneWidget);
    expect(find.text('该记录已更新或不再可用'), findsNothing);
    expect(find.byType(OwnerDailyReportViewPage), findsNothing);
  });

  testWidgets('inspection event opens its exact node and booking', (
    tester,
  ) async {
    final state = await _exactOwnerTargetState(
      title: '精确验收通知',
      action: 'OWNER_INSPECTION',
      aggregateType: 'INSPECTION_NODE',
      aggregateId: 'node-exact',
    );
    final api = _MessageInspectionApi([
      _remoteInspectionNode(id: 'node-exact', bookingId: 'booking-target'),
      _remoteInspectionNode(id: 'node-other', bookingId: 'booking-target'),
    ]);

    await _pumpOwnerMessagePage(tester, state: state, inspectionApi: api);
    await tester.tap(find.text('精确验收通知'));
    await tester.pumpAndSettle();

    final page = tester.widget<OwnerInspectionPage>(
      find.byType(OwnerInspectionPage),
    );
    expect(page.bookingId, 'booking-target');
    expect(page.initialNodeId, 'node-exact');
    expect(find.text('node-exact'), findsOneWidget);
    expect(find.text('node-other'), findsNothing);
  });

  testWidgets('inspection event rejects a node from another booking', (
    tester,
  ) async {
    final state = await _exactOwnerTargetState(
      title: '错配验收通知',
      action: 'OWNER_INSPECTION',
      aggregateType: 'INSPECTION_NODE',
      aggregateId: 'node-mismatch',
    );
    final api = _MessageInspectionApi([
      _remoteInspectionNode(id: 'node-mismatch', bookingId: 'booking-other'),
    ]);

    await _pumpOwnerMessagePage(tester, state: state, inspectionApi: api);
    await tester.tap(find.text('错配验收通知'));
    await tester.pumpAndSettle();

    expect(find.text('该记录已更新或不再可用'), findsOneWidget);
    expect(find.byType(OwnerInspectionPage), findsNothing);
  });

  testWidgets('inspection event distinguishes a temporary network failure', (
    tester,
  ) async {
    final state = await _exactOwnerTargetState(
      title: '验收网络失败',
      action: 'OWNER_INSPECTION',
      aggregateType: 'INSPECTION_NODE',
      aggregateId: 'node-network',
    );
    final api = _MessageInspectionApi(
      const [],
      error: StateError('temporary failure'),
    );

    await _pumpOwnerMessagePage(tester, state: state, inspectionApi: api);
    await tester.tap(find.text('验收网络失败'));
    await tester.pumpAndSettle();

    expect(find.text('暂时无法打开，请稍后重试'), findsOneWidget);
    expect(find.byType(OwnerInspectionPage), findsNothing);
  });

  testWidgets('inspection event treats a target 404 as stale', (tester) async {
    final state = await _exactOwnerTargetState(
      title: '验收目标已失效',
      action: 'OWNER_INSPECTION',
      aggregateType: 'INSPECTION_NODE',
      aggregateId: 'node-missing',
    );
    const api = _MessageInspectionApi(
      [],
      error: AuthApiException(
        code: 'INSPECTION_NODE_NOT_FOUND',
        message: '验收节点不存在',
        statusCode: 404,
      ),
    );

    await _pumpOwnerMessagePage(tester, state: state, inspectionApi: api);
    await tester.tap(find.text('验收目标已失效'));
    await tester.pumpAndSettle();

    expect(find.text('该记录已更新或不再可用'), findsOneWidget);
    expect(find.byType(OwnerInspectionPage), findsNothing);
  });

  testWidgets('after-sale event opens the exact ticket detail', (tester) async {
    final state = await _exactOwnerTargetState(
      title: '精确售后通知',
      action: 'OWNER_AFTER_SALE',
      aggregateType: 'AFTER_SALE',
      aggregateId: 'after-sale-exact',
    );
    final api = _MessageAfterSaleApi(
      _afterSaleDetail(
        afterSaleId: 'after-sale-exact',
        bookingId: 'booking-target',
      ),
    );

    await _pumpOwnerMessagePage(tester, state: state, paymentApi: api);
    await tester.tap(find.text('精确售后通知'));
    await tester.pumpAndSettle();

    final page = tester.widget<AfterSaleDetailPage>(
      find.byType(AfterSaleDetailPage),
    );
    expect(page.afterSaleId, 'after-sale-exact');
  });

  testWidgets('after-sale event rejects a ticket from another booking', (
    tester,
  ) async {
    final state = await _exactOwnerTargetState(
      title: '错配售后通知',
      action: 'OWNER_AFTER_SALE',
      aggregateType: 'AFTER_SALE',
      aggregateId: 'after-sale-mismatch',
    );
    final api = _MessageAfterSaleApi(
      _afterSaleDetail(
        afterSaleId: 'after-sale-mismatch',
        bookingId: 'booking-other',
      ),
    );

    await _pumpOwnerMessagePage(tester, state: state, paymentApi: api);
    await tester.tap(find.text('错配售后通知'));
    await tester.pumpAndSettle();

    expect(find.text('该记录已更新或不再可用'), findsOneWidget);
    expect(find.byType(AfterSaleDetailPage), findsNothing);
  });

  testWidgets('after-sale event distinguishes a temporary network failure', (
    tester,
  ) async {
    final state = await _exactOwnerTargetState(
      title: '售后网络失败',
      action: 'OWNER_AFTER_SALE',
      aggregateType: 'AFTER_SALE',
      aggregateId: 'after-sale-network',
    );
    final api = _MessageAfterSaleApi(
      null,
      error: const PaymentApiException(statusCode: 503, message: '服务繁忙'),
    );

    await _pumpOwnerMessagePage(tester, state: state, paymentApi: api);
    await tester.tap(find.text('售后网络失败'));
    await tester.pumpAndSettle();

    expect(find.text('暂时无法打开，请稍后重试'), findsOneWidget);
    expect(find.byType(AfterSaleDetailPage), findsNothing);
  });

  testWidgets('after-sale event treats a target 404 as stale', (tester) async {
    final state = await _exactOwnerTargetState(
      title: '售后目标已失效',
      action: 'OWNER_AFTER_SALE',
      aggregateType: 'AFTER_SALE',
      aggregateId: 'after-sale-missing',
    );
    final api = _MessageAfterSaleApi(
      null,
      error: const PaymentApiException(statusCode: 404, message: '工单不存在'),
    );

    await _pumpOwnerMessagePage(tester, state: state, paymentApi: api);
    await tester.tap(find.text('售后目标已失效'));
    await tester.pumpAndSettle();

    expect(find.text('该记录已更新或不再可用'), findsOneWidget);
    expect(find.byType(AfterSaleDetailPage), findsNothing);
  });
}

Future<void> _pumpOwnerMessagePage(
  WidgetTester tester, {
  required OwnerAppState state,
  DailyReportApi? dailyReportApi,
  InspectionApi? inspectionApi,
  PaymentApiClient? paymentApi,
}) async {
  await tester.pumpWidget(
    OwnerAppScope(
      state: state,
      child: MaterialApp(
        home: MessagePage(
          chatApi: _FakeChatApi(rooms: const []),
          dailyReportApi: dailyReportApi,
          inspectionApi: inspectionApi,
          paymentApi: paymentApi,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<OwnerAppState> _exactOwnerTargetState({
  required String title,
  required String action,
  required String aggregateType,
  required String aggregateId,
}) => _ownerStateWithNotification(
  message: _ownerNotification(
    eventType: 'BUSINESS_EVENT',
    bookingId: 'booking-target',
    serviceRequestId: 'request-target',
    targetAction: action,
    aggregateType: aggregateType,
    aggregateId: aggregateId,
    title: title,
  ),
  bookings: [
    _ownerBooking(
      id: 'booking-target',
      serviceRequestId: 'request-target',
      status: 'HIRED',
    ),
  ],
);

RemoteDailyReport _remoteDailyReport({
  required String id,
  required String bookingId,
}) => RemoteDailyReport(
  id: id,
  bookingId: bookingId,
  workerUserId: 'worker-id',
  reportDate: '2026-08-09',
  content: '第 $id 版日报',
  photos: const [],
  createdAt: DateTime.utc(2026, 8, 9, 8),
);

RemoteInspectionNode _remoteInspectionNode({
  required String id,
  required String bookingId,
}) => RemoteInspectionNode(
  id: id,
  bookingId: bookingId,
  name: id,
  status: 'INSPECTING',
  sortOrder: 1,
  createdAt: DateTime.utc(2026, 8, 9, 8),
);

AfterSaleDetailModel _afterSaleDetail({
  required String afterSaleId,
  required String bookingId,
}) => AfterSaleDetailModel(
  ticket: AfterSaleModel(
    id: afterSaleId,
    bookingId: bookingId,
    ownerUserId: 'owner-id',
    workerUserId: 'worker-id',
    type: 'COMPLAINT',
    reason: '精确工单',
    status: 'OPEN',
    createdAt: '2026-08-09T08:00:00Z',
    updatedAt: '2026-08-09T08:00:00Z',
  ),
  context: AfterSaleOrderContextModel(
    bookingId: bookingId,
    trade: 'carpentry',
    inspection: const AfterSaleInspectionSummaryModel(
      status: 'PASSED',
      passedCount: 1,
      totalCount: 1,
    ),
  ),
  timeline: const [],
);

final class _MessageDailyReportApi implements DailyReportApi {
  const _MessageDailyReportApi(this.reports, {this.error});

  final List<RemoteDailyReport> reports;
  final Object? error;

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) async {
    if (error case final failure?) throw failure;
    return reports;
  }

  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String reportDate,
    String content,
    List<String> photos,
  ) => throw UnimplementedError();
}

final class _MessageInspectionApi implements InspectionApi {
  const _MessageInspectionApi(this.nodes, {this.error});

  final List<RemoteInspectionNode> nodes;
  final Object? error;

  @override
  Future<List<RemoteInspectionNode>> getNodes(
    String accessToken,
    String bookingId,
  ) async {
    if (error case final failure?) throw failure;
    return nodes;
  }

  @override
  Future<List<RemoteInspectionNode>> createNodes(
    String accessToken,
    String bookingId,
    List<Map<String, dynamic>> nodes,
  ) => throw UnimplementedError();

  @override
  Future<List<RemoteInspectionRecord>> getRecords(
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
  Future<RemoteInspectionNode> requestInspection(
    String accessToken,
    String nodeId,
  ) => throw UnimplementedError();
}

final class _MessageAfterSaleApi extends PaymentApiClient {
  _MessageAfterSaleApi(this.detail, {this.error});

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

final class _FakeChatApi implements ChatApi {
  _FakeChatApi({required this.rooms});

  final List<ChatRoomModel> rooms;
  int getRoomsCalls = 0;

  @override
  Future<ChatRoomModel> getOrCreateRoom(String accessToken, String bookingId) =>
      throw UnimplementedError();

  @override
  Future<List<ChatRoomModel>> getRooms(String accessToken) async {
    getRoomsCalls++;
    expect(accessToken, 'owner-token');
    return rooms;
  }

  @override
  Future<void> markRoomRead(String accessToken, String roomId) async {}

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

Future<OwnerAppState> _ownerState() => OwnerAppState.memory(
  sessionStore: MemoryAuthSessionStore(
    AuthSession(
      accessToken: 'owner-token',
      tokenType: 'Bearer',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      userId: 'owner-id',
      phone: '19900000000',
      roles: const ['OWNER'],
    ),
  ),
);

ChatRoomModel _room() => ChatRoomModel(
  id: 'room-1',
  bookingId: 'booking-1',
  ownerUserId: 'owner-id',
  workerUserId: 'worker-id',
  otherUserId: 'worker-id',
  otherUserName: 'ren',
  lastMessageText: '8dian',
  lastMessageAt: DateTime(2026, 8, 1, 14, 34),
  unreadCount: 1,
  createdAt: DateTime(2026, 8, 1, 14),
);

Future<OwnerAppState> _ownerStateWithNotification({
  required OwnerMessage message,
  required List<RemoteOwnerBooking> bookings,
  Object? bookingError,
}) async {
  final seed = await OwnerAppState.memory();
  final store = MemoryOwnerStore();
  final session = AuthSession(
    accessToken: 'owner-token',
    tokenType: 'Bearer',
    expiresAt: DateTime.now().add(const Duration(days: 1)),
    userId: 'owner-id',
    phone: '19900000000',
    roles: const ['OWNER'],
  );
  await store.setString(
    OwnerAppState.documentKey,
    jsonEncode({
      ...seed.toJson(),
      'profile': const OwnerProfile(
        name: '王先生',
        city: '成都',
        phone: '19900000000',
      ).toJson(),
      'messages': [message.toJson()],
      'isLoggedIn': true,
      'sessionUserId': 'owner-id',
    }),
  );
  return OwnerAppState.memory(
    store: store,
    sessionStore: MemoryAuthSessionStore(session),
    profileApi: const _MessageOwnerProfileApi(),
    bookingApi: _MessageOwnerBookingApi(bookings, error: bookingError),
  );
}

OwnerMessage _ownerNotification({
  required String eventType,
  required String bookingId,
  required String serviceRequestId,
  String? paymentOrderId,
  String? aggregateType,
  String? aggregateId,
  required String targetAction,
  required String title,
}) => OwnerMessage(
  id: 'owner:$eventType:$bookingId',
  title: title,
  content: '服务器业务状态已更新',
  category: '预约',
  createdAt: DateTime.utc(2026, 8, 8, 9),
  eventType: eventType,
  bookingId: bookingId,
  serviceRequestId: serviceRequestId,
  paymentOrderId: paymentOrderId,
  targetAction: targetAction,
  aggregateType: aggregateType,
  aggregateId: aggregateId,
);

RemoteOwnerBooking _ownerBooking({
  required String id,
  required String serviceRequestId,
  required String status,
  String workerName = '周师傅',
}) => RemoteOwnerBooking(
  id: id,
  ownerUserId: 'owner-id',
  serviceRequestId: serviceRequestId,
  workerUserId: 'worker-id',
  workerName: workerName,
  trade: 'carpentry',
  serviceCity: '成都',
  serviceAddress: '成都高新区',
  remark: null,
  status: status,
  createdAt: DateTime.utc(2026, 8, 8, 8),
  updatedAt: DateTime.utc(2026, 8, 8, 9),
);

RemoteCandidateBooking _candidateBooking({
  required String id,
  required String serviceRequestId,
  required String status,
  required String workerName,
}) => RemoteCandidateBooking(
  id: id,
  serviceRequestId: serviceRequestId,
  ownerUserId: 'owner-id',
  ownerName: '王先生',
  ownerPhone: '19900000000',
  workerUserId: 'worker-id',
  workerName: workerName,
  trade: 'carpentry',
  serviceCity: '成都',
  serviceAddress: '成都高新区',
  remark: null,
  status: status,
  arrivalConfirmedByOwner: false,
  arrivalConfirmedByWorker: true,
  createdAt: DateTime.utc(2026, 8, 8, 8),
  updatedAt: DateTime.utc(2026, 8, 8, 9),
);

RemoteServiceRequest _serviceRequest({
  required String id,
  required RemoteCandidateBooking candidate,
}) => RemoteServiceRequest(
  id: id,
  ownerUserId: 'owner-id',
  trade: 'carpentry',
  serviceCity: '成都',
  serviceAddress: '成都高新区',
  remark: null,
  status: 'ACTIVE',
  candidates: [candidate],
  createdAt: DateTime.utc(2026, 8, 8, 8),
  updatedAt: DateTime.utc(2026, 8, 8, 9),
);

WorkerQuoteApiClient _emptyQuoteApi() => WorkerQuoteApiClient(
  baseUrl: Uri.parse('http://example.test'),
  httpClient: MockClient(
    (request) async => http.Response.bytes(
      utf8.encode(
        jsonEncode({'code': 'OK', 'message': 'success', 'data': <Object>[]}),
      ),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    ),
  ),
);

PaymentApiClient _emptyPaymentApi() => PaymentApiClient(
  baseUrl: Uri.parse('http://example.test'),
  httpClient: MockClient((request) async {
    final Object data = request.url.path == '/api/v1/payment/orders'
        ? {'content': <Object>[]}
        : <Object>[];
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
      ),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }),
);

PaymentApiClient _paymentApiWithOrders(List<Map<String, dynamic>> orders) =>
    PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        if (request.url.path.startsWith('/api/v1/payment/orders/') &&
            request.method == 'GET') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'PAYMENT_ORDER_NOT_FOUND',
                'message': '支付订单不存在',
                'data': null,
              }),
            ),
            404,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final Object data = request.url.path == '/api/v1/payment/orders'
            ? {'content': orders}
            : <Object>[];
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({'code': 'OK', 'message': 'success', 'data': data}),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

Map<String, dynamic> _ownerPaymentOrderJson({
  required String id,
  required String bookingId,
}) => {
  'id': id,
  'bookingId': bookingId,
  'ownerUserId': 'owner-id',
  'workerUserId': 'worker-id',
  'quoteId': 'quote-1',
  'amount': 1100,
  'platformFee': 100,
  'workerSettlement': 1000,
  'warrantyRetention': 0,
  'fundingModel': 'OFFLINE_SPLIT_V2',
  'quoteAmount': 1000,
  'constructionPaymentStatus': 'CONFIRMED',
  'platformFeeStatus': 'VERIFIED',
  'status': 'PAID',
  'paymentMethod': 'OFFLINE',
  'createdAt': '2026-08-08T09:00:00Z',
  'updatedAt': '2026-08-08T10:00:00Z',
};

final class _MessageOwnerBookingApi implements OwnerBookingApi {
  const _MessageOwnerBookingApi(this.bookings, {this.error});

  final List<RemoteOwnerBooking> bookings;
  final Object? error;

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(String accessToken) async {
    if (error case final failure?) throw failure;
    return bookings;
  }

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

final class _MessageOwnerProfileApi implements OwnerProfileApi {
  const _MessageOwnerProfileApi();

  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async =>
      const RemoteOwnerProfile(
        userId: 'owner-id',
        phone: '19900000000',
        name: '王先生',
        city: '成都',
        decorationType: null,
        address: null,
        area: null,
        profileComplete: true,
      );

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) => throw UnimplementedError();
}

final class _MessageServiceRequestApi implements ServiceRequestApi {
  const _MessageServiceRequestApi(this.requests);

  final List<RemoteServiceRequest> requests;

  @override
  Future<List<RemoteServiceRequest>> listOwnerRequests(
    String accessToken,
  ) async => requests;

  @override
  Future<RemoteServiceRequest> createRequest(
    String accessToken,
    ServiceRequestDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<RemoteServiceRequest> addCandidate(
    String accessToken,
    String requestId,
    String workerUserId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteServiceRequest> removeCandidate(
    String accessToken,
    String requestId,
    String bookingId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteServiceRequest> replaceCandidate(
    String accessToken,
    String requestId,
    String bookingId,
    String workerUserId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteServiceRequest> reopenRequest(
    String accessToken,
    String requestId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteServiceRequest> cancelRequest(
    String accessToken,
    String requestId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> cancelAsOwner(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> cancelAsWorker(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> proposeVisit(
    String accessToken,
    String bookingId,
    DateTime proposedTime,
  ) => throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> acceptVisit(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> rejectVisit(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> ownerArrive(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> workerArrive(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> ownerConfirmArrival(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteCandidateBooking> workerConfirmArrival(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();
}
