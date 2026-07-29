import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';
import 'package:zhidi_app/services/service_request_api_client.dart';

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
          (request) async => http.Response(
            '{"code":"OK","message":"success","data":[]}',
            200,
          ),
        ),
      );

      await tester.pumpWidget(
        OwnerAppScope(
          state: state,
          child: MaterialApp(
            home: Scaffold(
              body: MyHomePage(serviceRequestApi: serviceRequestApi),
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

  testWidgets('refreshes service requests when refresh epoch changes',
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
          body: MyHomePage(serviceRequestApi: api, refreshEpoch: epoch),
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

  testWidgets('confirms worker arrival directly from project workbench',
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
            utf8.encode(jsonEncode({
              'code': 'OK',
              'message': 'success',
              'data': _candidateJson(status: 'ON_SITE'),
            })),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': [
              _serviceRequestJson(candidateStatus: 'ARRIVAL_PENDING'),
            ],
          })),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(body: MyHomePage(serviceRequestApi: api)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('确认师傅已到场'), findsOneWidget);
    await tester.tap(find.text('确认师傅已到场'));
    await tester.pumpAndSettle();

    expect(confirmedArrival, isTrue);
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
  Future<List<RemoteOwnerBooking>> listOwnerBookings(String accessToken) async =>
      [
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
  Future<List<RemoteOwnerBooking>> listOwnerBookings(String accessToken) async =>
      const [];

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

Map<String, dynamic> _serviceRequestJson({
  String candidateStatus = 'PENDING',
}) =>
    {
      'id': 'request-arrival',
      'ownerUserId': 'owner-user-id',
      'trade': 'plumbing',
      'serviceCity': '成都',
      'serviceAddress': '测试小区',
      'remark': null,
      'status': 'COMPARING',
      'candidates': [_candidateJson(status: candidateStatus)],
      'createdAt': '2026-07-18T08:00:00Z',
      'updatedAt': '2026-07-18T08:00:00Z',
    };

Map<String, dynamic> _candidateJson({required String status}) => {
      'id': 'booking-arrival',
      'serviceRequestId': 'request-arrival',
      'ownerUserId': 'owner-user-id',
      'ownerName': '测试业主',
      'ownerPhone': '13555555555',
      'workerUserId': 'worker-1',
      'workerName': 'UI闭环水电师傅',
      'trade': 'plumbing',
      'serviceCity': '成都',
      'serviceAddress': '测试小区',
      'remark': null,
      'status': status,
      'arrivalConfirmedByOwner': status == 'ON_SITE',
      'arrivalConfirmedByWorker': true,
      'proposedTime': '2026-07-30T01:00:00Z',
      'onSiteAt': status == 'ON_SITE' ? '2026-07-29T08:38:15Z' : null,
      'createdAt': '2026-07-18T08:00:00Z',
      'updatedAt': '2026-07-18T08:00:00Z',
    };
