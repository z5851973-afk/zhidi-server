import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/design/tokens.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/inspection_api_client.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';
import 'package:zhidi_app/services/payment_api_client.dart';
import 'package:zhidi_app/services/service_request_api_client.dart';
import 'package:zhidi_app/services/worker_quote_api_client.dart';

BookedWorker _worker({
  String id = 'worker-1',
  String name = '李师傅',
  int phaseIndex = 0,
  String phaseName = '拆除',
  String status = '已接单待上门',
}) {
  return BookedWorker(
    id: id,
    name: name,
    trade: '拆除工',
    phaseName: phaseName,
    phaseIndex: phaseIndex,
    rating: 4.9,
    completedOrders: 128,
    years: 8,
    avatarEmoji: '👷',
    skills: const ['拆墙', '垃圾清运'],
    status: status,
  );
}

// ignore: unused_element
Future<OwnerAppState> _stateWithWorker() async {
  final state = await OwnerAppState.memory(store: MemoryOwnerStore());
  await state.bookWorker(_worker());
  return state;
}

// ignore: unused_element
Future<void> _pumpMyHome(WidgetTester tester, OwnerAppState state) async {
  await tester.pumpWidget(
    OwnerAppScope(
      state: state,
      child: const MaterialApp(home: Scaffold(body: MyHomePage())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows direct remote booking when service request list is empty',
    (tester) async {
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
      final serviceRequestApi = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient(
          (request) async =>
              http.Response('{"code":"OK","message":"success","data":[]}', 200),
        ),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: MyHomePage(
                serviceRequestApi: serviceRequestApi,
                paymentApi: _emptyPaymentApi(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GT'), findsOneWidget);
      expect(find.text('待接单'), findsOneWidget);
      expect(find.text('还没有装修需求'), findsNothing);
    },
  );

  testWidgets('refreshes service requests when refresh epoch changes', (
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
      bookingApi: _EmptyBookingApi(),
    );
    var listCalls = 0;
    final api = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        listCalls++;
        final data = listCalls == 1
            ? '[]'
            : '[{"id":"request-1","ownerUserId":"owner-user-id",'
                  '"trade":"plumbing","serviceCity":"成都",'
                  '"serviceAddress":"测试小区","remark":null,'
                  '"status":"OPEN","candidates":[],'
                  '"createdAt":"2026-07-18T08:00:00Z",'
                  '"updatedAt":"2026-07-18T08:00:00Z"}]';
        return http.Response.bytes(
          utf8.encode('{"code":"OK","message":"success","data":$data}'),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    Widget page(int epoch) => OwnerAppScope(
      state: state,
      child: MaterialApp(
        home: Scaffold(
          body: MyHomePage(
            serviceRequestApi: api,
            paymentApi: _emptyPaymentApi(),
            refreshEpoch: epoch,
          ),
        ),
      ),
    );

    await tester.pumpWidget(page(0));
    await tester.pumpAndSettle();
    expect(find.text('还没有装修需求'), findsOneWidget);

    await tester.pumpWidget(page(1));
    await tester.pumpAndSettle();
    expect(listCalls, 2);
    expect(find.text('水电师傅'), findsOneWidget);
    expect(find.text('还没有装修需求'), findsNothing);
  });

  testWidgets(
    'failed refresh keeps the last server project and exposes retry',
    (tester) async {
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
        bookingApi: _EmptyBookingApi(),
      );
      var fail = false;
      final api = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          if (fail) {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'code': 'TEMPORARY_FAILURE',
                  'message': '服务端暂时不可用',
                  'data': null,
                }),
              ),
              503,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            );
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [
                  _serviceRequestJson(
                    id: 'request-last-good',
                    trade: 'carpentry',
                    candidateStatus: null,
                  ),
                ],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await state.fetchRemoteServiceRequests(serviceRequestApi: api);
      fail = true;
      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: MyHomePage(
                serviceRequestApi: api,
                paymentApi: _emptyPaymentApi(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('木工师傅'), findsOneWidget);
      expect(find.textContaining('服务端暂时不可用'), findsOneWidget);
      expect(find.text('重试'), findsOneWidget);
    },
  );

  testWidgets('refresh epoch reloads booking quote data', (tester) async {
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
      bookingApi: _EmptyBookingApi(),
    );
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [_serviceRequestJson(candidateStatus: 'QUOTE_PENDING')],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    var quoteCalls = 0;
    final quoteApi = WorkerQuoteApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/bookings/booking-arrival/quotes');
        quoteCalls++;
        final total = quoteCalls == 1 ? 12860 : 8240;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [
                _remoteQuoteJson(
                  total: total,
                  updatedAt: quoteCalls == 1
                      ? '2026-08-08T08:00:00Z'
                      : '2026-08-08T09:00:00Z',
                ),
              ],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    Widget page(int epoch) => OwnerAppScope(
      state: state,
      child: MaterialApp(
        home: Scaffold(
          body: MyHomePage(
            serviceRequestApi: serviceApi,
            paymentApi: _emptyPaymentApi(),
            quoteApi: quoteApi,
            refreshEpoch: epoch,
          ),
        ),
      ),
    );

    await tester.pumpWidget(page(0));
    await tester.pumpAndSettle();
    expect(quoteCalls, 1);
    expect(find.text('¥12860'), findsOneWidget);

    await tester.pumpWidget(page(1));
    await tester.pumpAndSettle();

    expect(quoteCalls, 2);
    expect(find.text('¥8240'), findsOneWidget);
    expect(find.text('¥12860'), findsNothing);
  });

  testWidgets(
    'keeps same-trade projects separate and deduplicates the same request id',
    (tester) async {
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
        bookingApi: _EmptyBookingApi(),
      );
      final api = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final data = [
            _serviceRequestJson(
              id: 'masonry-empty',
              trade: 'masonry',
              status: 'OPEN',
              candidateStatus: null,
              houseInfo: const {
                'areaSqm': 80,
                'bedroomCount': 2,
                'livingRoomCount': 1,
                'kitchenCount': 1,
                'bathroomCount': 1,
              },
              updatedAt: '2026-07-18T08:00:00Z',
            ),
            _serviceRequestJson(
              id: 'masonry-with-candidate',
              trade: 'masonry',
              status: 'COMPARING',
              candidateStatus: 'PENDING',
              houseInfo: const {
                'areaSqm': 120,
                'bedroomCount': 4,
                'livingRoomCount': 2,
                'kitchenCount': 1,
                'bathroomCount': 2,
              },
              updatedAt: '2026-07-18T09:00:00Z',
            ),
            _serviceRequestJson(
              id: 'masonry-with-candidate',
              trade: 'masonry',
              status: 'OPEN',
              candidateStatus: null,
              updatedAt: '2026-07-18T07:00:00Z',
            ),
            _serviceRequestJson(
              id: 'plumbing-request',
              trade: 'plumbing',
              status: 'OPEN',
              candidateStatus: null,
              houseInfo: const {
                'areaSqm': 98.5,
                'bedroomCount': 3,
                'livingRoomCount': 2,
                'kitchenCount': 1,
                'bathroomCount': 2,
              },
              updatedAt: '2026-07-18T10:00:00Z',
            ),
          ];
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
            home: Scaffold(
              body: MyHomePage(
                serviceRequestApi: api,
                paymentApi: _emptyPaymentApi(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('泥瓦师傅'), findsNWidgets(2));
      expect(find.text('水电师傅'), findsOneWidget);
      expect(
        find.byKey(const Key('service-request-masonry-empty')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('service-request-masonry-with-candidate')),
        findsOneWidget,
      );
      expect(find.text('成都 · 1位候选师傅 · 1次邀请'), findsOneWidget);
      expect(find.text('成都 · 0位候选师傅 · 0次邀请'), findsNWidgets(2));
      expect(find.text('80㎡ · 2室1厅1厨1卫'), findsOneWidget);
      expect(find.text('120㎡ · 4室2厅1厨2卫'), findsOneWidget);
      expect(find.text('98.5㎡ · 3室2厅1厨2卫'), findsOneWidget);
      expect(find.text('房屋信息未填写'), findsNothing);

      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('水电师傅'));
      await tester.pumpAndSettle();
      expect(find.text('水电师傅 · 候选'), findsOneWidget);
      expect(find.text('98.5㎡ · 3室2厅1厨2卫'), findsOneWidget);
    },
  );

  testWidgets(
    'completed candidate marks its decoration requirement completed',
    (tester) async {
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
        bookingApi: _EmptyBookingApi(),
      );
      final serviceApi = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final data = [
            _serviceRequestJson(
              id: 'completed-carpentry',
              trade: 'carpentry',
              status: 'WORKER_SELECTED',
              candidateStatus: 'COMPLETED',
              createdAt: '2026-08-05T08:00:00Z',
            ),
            _serviceRequestJson(
              id: 'active-plumbing',
              trade: 'plumbing',
              status: 'OPEN',
              candidateStatus: 'PENDING',
              createdAt: '2026-08-06T08:00:00Z',
            ),
          ];
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
            home: Scaffold(
              body: MyHomePage(
                serviceRequestApi: serviceApi,
                paymentApi: _emptyPaymentApi(),
                quoteApi: _emptyQuoteApi(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('木工师傅'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      expect(find.text('已选定'), findsNothing);
      final completedLabel = tester.widget<Text>(find.text('已完成'));
      expect(completedLabel.style?.color, ZdColors.success);
    },
  );

  testWidgets(
    'new open request is not replaced by an older completed same-trade project',
    (tester) async {
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
        bookingApi: _EmptyBookingApi(),
      );
      final serviceApi = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [
                  _serviceRequestJson(
                    id: 'completed-carpentry',
                    trade: 'carpentry',
                    status: 'WORKER_SELECTED',
                    candidateStatus: 'COMPLETED',
                    workerName: '历史木工师傅',
                    createdAt: '2026-08-07T08:00:00Z',
                    updatedAt: '2026-08-07T08:00:00Z',
                  ),
                  _serviceRequestJson(
                    id: 'new-carpentry',
                    trade: 'carpentry',
                    status: 'OPEN',
                    candidateStatus: null,
                    createdAt: '2026-08-08T08:00:00Z',
                    updatedAt: '2026-08-08T08:00:00Z',
                  ),
                ],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [_paymentOrderJson(status: 'PAID')],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: MyHomePage(
                serviceRequestApi: serviceApi,
                paymentApi: paymentApi,
                quoteApi: _emptyQuoteApi(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('历史木工师傅'), findsNothing);
      expect(find.text('木工改造项目'), findsNothing);
      expect(find.text('已支付 · 查看记录'), findsNothing);
      expect(find.text('待匹配'), findsOneWidget);
      expect(find.text('成都 · 0位候选师傅 · 0次邀请'), findsOneWidget);
    },
  );

  testWidgets(
    'new open request keeps an older hired same-trade project visible',
    (tester) async {
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
        bookingApi: _EmptyBookingApi(),
      );
      final serviceApi = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [
                  _serviceRequestJson(
                    id: 'hired-carpentry',
                    trade: 'carpentry',
                    status: 'WORKER_SELECTED',
                    candidateStatus: 'HIRED',
                    workerName: '施工中木工师傅',
                    createdAt: '2026-08-07T08:00:00Z',
                    updatedAt: '2026-08-07T08:00:00Z',
                  ),
                  _serviceRequestJson(
                    id: 'new-carpentry',
                    trade: 'carpentry',
                    status: 'OPEN',
                    candidateStatus: null,
                    createdAt: '2026-08-08T08:00:00Z',
                    updatedAt: '2026-08-08T08:00:00Z',
                  ),
                ],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: MyHomePage(
                serviceRequestApi: serviceApi,
                paymentApi: _emptyPaymentApi(),
                quoteApi: _emptyQuoteApi(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('施工中木工师傅'), findsOneWidget);
      expect(find.text('施工中'), findsWidgets);
      expect(find.text('待匹配'), findsOneWidget);
    },
  );

  testWidgets('open request cannot feature its completed candidate', (
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
      bookingApi: _EmptyBookingApi(),
    );
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [
                _serviceRequestJson(
                  id: 'open-carpentry',
                  trade: 'carpentry',
                  status: 'OPEN',
                  candidateStatus: 'COMPLETED',
                  workerName: '异常归档师傅',
                ),
              ],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: _emptyPaymentApi(),
              quoteApi: _emptyQuoteApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('异常归档师傅'), findsNothing);
    expect(find.text('木工改造项目'), findsNothing);
  });

  testWidgets('rejected worker returns the latest trade request to matching', (
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
      bookingApi: _EmptyBookingApi(),
    );
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        final data = [
          _serviceRequestJson(
            id: 'completed-carpentry',
            trade: 'carpentry',
            status: 'WORKER_SELECTED',
            candidateStatus: 'COMPLETED',
            createdAt: '2026-08-05T08:00:00Z',
          ),
          _serviceRequestJson(
            id: 'rejected-carpentry',
            trade: 'carpentry',
            status: 'OPEN',
            candidateStatus: 'REJECTED',
            createdAt: '2026-08-06T08:00:00Z',
          ),
        ];
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
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: _emptyPaymentApi(),
              quoteApi: _emptyQuoteApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('木工师傅 · 候选'), findsNothing);
    expect(find.text('REJECTED'), findsNothing);
    expect(find.text('待匹配'), findsOneWidget);
    expect(find.text('成都 · 0位候选师傅 · 1次邀请'), findsNWidgets(2));

    final rejectedRequest = find.byKey(
      const Key('service-request-rejected-carpentry'),
    );
    await tester.ensureVisible(rejectedRequest);
    await tester.pumpAndSettle();
    await tester.tap(rejectedRequest);
    await tester.pumpAndSettle();

    expect(find.text('已结束'), findsOneWidget);
    expect(find.text('已拒绝'), findsOneWidget);
    expect(find.text('取消'), findsNothing);
  });

  testWidgets('confirms worker arrival directly from project workbench', (
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
      bookingApi: _EmptyBookingApi(),
    );
    var confirmedArrival = false;
    final api = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        if (request.method == 'PUT') {
          expect(
            request.url.path,
            '/api/v1/owners/me/bookings/booking-arrival/confirm-arrival',
          );
          confirmedArrival = true;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': _candidateJson(status: 'ON_SITE'),
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [_serviceRequestJson(candidateStatus: 'ARRIVAL_PENDING')],
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
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: api,
              paymentApi: _emptyPaymentApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('确认师傅已到场'), findsOneWidget);
    await tester.tap(find.text('确认师傅已到场'));
    await tester.pumpAndSettle();

    expect(confirmedArrival, isTrue);
  });

  testWidgets('preselected candidate does not show construction workflow', (
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
      bookingApi: _EmptyBookingApi(),
    );
    final api = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [_serviceRequestJson(candidateStatus: 'PENDING')],
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
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: api,
              paymentApi: _emptyPaymentApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('水电师傅 · 候选'), findsOneWidget);
    expect(find.text('待接单'), findsWidgets);
    expect(find.text('待报价'), findsOneWidget);
    expect(find.text('施工中'), findsNothing);
    expect(find.text('施工记录'), findsNothing);
    expect(find.text('验收'), findsNothing);
  });

  testWidgets(
    'project summary distinguishes a proposal from an agreed legacy time',
    (tester) async {
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
        bookingApi: _EmptyBookingApi(),
      );
      final requestJson = _serviceRequestJson(
        candidateStatus: 'VISIT_PROPOSED',
      );
      final candidate =
          (requestJson['candidates'] as List<dynamic>).single
              as Map<String, dynamic>;
      candidate.remove('scheduledVisitAt');
      final api = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [requestJson],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      Widget page() => OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: MyHomePage(
              key: ValueKey(candidate['status']),
              serviceRequestApi: api,
              paymentApi: _emptyPaymentApi(),
            ),
          ),
        ),
      );

      await tester.pumpWidget(page());
      await tester.pumpAndSettle();

      expect(find.text('约定上门时间：待确认'), findsOneWidget);
      expect(find.text('约定上门时间：2026-07-30 09:00'), findsNothing);

      candidate['status'] = 'VISIT_SCHEDULED';
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();

      expect(find.text('约定上门时间：2026-07-30 09:00'), findsOneWidget);
    },
  );

  testWidgets('service request detail refreshes stale candidate status', (
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
      bookingApi: _EmptyBookingApi(),
    );
    var listCalls = 0;
    final api = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        listCalls++;
        final status = listCalls == 1 ? 'PENDING' : 'ON_SITE';
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [_serviceRequestJson(candidateStatus: status)],
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
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: api,
              paymentApi: _emptyPaymentApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('待接单'), findsWidgets);
    await tester.tap(find.text('查看进度').first);
    await tester.pumpAndSettle();

    expect(listCalls, greaterThanOrEqualTo(2));
    expect(find.text('约定上门时间：2026-07-30 09:00'), findsWidgets);
    expect(find.text('实际到场时间：2026-07-29 16:38'), findsWidgets);
    expect(find.text('取消'), findsNothing);
  });

  testWidgets('hired project lets worker initiate inspection only', (
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
      bookingApi: _EmptyBookingApi(),
    );
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [_serviceRequestJson(candidateStatus: 'HIRED')],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: _emptyPaymentApi(),
              quoteApi: _emptyQuoteApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('施工中'), findsWidgets);
    expect(find.text('申请验收'), findsNothing);
    expect(find.text('发起验收'), findsNothing);
    expect(find.text('验收进度'), findsOneWidget);
    expect(find.text('查看进度 >'), findsOneWidget);
  });

  testWidgets('refreshes completed project after returning from inspection', (
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
      bookingApi: _EmptyBookingApi(),
    );
    var listCalls = 0;
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        listCalls++;
        final status = listCalls == 1 ? 'HIRED' : 'COMPLETED';
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [
                _serviceRequestJson(
                  status: 'WORKER_SELECTED',
                  candidateStatus: status,
                ),
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
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: _emptyPaymentApi(),
              quoteApi: _emptyQuoteApi(),
              inspectionApi: const _EmptyInspectionApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('施工中'), findsWidgets);
    await tester.tap(find.text('验收进度'));
    await tester.pumpAndSettle();
    expect(find.text('节点验收'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(listCalls, 2);
    expect(find.text('已完成'), findsWidgets);
    expect(find.text('施工中'), findsOneWidget);
  });

  testWidgets('exact missing target does not show an unrelated appointment', (
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
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [_serviceRequestJson()],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: _emptyPaymentApi(),
              initialServiceRequestId: 'missing-request',
              initialBookingId: 'missing-booking',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('该订单已更新或不再可用'), findsOneWidget);
    expect(find.text('GT'), findsNothing);
  });

  testWidgets('exact missing target hides every unrelated local cost source', (
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
      bookingApi: _EmptyBookingApi(),
    );
    await state.addSavedQuote(
      SavedQuote(
        id: 'unrelated-old-quote',
        workerName: '旧项目师傅',
        tradeName: '木工',
        items: const [],
        grandTotal: 200,
        savedAt: DateTime.utc(2026, 8, 8),
      ),
    );
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [_serviceRequestJson()],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: _emptyPaymentApi(),
              initialServiceRequestId: 'missing-request',
              initialBookingId: 'missing-booking',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('该订单已更新或不再可用'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('my-home-cost-card')), findsNothing);
    expect(find.text('¥200'), findsNothing);
  });

  testWidgets(
    'exact existing booking hides unrelated local cost and document sources',
    (tester) async {
      final store = MemoryOwnerStore();
      final sessionStore = MemoryAuthSessionStore(
        AuthSession(
          accessToken: 'owner-token',
          tokenType: 'Bearer',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
          userId: 'owner-user-id',
          phone: '13555555555',
          roles: const ['OWNER'],
        ),
      );
      var state = await OwnerAppState.memory(
        store: store,
        sessionStore: sessionStore,
        profileApi: _ProfileApi(),
        bookingApi: _EmptyBookingApi(),
      );
      await state.addSavedQuote(
        SavedQuote(
          id: 'unrelated-quote',
          workerName: '乙订单师傅',
          tradeName: '木工',
          items: const [],
          grandTotal: 4321,
          savedAt: DateTime.utc(2026, 8, 8),
        ),
      );
      await state.addMaterialEstimate(
        MaterialEstimate(
          id: 'unrelated-estimate',
          workerId: 'unrelated-worker',
          workerName: '乙订单师傅',
          workerTrade: '木工',
          phaseName: '木工',
          phaseIndex: 4,
          createdAt: DateTime.utc(2026, 8, 8),
          selectedItemIds: const {'unrelated-material'},
          items: const [
            MaterialItem(
              id: 'unrelated-material',
              name: '乙订单材料',
              category: MaterialCategory.auxiliary,
              unit: '件',
              quantity: 1,
              unitPrice: 777,
            ),
          ],
        ),
      );
      final document =
          jsonDecode(store.getString(OwnerAppState.documentKey)!)
              as Map<String, dynamic>;
      document['bookedWorkers'] = [
        _worker(
          id: 'unrelated-worker',
          name: '乙订单师傅',
          phaseIndex: 4,
          phaseName: '木工',
        ).toJson(),
      ];
      await store.setString(OwnerAppState.documentKey, jsonEncode(document));
      state = await OwnerAppState.memory(
        store: store,
        sessionStore: sessionStore,
        profileApi: _ProfileApi(),
        bookingApi: _EmptyBookingApi(),
      );
      final requestJson = _serviceRequestJson(
        id: 'exact-request',
        bookingId: 'exact-booking',
        workerName: '甲订单师傅',
      );
      final serviceApi = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [requestJson],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: MyHomePage(
                serviceRequestApi: serviceApi,
                paymentApi: _emptyPaymentApi(),
                quoteApi: _emptyQuoteApi(),
                initialServiceRequestId: 'exact-request',
                initialBookingId: 'exact-booking',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('甲订单师傅'), findsWidgets);
      expect(find.text('乙订单师傅'), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, -1600));
      await tester.pumpAndSettle();

      expect(find.text('乙订单师傅'), findsNothing);
      expect(find.byKey(const Key('my-home-cost-card')), findsNothing);
      expect(find.byKey(const Key('my-home-documents-card')), findsNothing);
      expect(find.text('¥4321'), findsNothing);
      expect(find.text('¥777'), findsNothing);
      expect(find.text('¥1800'), findsNothing);
    },
  );

  testWidgets(
    'exact booking stays scoped after opening its decoration request card',
    (tester) async {
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
        bookingApi: _EmptyBookingApi(),
      );
      final requestJson = _serviceRequestJson(
        id: 'exact-request',
        bookingId: 'exact-booking',
        workerName: '目标师傅',
      );
      requestJson['candidates'] = [
        _candidateJson(
          status: 'PENDING',
          serviceRequestId: 'exact-request',
          bookingId: 'exact-booking',
          workerName: '目标师傅',
        ),
        _candidateJson(
          status: 'PENDING',
          serviceRequestId: 'exact-request',
          bookingId: 'other-booking',
          workerName: '其他师傅',
        ),
      ];
      final serviceApi = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [requestJson],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: MyHomePage(
                serviceRequestApi: serviceApi,
                paymentApi: _emptyPaymentApi(),
                initialServiceRequestId: 'exact-request',
                initialBookingId: 'exact-booking',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('水电师傅').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('水电师傅').last);
      await tester.pumpAndSettle();

      expect(find.text('目标师傅'), findsOneWidget);
      expect(find.text('其他师傅'), findsNothing);
      expect(find.textContaining('已邀请 1 位师傅'), findsOneWidget);
    },
  );

  testWidgets(
    'exact detail becomes unavailable when its booking disappears on refresh',
    (tester) async {
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
        bookingApi: _EmptyBookingApi(),
      );
      final requestJson = _serviceRequestJson(
        id: 'disappearing-request',
        bookingId: 'disappearing-booking',
        workerName: '将消失师傅',
      );
      final delayedDetailRefresh = Completer<http.Response>();
      var listCalls = 0;
      final serviceApi = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((_) async {
          listCalls += 1;
          if (listCalls == 1) {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'code': 'OK',
                  'message': 'success',
                  'data': [requestJson],
                }),
              ),
              200,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            );
          }
          return delayedDetailRefresh.future;
        }),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: MyHomePage(
                serviceRequestApi: serviceApi,
                paymentApi: _emptyPaymentApi(),
                initialServiceRequestId: 'disappearing-request',
                initialBookingId: 'disappearing-booking',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('水电师傅').last, 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('水电师傅').last);
      await tester.pump();

      delayedDetailRefresh.complete(
        http.Response.bytes(
          utf8.encode(
            jsonEncode({'code': 'OK', 'message': 'success', 'data': []}),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('该订单已更新或不再可用'), findsOneWidget);
      expect(find.text('将消失师傅'), findsNothing);
      expect(find.text('查看所有报价'), findsNothing);
    },
  );

  testWidgets('exact detail ignores an old-account refresh after logout', (
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
      bookingApi: _EmptyBookingApi(),
    );
    final initialRequest = _serviceRequestJson(
      id: 'logout-request',
      bookingId: 'logout-booking',
      workerName: '初始师傅',
    );
    final staleRefresh = Completer<http.Response>();
    var listCalls = 0;
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((_) async {
        listCalls += 1;
        if (listCalls == 1) {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [initialRequest],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return staleRefresh.future;
      }),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: _emptyPaymentApi(),
              initialServiceRequestId: 'logout-request',
              initialBookingId: 'logout-booking',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('水电师傅').last, 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('水电师傅').last);
    await tester.pump();

    await state.logout();
    staleRefresh.complete(
      http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': [
              _serviceRequestJson(
                id: 'logout-request',
                bookingId: 'logout-booking',
                workerName: '旧会话师傅',
              ),
            ],
          }),
        ),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('该订单已更新或不再可用'), findsOneWidget);
    expect(find.text('初始师傅'), findsNothing);
    expect(find.text('旧会话师傅'), findsNothing);
  });

  testWidgets('paid selected candidate shows paid record instead of pay CTA', (
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
      bookingApi: _EmptyBookingApi(),
    );
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [_serviceRequestJson(candidateStatus: 'HIRED')],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final paymentApi = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/payment/orders');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [_paymentOrderJson(status: 'PAID')],
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
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: paymentApi,
              quoteApi: _emptyQuoteApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('查看详情 >').first);
    await tester.pumpAndSettle();

    expect(find.text('去支付'), findsNothing);
    expect(find.text('已支付 · 查看记录'), findsOneWidget);
    expect(find.text('售后'), findsNothing);
  });

  testWidgets('completed candidate stays visible with payment entry', (
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
      bookingApi: _EmptyBookingApi(),
    );
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [
                _serviceRequestJson(
                  status: 'WORKER_SELECTED',
                  candidateStatus: 'COMPLETED',
                ),
              ],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final paymentApi = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': <Map<String, dynamic>>[],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: paymentApi,
              quoteApi: _emptyQuoteApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已完成'), findsWidgets);
    await tester.tap(find.text('查看详情 >').first);
    await tester.pumpAndSettle();
    expect(find.text('去支付'), findsOneWidget);
    expect(find.text('售后'), findsNothing);
    expect(find.text('申请验收'), findsNothing);
  });

  testWidgets('completed featured project shows paid payment status', (
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
      bookingApi: _EmptyBookingApi(),
    );
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [
                _serviceRequestJson(
                  status: 'WORKER_SELECTED',
                  candidateStatus: 'COMPLETED',
                ),
              ],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final paymentApi = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        final order = _paymentOrderJson(status: 'PAID');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data':
                  request.url.path == '/api/v1/payment/orders/payment-order-1'
                  ? order
                  : [order],
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
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: paymentApi,
              quoteApi: _emptyQuoteApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('去支付'), findsNothing);
    expect(find.text('已支付 · 查看记录'), findsOneWidget);
    final paidLabel = tester.widget<Text>(find.text('已支付 · 查看记录'));
    expect(paidLabel.maxLines, 1);
    await tester.tap(find.text('查看详情 >').first);
    await tester.pumpAndSettle();
    expect(find.text('售后'), findsOneWidget);
  });

  testWidgets(
    'payment refresh failure clears stale paid state and retries independently',
    (tester) async {
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
        bookingApi: _EmptyBookingApi(),
      );
      var serviceCalls = 0;
      final serviceApi = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          serviceCalls++;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [
                  _serviceRequestJson(
                    status: 'WORKER_SELECTED',
                    candidateStatus: 'COMPLETED',
                  ),
                ],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      var paymentCalls = 0;
      var paymentRecovers = false;
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          paymentCalls++;
          if (paymentCalls > 1 && !paymentRecovers) {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'code': 'TEMPORARY_FAILURE',
                  'message': '支付服务暂时不可用',
                  'data': null,
                }),
              ),
              503,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            );
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [_paymentOrderJson(status: 'PAID')],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      Widget page(int epoch) => OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: paymentApi,
              quoteApi: _emptyQuoteApi(),
              refreshEpoch: epoch,
            ),
          ),
        ),
      );

      await tester.pumpWidget(page(0));
      await tester.pumpAndSettle();
      expect(find.text('已支付 · 查看记录'), findsOneWidget);

      await tester.pumpWidget(page(1));
      await tester.pumpAndSettle();

      expect(find.text('水电改造项目'), findsOneWidget);
      expect(find.text('已支付 · 查看记录'), findsNothing);
      expect(find.text('去支付'), findsNothing);
      expect(find.text('付款状态暂时无法加载'), findsOneWidget);
      final primaryAction = tester.widget<ElevatedButton>(
        find.byKey(const Key('my-home-primary-action')),
      );
      expect(primaryAction.onPressed, isNull);
      await tester.scrollUntilVisible(
        find.byKey(const Key('my-home-documents-card')),
        400,
      );
      final paymentRecordEntry = tester.widget<InkWell>(
        find.ancestor(
          of: find.descendant(
            of: find.byKey(const Key('my-home-documents-card')),
            matching: find.text('付款记录'),
          ),
          matching: find.byType(InkWell),
        ),
      );
      expect(paymentRecordEntry.onTap, isNull);

      paymentRecovers = true;
      await tester.scrollUntilVisible(
        find.byKey(const Key('payment-status-retry')),
        -400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('payment-status-retry')));
      await tester.pumpAndSettle();

      expect(serviceCalls, 2);
      expect(paymentCalls, 3);
      expect(find.text('付款状态暂时无法加载'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const Key('my-home-primary-action')),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('已支付 · 查看记录'), findsOneWidget);
    },
  );

  testWidgets(
    'detail refresh failure clears stale paid and after-sale actions',
    (tester) async {
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
        bookingApi: _EmptyBookingApi(),
      );
      final serviceApi = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [
                  _serviceRequestJson(
                    status: 'WORKER_SELECTED',
                    candidateStatus: 'COMPLETED',
                  ),
                ],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      var listCalls = 0;
      var paymentRecovers = false;
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/payment/orders');
          listCalls++;
          if (listCalls >= 4 && !paymentRecovers) {
            return http.Response.bytes(
              utf8.encode(
                jsonEncode({
                  'code': 'TEMPORARY_FAILURE',
                  'message': '支付服务暂时不可用',
                  'data': null,
                }),
              ),
              503,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            );
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [_paymentOrderJson(status: 'PAID')],
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
            home: Scaffold(
              body: MyHomePage(
                serviceRequestApi: serviceApi,
                paymentApi: paymentApi,
                quoteApi: _emptyQuoteApi(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('查看详情 >').first);
      await tester.pumpAndSettle();
      expect(find.text('已支付 · 查看记录'), findsOneWidget);
      expect(find.text('售后'), findsOneWidget);

      await tester.tap(find.text('已支付 · 查看记录'));
      await tester.pumpAndSettle();
      expect(find.text('支付'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(listCalls, 4);
      expect(find.text('付款状态暂时无法加载'), findsOneWidget);
      expect(find.text('已支付 · 查看记录'), findsNothing);
      expect(find.text('去支付'), findsNothing);
      expect(find.text('售后'), findsNothing);

      paymentRecovers = true;
      await tester.tap(find.byKey(const Key('payment-status-retry')));
      await tester.pumpAndSettle();

      expect(listCalls, 5);
      expect(find.text('付款状态暂时无法加载'), findsNothing);
      expect(find.text('已支付 · 查看记录'), findsOneWidget);
      expect(find.text('售后'), findsOneWidget);
    },
  );

  testWidgets('payment record opens the real latest payment order', (
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
      bookingApi: _EmptyBookingApi(),
    );
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [
                _serviceRequestJson(
                  status: 'WORKER_SELECTED',
                  candidateStatus: 'COMPLETED',
                ),
              ],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final paymentApi = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        final order = _paymentOrderJson(status: 'PAID');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data':
                  request.url.path == '/api/v1/payment/orders/payment-order-1'
                  ? order
                  : [order],
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
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: paymentApi,
              quoteApi: _emptyQuoteApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('my-home-documents-card')),
      400,
    );
    await tester.pumpAndSettle();
    final paymentEntry = find.descendant(
      of: find.byKey(const Key('my-home-documents-card')),
      matching: find.text('付款记录'),
    );
    await tester.ensureVisible(paymentEntry);
    await tester.pumpAndSettle();
    await tester.tap(paymentEntry);
    await tester.pumpAndSettle();

    expect(find.text('支付'), findsOneWidget);
    expect(find.text('已支付'), findsWidgets);
    expect(find.text('付款记录正在接入平台托管流程'), findsNothing);
  });

  testWidgets(
    'completed featured project shows awaiting worker receipt status',
    (tester) async {
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
        bookingApi: _EmptyBookingApi(),
      );
      final serviceApi = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient(
          (request) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [
                  _serviceRequestJson(
                    status: 'WORKER_SELECTED',
                    candidateStatus: 'COMPLETED',
                  ),
                ],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient(
          (request) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [_paymentOrderJson(status: 'OWNER_REPORTED_PAID')],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: MyHomePage(
                serviceRequestApi: serviceApi,
                paymentApi: paymentApi,
                quoteApi: _emptyQuoteApi(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('去支付'), findsNothing);
      expect(find.text('待师傅确认收款'), findsOneWidget);
    },
  );

  testWidgets('split payment awaiting platform review has an honest label', (
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
      bookingApi: _EmptyBookingApi(),
    );
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [
                _serviceRequestJson(
                  status: 'WORKER_SELECTED',
                  candidateStatus: 'COMPLETED',
                ),
              ],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    final paymentApi = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [
                _paymentOrderJson(
                  status: 'UNDER_REVIEW',
                  fundingModel: 'OFFLINE_SPLIT_V2',
                  constructionPaymentStatus: 'CONFIRMED',
                  platformFeeStatus: 'REPORTED',
                ),
              ],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: paymentApi,
              quoteApi: _emptyQuoteApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('平台核验中'), findsOneWidget);
    expect(find.text('去支付'), findsNothing);
  });

  testWidgets('cost card syncs confirmed amount from paid payment orders', (
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
      bookingApi: _EmptyBookingApi(),
    );
    final serviceApi = ServiceRequestApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [_serviceRequestJson(candidateStatus: 'HIRED')],
            }),
          ),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final paymentApi = PaymentApiClient(
      baseUrl: Uri.parse('http://example.test'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/v1/payment/orders');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': [_paymentOrderJson(status: 'PAID')],
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
          home: Scaffold(
            body: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: paymentApi,
              quoteApi: _quoteApiWithFeeSplit(laborFee: 200, auxiliaryFee: 110),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('my-home-cost-card')),
      300,
    );
    await tester.pumpAndSettle();

    expect(find.text('已确认费用'), findsOneWidget);
    expect(find.text('人工费用'), findsOneWidget);
    expect(find.text('辅材费用'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('cost-confirmed-value'))).data,
      '¥310',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('cost-labor-value'))).data,
      '¥200',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('cost-material-value'))).data,
      '¥110',
    );
  });

  testWidgets(
    'shows the current single-trade service without whole-home timeline',
    (tester) async {
      // SKIP: MyHomePage now fetches ServiceRequest list from API.
      // BookedWorker-based legacy UI has been replaced. Test needs rewrite
      // to use mock ServiceRequestApiClient instead of BookedWorker fixtures.
      return;
    },
  );

  testWidgets('opens the current trade service detail', (tester) async {
    // SKIP: Same reason — MyHomePage now fetches ServiceRequest list from API.
    return;
  });

  for (final scenario in const [('OPEN', '继续选师傅'), ('CANCELLED', '重新找师傅')]) {
    testWidgets('${scenario.$1} demand exposes ${scenario.$2}', (tester) async {
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
        bookingApi: _EmptyBookingApi(),
      );
      final serviceApi = ServiceRequestApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'code': 'OK',
                'message': 'success',
                'data': [
                  _serviceRequestJson(
                    status: scenario.$1,
                    candidateStatus: null,
                  ),
                ],
              }),
            ),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: MyHomePage(
              serviceRequestApi: serviceApi,
              paymentApi: _emptyPaymentApi(),
              quoteApi: _emptyQuoteApi(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('水电师傅'));
      await tester.pumpAndSettle();

      expect(find.text(scenario.$2), findsOneWidget);
    });
  }
}

