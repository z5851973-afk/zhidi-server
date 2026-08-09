import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/owner_quote_compare_page.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';
import 'package:zhidi_app/services/worker_quote_api_client.dart';

void main() {
  testWidgets('loads and displays server quotes for comparison', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      store: MemoryOwnerStore(),
      sessionStore: MemoryAuthSessionStore(_session()),
      profileApi: _ProfileApi(),
      bookingApi: _BookingApi(),
    );
    final api = WorkerQuoteApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/service-requests/request-1/quotes');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [
                _quoteJson('quote-high', '张师傅', 15000),
                _quoteJson('quote-low', '李师傅', 12000),
              ],
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
          home: OwnerQuoteComparePage(
            serviceRequestId: 'request-1',
            quoteApi: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('李师傅'), findsOneWidget);
    expect(find.text('张师傅'), findsOneWidget);
    expect(find.text('最低价'), findsOneWidget);
    expect(find.text('确认选择该师傅'), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text('选人确认'), 300);
    expect(find.textContaining('不会发起付款或划转资金'), findsOneWidget);
    expect(find.textContaining('托管'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses candidate worker name when quote omits workerName', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      store: MemoryOwnerStore(),
      sessionStore: MemoryAuthSessionStore(_session()),
      profileApi: _ProfileApi(),
      bookingApi: _BookingApi(),
    );
    final api = WorkerQuoteApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [
                {
                  ..._quoteJson('quote-1', '不会显示的名字', 160),
                  'workerName': null,
                  'workerUserId': 'worker-1',
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
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: OwnerQuoteComparePage(
            serviceRequestId: 'request-1',
            quoteApi: api,
            workerNamesById: const {'worker-1': 'UI闭环水电师傅'},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UI闭环水电师傅'), findsOneWidget);
    expect(find.text('未知师傅'), findsNothing);
  });

  testWidgets('owner sees itemized quote plus platform fee before selection', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      store: MemoryOwnerStore(),
      sessionStore: MemoryAuthSessionStore(_session()),
      profileApi: _ProfileApi(),
      bookingApi: _BookingApi(),
    );
    final api = WorkerQuoteApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [_itemizedQuoteJson('quote-1', '李师傅')],
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
          home: OwnerQuoteComparePage(
            serviceRequestId: 'request-1',
            quoteApi: api,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('人工明细'), findsOneWidget);
    expect(find.text('材料明细'), findsOneWidget);
    expect(find.text('吊顶安装'), findsOneWidget);
    expect(find.text('30平方米'), findsOneWidget);
    expect(find.text('板材材料'), findsOneWidget);
    expect(find.text('38张'), findsOneWidget);
    expect(find.text('报价总价'), findsOneWidget);
    expect(find.text('¥10440.00'), findsWidgets);
    expect(find.text('平台服务费（10%）'), findsOneWidget);
    expect(find.text('¥1044.00'), findsOneWidget);
    expect(find.text('业主应付'), findsOneWidget);
    expect(find.text('¥11484.00'), findsOneWidget);
  });

  testWidgets('quote selection requires acknowledgement and two-second hold', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (_) => const QuoteSelectionConfirmationDialog(
                    workerName: '张师傅',
                    totalPrice: 12800,
                  ),
                );
              },
              child: const Text('选择报价'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('选择报价'));
    await tester.pumpAndSettle();
    expect(find.textContaining('¥12800.00'), findsOneWidget);
    expect(find.text('本次操作只选择师傅和报价，不会发起付款或划转资金。'), findsOneWidget);
    expect(find.textContaining('托管'), findsNothing);

    final button = find.byKey(const Key('quote-hold-confirm'));
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();

    var gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 1500));
    await gesture.up();
    await tester.pump();
    expect(result, isNull);
    expect(find.text('确认选人'), findsOneWidget);

    gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    await gesture.up();
  });

  testWidgets('confirmation repeats quote fee and owner payable total', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                showDialog<bool>(
                  context: context,
                  builder: (_) => const QuoteSelectionConfirmationDialog(
                    workerName: '李师傅',
                    totalPrice: 10840,
                  ),
                );
              },
              child: const Text('选择报价'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('选择报价'));
    await tester.pumpAndSettle();

    expect(find.text('报价总价'), findsOneWidget);
    expect(find.text('¥10840.00'), findsOneWidget);
    expect(find.text('平台服务费（10%）'), findsOneWidget);
    expect(find.text('¥1084.00'), findsOneWidget);
    expect(find.text('业主应付'), findsOneWidget);
    expect(find.text('¥11924.00'), findsOneWidget);
    expect(find.textContaining('平台服务费在师傅报价之外另行收取'), findsOneWidget);
  });

  testWidgets('accepted comparison returns changed result to previous page', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      store: MemoryOwnerStore(),
      sessionStore: MemoryAuthSessionStore(_session()),
      profileApi: _ProfileApi(),
      bookingApi: _BookingApi(),
    );
    var accepted = false;
    final api = WorkerQuoteApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        if (request.method == 'PUT') accepted = true;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': request.method == 'GET'
                  ? [_quoteJson('quote-1', '李师傅', 12000)]
                  : {
                      ..._quoteJson('quote-1', '李师傅', 12000),
                      'status': 'ACCEPTED',
                    },
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    bool? changed;

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnerQuoteComparePage(
                        serviceRequestId: 'request-1',
                        quoteApi: api,
                      ),
                    ),
                  );
                },
                child: const Text('打开报价对比'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开报价对比'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('选人确认'), 300);
    await tester.tap(find.text('我已核对师傅、报价明细和总价'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('确认选择该师傅'), 300);
    await tester.tap(find.text('确认选择该师傅'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump();
    final button = find.byKey(const Key('quote-hold-confirm'));
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await gesture.up();

    expect(accepted, isTrue);
    expect(changed, isTrue);
  });
}

Map<String, dynamic> _quoteJson(String id, String workerName, double total) => {
  'id': id,
  'bookingId': 'booking-$id',
  'workerUserId': 'worker-$id',
  'workerName': workerName,
  'status': 'SUBMITTED',
  'items': [
    {
      'name': '施工项目',
      'quantity': 1,
      'unit': '项',
      'unitPrice': total,
      'subtotal': total,
    },
  ],
  'createdAt': '2026-07-19T01:00:00Z',
  'updatedAt': '2026-07-19T01:00:00Z',
};

Map<String, dynamic> _itemizedQuoteJson(String id, String workerName) => {
  'id': id,
  'bookingId': 'booking-$id',
  'workerUserId': 'worker-$id',
  'workerName': workerName,
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
  'createdAt': '2026-07-19T01:00:00Z',
  'updatedAt': '2026-07-19T01:00:00Z',
};

AuthSession _session() => AuthSession(
  accessToken: 'owner-token',
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(const Duration(days: 1)),
  userId: 'owner-user-id',
  phone: '13555555555',
  roles: const ['OWNER'],
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
