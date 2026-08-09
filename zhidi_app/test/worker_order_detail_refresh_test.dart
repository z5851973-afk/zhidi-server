import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/models/house_info.dart';
import 'package:zhidi_app/pages/worker/order_detail_page.dart';
import 'package:zhidi_app/services/payment_api_client.dart';
import 'package:zhidi_app/services/worker_booking_api_client.dart';
import 'package:zhidi_app/services/worker_quote_api_client.dart';

final _workerFeeSynonyms = RegExp('平台服务费|平台费|服务费|手续费|抽成|佣金');

void main() {
  testWidgets('order detail shows separate area and layout from house info', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    state.initBookingApi(
      api: _FakeWorkerBookingApi([
        _booking(
          status: 'PENDING',
          houseInfo: const HouseInfo(
            areaSqm: 98.5,
            bedroomCount: 3,
            livingRoomCount: 2,
            kitchenCount: 1,
            bathroomCount: 2,
          ),
        ),
      ]),
      accessToken: 'worker-jwt',
    );
    await state.fetchRemoteBookings();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: const MaterialApp(
          home: OrderDetailPage(orderId: 'booking-1', refreshInterval: null),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('98.5㎡'), findsOneWidget);
    expect(find.text('3室2厅1厨2卫'), findsOneWidget);
  });
  testWidgets('order detail header handles long status and order id', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(630, 1460);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    const longBookingId = 'a0729b92-f261-47ae-8fbb-4c395780f1a2';
    state.initBookingApi(
      api: _FakeWorkerBookingApi([
        _booking(id: longBookingId, status: 'VISIT_PROPOSED'),
      ]),
      accessToken: 'worker-jwt',
    );
    await state.fetchRemoteBookings();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: const MaterialApp(
          home: OrderDetailPage(orderId: longBookingId, refreshInterval: null),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('等待业主确认上门时间'), findsWidgets);
  });

  testWidgets('order detail refreshes remote status after opening', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _FakeWorkerBookingApi([_booking(status: 'ARRIVAL_PENDING')]);
    state.initBookingApi(api: api, accessToken: 'worker-jwt');
    await state.fetchRemoteBookings();
    api.bookings = [_booking(status: 'ON_SITE')];

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: const MaterialApp(home: OrderDetailPage(orderId: 'booking-1')),
      ),
    );

    expect(find.text('确认业主已到场'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.text('提交报价单'), findsOneWidget);
    expect(find.text('确认业主已到场'), findsNothing);
  });

  testWidgets(
    'scheduled visit shows fixed time and actual arrival as pending',
    (tester) async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      state.initBookingApi(
        api: _FakeWorkerBookingApi([
          _booking(
            status: 'VISIT_SCHEDULED',
            scheduledVisitAt: DateTime(2026, 8, 10, 9, 30),
          ),
        ]),
        accessToken: 'worker-jwt',
      );
      await state.fetchRemoteBookings();

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: const MaterialApp(
            home: OrderDetailPage(orderId: 'booking-1', refreshInterval: null),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('约定上门时间'), findsOneWidget);
      expect(find.text('2026年8月10日 09:30'), findsOneWidget);
      expect(find.text('实际到场时间'), findsOneWidget);
      expect(find.text('待到场'), findsOneWidget);
      expect(find.textContaining('开工时间'), findsNothing);
    },
  );

  testWidgets('on-site order keeps scheduled and actual times visible', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    state.initBookingApi(
      api: _FakeWorkerBookingApi([
        _booking(
          status: 'ON_SITE',
          scheduledVisitAt: DateTime(2026, 8, 10, 9, 30),
          actualOnSiteAt: DateTime(2026, 8, 10, 10, 5),
        ),
      ]),
      accessToken: 'worker-jwt',
    );
    await state.fetchRemoteBookings();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: const MaterialApp(
          home: OrderDetailPage(orderId: 'booking-1', refreshInterval: null),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('约定上门时间'), findsOneWidget);
    expect(find.text('2026年8月10日 09:30'), findsOneWidget);
    expect(find.text('实际到场时间'), findsOneWidget);
    expect(find.text('2026年8月10日 10:05'), findsOneWidget);
    expect(find.text('待到场'), findsNothing);
    expect(find.textContaining('开工时间'), findsNothing);
  });

  testWidgets(
    'target order disappearance never falls back to another completed order',
    (tester) async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final api = _FakeWorkerBookingApi([
        _booking(id: 'booking-a', ownerName: '不应出现的 A 业主', status: 'COMPLETED'),
        _booking(id: 'booking-b', ownerName: '目标 B 业主', status: 'ACCEPTED'),
      ]);
      state.initBookingApi(api: api, accessToken: 'worker-jwt');
      await state.fetchRemoteBookings();
      api.bookings = [
        _booking(id: 'booking-a', ownerName: '不应出现的 A 业主', status: 'COMPLETED'),
      ];

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: const MaterialApp(
            home: OrderDetailPage(orderId: 'booking-b', refreshInterval: null),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(find.text('该订单已更新或不再可用'), findsOneWidget);
      expect(find.text('完工档案'), findsNothing);
      expect(find.text('不应出现的 A 业主'), findsNothing);
    },
  );

  testWidgets('hired order detail exposes construction actions', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    state.initBookingApi(
      api: _FakeWorkerBookingApi([_booking(status: 'HIRED')]),
      accessToken: 'worker-jwt',
    );
    await state.fetchRemoteBookings();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: const MaterialApp(
          home: OrderDetailPage(orderId: 'booking-1', refreshInterval: null),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('已被选中'), findsWidgets);
    expect(find.text('提交日报'), findsOneWidget);
    expect(find.text('发起验收'), findsOneWidget);
    expect(find.text('联系业主'), findsOneWidget);
    expect(find.text('13800000000'), findsOneWidget);
    expect(find.text('查看结算'), findsOneWidget);
  });

  testWidgets('worker can open the submitted server quote from order detail', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    state.initBookingApi(
      api: _FakeWorkerBookingApi([_booking(status: 'QUOTE_PENDING')]),
      accessToken: 'worker-jwt',
    );
    await state.fetchRemoteBookings();
    final quoteApi = WorkerQuoteApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/bookings/booking-1/quotes');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [_quoteJson],
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
          home: OrderDetailPage(
            orderId: 'booking-1',
            refreshInterval: null,
            quoteApi: quoteApi,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已提交报价单'), findsOneWidget);
    expect(find.text('查看已提交报价单'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('查看已提交报价单'), 250);
    await tester.tap(find.text('查看已提交报价单'));
    await tester.pumpAndSettle();

    expect(find.text('报价明细'), findsOneWidget);
    expect(find.text('人工明细'), findsOneWidget);
    expect(find.text('材料明细'), findsOneWidget);
    expect(find.text('吊顶安装'), findsOneWidget);
    expect(find.text('¥120.00/平方米 × 30'), findsOneWidget);
    expect(find.text('板材材料'), findsOneWidget);
    expect(find.text('¥180.00/张 × 38'), findsOneWidget);
    expect(find.text('¥10440.00'), findsWidgets);
    expect(find.textContaining('平台服务费'), findsNothing);
  });

  testWidgets('quote load failure remains retryable on order detail', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    state.initBookingApi(
      api: _FakeWorkerBookingApi([_booking(status: 'QUOTE_PENDING')]),
      accessToken: 'worker-jwt',
    );
    await state.fetchRemoteBookings();
    final quoteApi = WorkerQuoteApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'QUOTE_LOAD_FAILED',
              'message': '报价加载失败',
              'data': null,
            }),
          ),
          500,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: OrderDetailPage(
            orderId: 'booking-1',
            refreshInterval: null,
            quoteApi: quoteApi,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('查看已提交报价单'), 250);
    await tester.tap(find.text('查看已提交报价单'));
    await tester.pumpAndSettle();

    expect(find.text('报价加载失败，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('订单详情'), findsOneWidget);
  });

  testWidgets(
    'completed inspection waits for owner payment and previews aligned split',
    (tester) async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      state.initBookingApi(
        api: _FakeWorkerBookingApi([_booking(status: 'COMPLETED')]),
        accessToken: 'worker-jwt',
      );
      await state.fetchRemoteBookings();
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final data = switch (request.url.path) {
            '/api/v1/payment/orders' => {'content': <Map<String, dynamic>>[]},
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
      state.initPaymentApi(api: paymentApi, accessToken: 'worker-jwt');
      await state.fetchRemotePayments();
      final quoteApi = WorkerQuoteApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient(
          (request) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [_quoteJson],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: OrderDetailPage(
              orderId: 'booking-1',
              refreshInterval: null,
              quoteApi: quoteApi,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final statusRegion = find.byKey(
        const ValueKey('worker-completed-payment-status-booking-1'),
      );
      final fundRegion = find.byKey(
        const ValueKey('worker-completed-fund-summary-booking-1'),
      );
      expect(statusRegion, findsOneWidget);
      expect(fundRegion, findsOneWidget);
      expect(_nonEmptyTextDataWithin(statusRegion), ['等待业主付款']);
      final fundText = _nonEmptyTextDataWithin(fundRegion);
      expect(fundText, containsAll(['预计工程款', '¥10440', '履约质保金余额', '核算中']));
      expect(fundText.where((text) => text.contains('%')), isEmpty);
      _expectNoWorkerFeeText([
        ..._nonEmptyTextDataWithin(statusRegion),
        ...fundText,
      ]);
      expect(find.text('本单可结算'), findsNothing);
      expect(find.text('查看收入明细'), findsNothing);
    },
  );

  for (final testCase in const [
    (
      name: 'reported',
      constructionStatus: 'REPORTED',
      feeStatus: 'REPORTED',
      orderStatus: 'UNDER_REVIEW',
      statusText: '业主已付工程款，待确认到账',
    ),
    (
      name: 'confirmed-not-paid',
      constructionStatus: 'CONFIRMED',
      feeStatus: 'REPORTED',
      orderStatus: 'UNDER_REVIEW',
      statusText: '工程款已确认，付款状态核验中',
    ),
    (
      name: 'paid',
      constructionStatus: 'CONFIRMED',
      feeStatus: 'VERIFIED',
      orderStatus: 'PAID',
      statusText: '本单款项已核验',
    ),
  ]) {
    testWidgets(
      'split completed archive ${testCase.name} has scoped neutral funds',
      (tester) async {
        await _pumpCompletedArchive(
          tester,
          paymentOrder: {
            ..._confirmedSplitPaymentOrderJson,
            'constructionPaymentStatus': testCase.constructionStatus,
            'platformFeeStatus': testCase.feeStatus,
            'status': testCase.orderStatus,
          },
          workerWarrantyAccount: _workerWarrantyAccountJson,
        );

        final statusRegion = find.byKey(
          const ValueKey('worker-completed-payment-status-booking-1'),
        );
        final fundRegion = find.byKey(
          const ValueKey('worker-completed-fund-summary-booking-1'),
        );
        expect(statusRegion, findsOneWidget);
        expect(fundRegion, findsOneWidget);
        expect(_nonEmptyTextDataWithin(statusRegion), [testCase.statusText]);
        final fundText = _nonEmptyTextDataWithin(fundRegion);
        expect(fundText, containsAll(['本单工程款', '履约质保金余额']));
        expect(
          fundText.where((text) => text.contains('¥')),
          unorderedEquals(['¥10440', '¥1044']),
        );
        expect(fundText.where((text) => text.contains('%')), isEmpty);
        _expectNoWorkerFeeText([
          ..._nonEmptyTextDataWithin(statusRegion),
          ...fundText,
        ]);
      },
    );
  }

  testWidgets('completed order detail is a read-only completed archive', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    state.initBookingApi(
      api: _FakeWorkerBookingApi([_booking(status: 'COMPLETED')]),
      accessToken: 'worker-jwt',
    );
    await state.fetchRemoteBookings();
    final paymentApi = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        final data = switch (request.url.path) {
          '/api/v1/payment/orders' => {'content': <Map<String, dynamic>>[]},
          '/api/v1/settlements' => [_settlementJson],
          '/api/v1/warranty-retentions' => [_warrantyJson],
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
    state.initPaymentApi(api: paymentApi, accessToken: 'worker-jwt');
    await state.fetchRemotePayments();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: const MaterialApp(
          home: OrderDetailPage(orderId: 'booking-1', refreshInterval: null),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('完工档案'), findsOneWidget);
    expect(find.text('施工记录'), findsOneWidget);
    expect(find.text('验收记录'), findsOneWidget);
    expect(find.text('收入与质保金'), findsOneWidget);
    final statusRegion = find.byKey(
      const ValueKey('worker-completed-payment-status-booking-1'),
    );
    final fundRegion = find.byKey(
      const ValueKey('worker-completed-fund-summary-booking-1'),
    );
    expect(statusRegion, findsOneWidget);
    expect(fundRegion, findsOneWidget);
    expect(_nonEmptyTextDataWithin(statusRegion), ['已确认收款']);
    final fundText = _nonEmptyTextDataWithin(fundRegion);
    expect(fundText, containsAll(['本单可结算', '本单质保金']));
    expect(
      fundText.where((text) => text.contains('¥')),
      unorderedEquals(['¥5220', '¥580']),
    );
    expect(fundText.where((text) => text.contains('%')), isEmpty);
    _expectNoWorkerFeeText([
      ..._nonEmptyTextDataWithin(statusRegion),
      ...fundText,
    ]);
    expect(find.text('联系业主'), findsNothing);
    expect(find.text('13800000000'), findsNothing);
    expect(find.text('138****0000'), findsOneWidget);
    expect(find.text('查看收入明细'), findsOneWidget);
    expect(find.text('提交日报'), findsNothing);
    expect(find.text('发起验收'), findsNothing);
    expect(find.text('完成施工'), findsNothing);
  });
}

Future<void> _pumpCompletedArchive(
  WidgetTester tester, {
  required Map<String, dynamic> paymentOrder,
  Map<String, dynamic>? workerWarrantyAccount,
}) async {
  final state = await WorkerAppState.memory();
  state.loginWithToken('worker-jwt');
  state.initBookingApi(
    api: _FakeWorkerBookingApi([_booking(status: 'COMPLETED')]),
    accessToken: 'worker-jwt',
  );
  await state.fetchRemoteBookings();
  final paymentApi = PaymentApiClient(
    baseUrl: Uri.parse('http://example.test'),
    httpClient: MockClient((request) async {
      final data = switch (request.url.path) {
        '/api/v1/payment/orders' => {
          'content': [paymentOrder],
        },
        '/api/v1/settlements' => <Map<String, dynamic>>[],
        '/api/v1/warranty-retentions' => <Map<String, dynamic>>[],
        '/api/v1/worker-warranty/account' =>
          workerWarrantyAccount ?? <Map<String, dynamic>>[],
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
  state.initPaymentApi(api: paymentApi, accessToken: 'worker-jwt');
  await state.fetchRemotePayments();

  await tester.pumpWidget(
    WorkerAppScope(
      state: state,
      child: const MaterialApp(
        home: OrderDetailPage(orderId: 'booking-1', refreshInterval: null),
      ),
    ),
  );
  await tester.pumpAndSettle();
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

const _settlementJson = {
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

const _warrantyJson = {
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

const _confirmedSplitPaymentOrderJson = {
  'id': 'payment-split-confirmed-1',
  'bookingId': 'booking-1',
  'ownerUserId': 'owner-1',
  'workerUserId': 'worker-1',
  'quoteId': 'quote-1',
  'amount': 11484,
  'platformFee': 1044,
  'workerSettlement': 10440,
  'warrantyRetention': 0,
  'fundingModel': 'OFFLINE_SPLIT_V2',
  'quoteAmount': 10440,
  'constructionPaymentStatus': 'CONFIRMED',
  'platformFeeStatus': 'REPORTED',
  'status': 'UNDER_REVIEW',
  'paymentMethod': 'OFFLINE',
  'createdAt': '2026-08-07T01:00:00Z',
  'updatedAt': '2026-08-07T01:01:00Z',
};

const _workerWarrantyAccountJson = {
  'id': 'warranty-account-1',
  'workerUserId': 'worker-1',
  'effectiveBalance': 1044,
  'deductedTotal': 0,
  'releasedTotal': 0,
  'capAmount': 10000,
  'outstandingAmount': 0,
  'status': 'ACTIVE',
  'canAcceptNewJobs': true,
  'createdAt': '2026-08-07T01:00:00Z',
  'updatedAt': '2026-08-07T01:01:00Z',
};

const _quoteJson = {
  'id': 'quote-1',
  'bookingId': 'booking-1',
  'workerUserId': 'worker-1',
  'workerName': '模拟器闭环木工',
  'status': 'SUBMITTED',
  'items': [
    {
      'name': '吊顶安装',
      'quantity': 30,
      'unit': '平方米',
      'unitPrice': 120,
      'subtotal': 3600,
      'laborFee': 3600,
      'auxiliaryFee': 0,
      'mainMaterialFee': 0,
    },
    {
      'name': '板材材料',
      'quantity': 38,
      'unit': '张',
      'unitPrice': 180,
      'subtotal': 6840,
      'laborFee': 0,
      'auxiliaryFee': 6840,
      'mainMaterialFee': 0,
    },
  ],
  'createdAt': '2026-08-06T01:00:00Z',
  'updatedAt': '2026-08-06T01:00:00Z',
};

RemoteWorkerBooking _booking({
  String id = 'booking-1',
  String ownerName = '业主',
  required String status,
  DateTime? scheduledVisitAt,
  DateTime? actualOnSiteAt,
  HouseInfo? houseInfo,
}) => RemoteWorkerBooking(
  id: id,
  ownerUserId: 'owner-1',
  ownerName: ownerName,
  ownerPhone: '13800000000',
  serviceRequestId: 'request-1',
  workerUserId: 'worker-1',
  workerName: '模拟器闭环木工',
  trade: 'carpentry',
  serviceCity: '成都',
  serviceAddress: 'Android Studio 模拟器小区',
  houseInfo: houseInfo,
  status: status,
  arrivalConfirmedByOwner: status == 'ON_SITE',
  arrivalConfirmedByWorker: true,
  onSiteAt: status == 'ON_SITE' ? DateTime.utc(2026, 7, 18, 10) : null,
  scheduledVisitAt: scheduledVisitAt,
  actualOnSiteAt: actualOnSiteAt,
  createdAt: DateTime.utc(2026, 7, 18),
  updatedAt: DateTime.utc(2026, 7, 18, 10),
);

final class _FakeWorkerBookingApi implements WorkerBookingApi {
  _FakeWorkerBookingApi(this.bookings);

  List<RemoteWorkerBooking> bookings;

  @override
  Future<List<RemoteWorkerBooking>> listWorkerBookings(
    String accessToken,
  ) async => bookings;

  @override
  Future<RemoteWorkerBooking> acceptBooking(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();

  @override
  Future<RemoteWorkerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) => throw UnimplementedError();

  @override
  Future<RemoteWorkerBooking> rejectBooking(
    String accessToken,
    String bookingId,
  ) => throw UnimplementedError();
}