PaymentApiClient _emptyPaymentApi() {
  return PaymentApiClient(
    baseUrl: Uri.parse('http://example.test'),
    httpClient: MockClient((request) async {
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({'code': 'OK', 'message': 'success', 'data': const []}),
        ),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

WorkerQuoteApiClient _quoteApiWithFeeSplit({
  required double laborFee,
  required double auxiliaryFee,
}) {
  return WorkerQuoteApiClient(
    baseUrl: Uri.parse('http://example.test'),
    httpClient: MockClient((request) async {
      expect(request.url.path, '/api/v1/bookings/booking-arrival/quotes');
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': [
              {
                'id': 'quote-1',
                'bookingId': 'booking-arrival',
                'workerUserId': 'worker-1',
                'workerName': 'UI闭环水电师傅',
                'status': 'ACCEPTED',
                'items': [
                  {
                    'name': '泥瓦修补',
                    'quantity': 1,
                    'unit': '项',
                    'unitPrice': laborFee + auxiliaryFee,
                    'subtotal': laborFee + auxiliaryFee,
                    'laborFee': laborFee,
                    'auxiliaryFee': auxiliaryFee,
                    'mainMaterialFee': 0,
                  },
                ],
                'createdAt': '2026-07-30T09:00:00Z',
                'updatedAt': '2026-07-30T10:00:00Z',
              },
            ],
          }),
        ),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

WorkerQuoteApiClient _emptyQuoteApi() {
  return WorkerQuoteApiClient(
    baseUrl: Uri.parse('http://example.test'),
    httpClient: MockClient((request) async {
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({'code': 'OK', 'message': 'success', 'data': const []}),
        ),
        200,
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );
}

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
  ) async => [
    RemoteOwnerBooking(
      id: 'booking-gt',
      ownerUserId: 'owner-user-id',
      serviceRequestId: 'request-not-returned-by-list-api',
      workerUserId: 'worker-gt',
      workerName: 'GT',
      trade: 'plumbing',
      serviceCity: '成都',
      serviceAddress: '测试小区',
      remark: null,
      status: 'PENDING',
      createdAt: DateTime.utc(2026, 7, 18, 8),
      updatedAt: DateTime.utc(2026, 7, 18, 8),
    ),
  ];

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

final class _EmptyBookingApi implements OwnerBookingApi {
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

final class _EmptyInspectionApi implements InspectionApi {
  const _EmptyInspectionApi();

  @override
  Future<List<RemoteInspectionNode>> getNodes(
    String accessToken,
    String bookingId,
  ) async => const [];

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
  ) async => const [];
}

Map<String, dynamic> _serviceRequestJson({
  String id = 'request-arrival',
  String trade = 'plumbing',
  String status = 'COMPARING',
  String? candidateStatus = 'PENDING',
  String bookingId = 'booking-arrival',
  String workerName = 'UI闭环水电师傅',
  String createdAt = '2026-07-18T08:00:00Z',
  String updatedAt = '2026-07-18T08:00:00Z',
  Map<String, dynamic>? houseInfo,
}) => {
  'id': id,
  'ownerUserId': 'owner-user-id',
  'trade': trade,
  'serviceCity': '成都',
  'serviceAddress': '测试小区',
  'remark': null,
  ...?houseInfo,
  'status': status,
  'candidates': candidateStatus == null
      ? []
      : [
          _candidateJson(
            status: candidateStatus,
            serviceRequestId: id,
            trade: trade,
            bookingId: bookingId,
            workerName: workerName,
          ),
        ],
  'createdAt': createdAt,
  'updatedAt': updatedAt,
};

Map<String, dynamic> _candidateJson({
  required String status,
  String serviceRequestId = 'request-arrival',
  String trade = 'plumbing',
  String bookingId = 'booking-arrival',
  String workerName = 'UI闭环水电师傅',
}) => {
  'id': bookingId,
  'serviceRequestId': serviceRequestId,
  'ownerUserId': 'owner-user-id',
  'ownerName': '测试业主',
  'ownerPhone': '13555555555',
  'workerUserId': 'worker-1',
  'workerName': workerName,
  'trade': trade,
  'serviceCity': '成都',
  'serviceAddress': '测试小区',
  'remark': null,
  'status': status,
  'arrivalConfirmedByOwner': status == 'ON_SITE',
  'arrivalConfirmedByWorker': true,
  'proposedTime': '2026-07-30T01:00:00Z',
  'scheduledVisitAt': '2026-07-30T01:00:00Z',
  'onSiteAt': status == 'ON_SITE' ? '2026-07-29T08:38:15Z' : null,
  'actualOnSiteAt': status == 'ON_SITE' ? '2026-07-29T08:38:15Z' : null,
  'createdAt': '2026-07-18T08:00:00Z',
  'updatedAt': '2026-07-18T08:00:00Z',
};

Map<String, dynamic> _remoteQuoteJson({
  required num total,
  String bookingId = 'booking-arrival',
  String status = 'SUBMITTED',
  String updatedAt = '2026-08-08T08:00:00Z',
}) => {
  'id': 'quote-$updatedAt',
  'bookingId': bookingId,
  'workerUserId': 'worker-1',
  'workerName': 'UI闭环水电师傅',
  'status': status,
  'items': [
    {
      'name': '木工施工',
      'quantity': 1,
      'unit': '项',
      'unitPrice': total,
      'subtotal': total,
      'laborFee': total,
      'auxiliaryFee': 0,
      'mainMaterialFee': 0,
    },
  ],
  'createdAt': '2026-08-08T08:00:00Z',
  'updatedAt': updatedAt,
};

Map<String, dynamic> _paymentOrderJson({
  required String status,
  String fundingModel = 'LEGACY_OWNER_RETENTION',
  String constructionPaymentStatus = 'NOT_REPORTED',
  String platformFeeStatus = 'NOT_REPORTED',
}) => {
  'id': 'payment-order-1',
  'bookingId': 'booking-arrival',
  'ownerUserId': 'owner-user-id',
  'workerUserId': 'worker-1',
  'quoteId': 'quote-1',
  'amount': 310,
  'platformFee': 0,
  'workerSettlement': 279,
  'warrantyRetention': 31,
  'fundingModel': fundingModel,
  'quoteAmount': 310,
  'constructionPaymentStatus': constructionPaymentStatus,
  'platformFeeStatus': platformFeeStatus,
  'status': status,
  'paymentMethod': 'OFFLINE',
  'transactionId': null,
  'paidAt': status == 'PAID' ? '2026-07-30T10:00:00Z' : null,
  'ownerReportedPaidAt': '2026-07-30T09:50:00Z',
  'offlinePaymentChannel': '微信转账',
  'paymentReference': 'test-reference',
  'ownerPaymentNote': '已转账',
  'workerConfirmedReceivedAt': status == 'PAID' ? '2026-07-30T10:00:00Z' : null,
  'refundedAt': null,
  'createdAt': '2026-07-30T09:00:00Z',
  'updatedAt': '2026-07-30T10:00:00Z',
};
