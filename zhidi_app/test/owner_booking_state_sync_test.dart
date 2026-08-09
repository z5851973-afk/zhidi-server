import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/models/house_info.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/inspection_api_client.dart';
import 'package:zhidi_app/services/owner_address_api_client.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';
import 'package:zhidi_app/services/payment_api_client.dart';
import 'package:zhidi_app/services/service_request_api_client.dart';

const _houseInfo = HouseInfo(
  areaSqm: 98.5,
  bedroomCount: 3,
  livingRoomCount: 2,
  kitchenCount: 1,
  bathroomCount: 2,
);

void main() {
  test('owner messages restore legacy JSON without notification metadata', () {
    final message = OwnerMessage.fromJson({
      'id': 'legacy-message',
      'title': '旧消息',
      'content': '旧版本保存的内容',
      'category': '系统',
      'createdAt': '2026-08-08T08:00:00.000Z',
      'isRead': false,
    });

    expect(message.eventType, isNull);
    expect(message.bookingId, isNull);
    expect(message.serviceRequestId, isNull);
    expect(message.paymentOrderId, isNull);
    expect(message.targetAction, isNull);
    expect(message.serverEventId, isNull);
    expect(message.aggregateType, isNull);
    expect(message.aggregateId, isNull);
  });

  test('owner messages persist exact business event identity', () {
    final message = OwnerMessage(
      id: 'business:event-owner-1',
      title: '待验收节点',
      content: '工人已发起验收',
      category: '验收',
      createdAt: DateTime.utc(2026, 8, 9),
      serverEventId: 'event-owner-1',
      aggregateType: 'INSPECTION_NODE',
      aggregateId: 'node-owner-1',
      bookingId: 'booking-owner-1',
    );

    final restored = OwnerMessage.fromJson(message.toJson());

    expect(restored.serverEventId, 'event-owner-1');
    expect(restored.aggregateType, 'INSPECTION_NODE');
    expect(restored.aggregateId, 'node-owner-1');
  });

  test(
    'bookWorker creates remote booking before local booking for server worker',
    () async {
      final sessionStore = MemoryAuthSessionStore(_session());
      final bookingApi = _FakeOwnerBookingApi();
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: sessionStore,
        profileApi: _FakeOwnerProfileApi(),
        addressApi: _StaticOwnerAddressApi([_defaultAddress()]),
        bookingApi: bookingApi,
      );
      bookingApi.tokens.clear();
      bookingApi.requests.clear();

      await state.bookWorker(
        _worker(id: 'remote-worker-user-id'),
        remoteWorkerUserId: 'remote-worker-user-id',
        houseInfo: _houseInfo,
      );

      expect(bookingApi.tokens, ['jwt-token', 'jwt-token']);
      expect(bookingApi.requests, hasLength(1));
      expect(bookingApi.requests.single.workerUserId, 'remote-worker-user-id');
      expect(bookingApi.requests.single.trade, '泥工师傅');
      expect(bookingApi.requests.single.serviceCity, '成都市');
      expect(bookingApi.requests.single.serviceAddress, '四川省成都市武侯区科华路 1 号');
      expect(bookingApi.requests.single.remark, '来自安卓业主端');
      expect(bookingApi.requests.single.houseInfo, _houseInfo);
      final booked = state.bookedWorkers.firstWhere(
        (worker) => worker.id == 'remote-worker-user-id',
      );
      expect(booked.name, '周师傅');
      expect(
        state.appointments.any(
          (appointment) => appointment.workerName == '周师傅',
        ),
        isTrue,
      );
      expect(state.messages.first.title, '预约已提交');
      expect(state.messages.first.content, contains('等待师傅接单'));
    },
  );

  test('bookWorker requires a default service address', () async {
    final bookingApi = _FakeOwnerBookingApi();
    final state = await OwnerAppState.memory(
      store: MemoryOwnerStore(),
      sessionStore: MemoryAuthSessionStore(_session()),
      profileApi: _FakeOwnerProfileApi(),
      bookingApi: bookingApi,
    );
    bookingApi.tokens.clear();
    bookingApi.requests.clear();

    await expectLater(
      state.bookWorker(
        _worker(id: 'remote-worker-user-id'),
        remoteWorkerUserId: 'remote-worker-user-id',
      ),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.code, 'code', 'OWNER_ADDRESS_REQUIRED')
            .having((error) => error.message, 'message', '请先添加上门地址'),
      ),
    );

    expect(bookingApi.requests, isEmpty);
    expect(state.bookedWorkers, isEmpty);
  });

  test('bookWorker requires complete house information', () async {
    final bookingApi = _FakeOwnerBookingApi();
    final state = await OwnerAppState.memory(
      store: MemoryOwnerStore(),
      sessionStore: MemoryAuthSessionStore(_session()),
      profileApi: _FakeOwnerProfileApi(),
      addressApi: _StaticOwnerAddressApi([_defaultAddress()]),
      bookingApi: bookingApi,
    );
    bookingApi.tokens.clear();
    bookingApi.requests.clear();

    await expectLater(
      state.bookWorker(
        _worker(id: 'remote-worker-user-id'),
        remoteWorkerUserId: 'remote-worker-user-id',
      ),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.code,
          'code',
          'HOUSE_INFO_REQUIRED',
        ),
      ),
    );

    expect(bookingApi.requests, isEmpty);
    expect(state.bookedWorkers, isEmpty);
  });

  test(
    'new bookings use a switched default without changing old snapshots',
    () async {
      final bookingApi = _FakeOwnerBookingApi();
      final addressApi = _StaticOwnerAddressApi([
        _defaultAddress(),
        _secondAddress(),
      ]);
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        addressApi: addressApi,
        bookingApi: bookingApi,
      );
      bookingApi.tokens.clear();
      bookingApi.requests.clear();

      await state.bookWorker(
        _worker(id: 'remote-worker-1'),
        remoteWorkerUserId: 'remote-worker-1',
        houseInfo: _houseInfo,
      );
      final oldSnapshot = bookingApi.requests.single;

      await state.setDefaultAddress('address-2');
      await state.bookWorker(
        _worker(id: 'remote-worker-2'),
        remoteWorkerUserId: 'remote-worker-2',
        houseInfo: _houseInfo,
      );

      expect(oldSnapshot.serviceAddress, '四川省成都市武侯区科华路 1 号');
      expect(bookingApi.requests.last.serviceCity, '杭州市');
      expect(bookingApi.requests.last.serviceAddress, '浙江省杭州市西湖区文三路 2 号');
    },
  );

  test('bookWorker rejects a worker without a server identity', () async {
    final bookingApi = _FakeOwnerBookingApi();
    final state = await OwnerAppState.memory(
      store: MemoryOwnerStore(),
      profileApi: _FakeOwnerProfileApi(),
      bookingApi: bookingApi,
    );

    await expectLater(
      state.bookWorker(_worker(id: 'mock-worker-1')),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.code,
          'code',
          'SERVER_WORKER_REQUIRED',
        ),
      ),
    );

    expect(bookingApi.requests, isEmpty);
    expect(state.bookedWorkers, isEmpty);
    expect(state.appointments, isEmpty);
  });

  test(
    'fetchRemoteBookings adds owner message when remote booking is accepted',
    () async {
      final bookingApi = _FakeOwnerBookingApi()
        ..remoteBookings = [
          _remoteOwnerBooking(
            id: 'remote-booking-accepted',
            status: 'PENDING',
            workerName: '模拟器闭环工人',
            trade: 'carpentry',
            address: 'Android Studio 模拟器小区 2 栋 202',
          ),
        ];
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: bookingApi,
      );

      bookingApi.remoteBookings = [
        _remoteOwnerBooking(
          id: 'remote-booking-accepted',
          status: 'ACCEPTED',
          workerName: '模拟器闭环工人',
          trade: 'carpentry',
          address: 'Android Studio 模拟器小区 2 栋 202',
        ),
      ];
      await state.fetchRemoteBookings();
      await state.fetchRemoteBookings();

      expect(
        state.appointments
            .singleWhere(
              (appointment) => appointment.id == 'rm-remote-booking-accepted',
            )
            .status,
        '已确认',
      );
      final feedbackMessages = state.messages.where(
        (message) => message.id == 'owner:ACCEPTED:remote-booking-accepted',
      );
      expect(feedbackMessages, hasLength(1));
      expect(feedbackMessages.single.title, '工人已接单');
      expect(feedbackMessages.single.category, '预约');
      expect(feedbackMessages.single.isRead, isFalse);
      expect(feedbackMessages.single.content, contains('模拟器闭环工人'));
      expect(feedbackMessages.single.eventType, 'ACCEPTED');
      expect(feedbackMessages.single.bookingId, 'remote-booking-accepted');
      expect(feedbackMessages.single.serviceRequestId, 'sr-test-1');
      expect(feedbackMessages.single.targetAction, 'OWNER_BOOKING');
      expect(feedbackMessages.single.content, contains('木工'));
      expect(feedbackMessages.single.content, isNot(contains('carpentry')));
      expect(
        feedbackMessages.single.content,
        contains('Android Studio 模拟器小区 2 栋 202'),
      );
    },
  );

  test(
    'fetchRemoteBookings adds owner message when remote booking is pending',
    () async {
      final bookingApi = _FakeOwnerBookingApi()
        ..remoteBookings = [
          RemoteOwnerBooking(
            id: 'remote-booking-pending',
            ownerUserId: 'owner-user-id',
            serviceRequestId: 'sr-test-1',
            workerUserId: 'worker-user-id',
            workerName: 'GT',
            trade: 'plumbing',
            serviceCity: '成都',
            serviceAddress: 'fghfdg',
            remark: null,
            status: 'PENDING',
            createdAt: DateTime.utc(2026, 7, 18, 12, 51),
            updatedAt: DateTime.utc(2026, 7, 18, 12, 51),
          ),
        ];
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: bookingApi,
      );

      await state.fetchRemoteBookings();
      await state.fetchRemoteBookings();

      expect(
        state.appointments
            .singleWhere(
              (appointment) => appointment.id == 'rm-remote-booking-pending',
            )
            .status,
        '待接单',
      );
      final feedbackMessages = state.messages.where(
        (message) => message.id == 'owner:PENDING:remote-booking-pending',
      );
      expect(feedbackMessages, hasLength(1));
      expect(feedbackMessages.single.title, '预约已提交');
      expect(feedbackMessages.single.category, '预约');
      expect(feedbackMessages.single.isRead, isFalse);
      expect(feedbackMessages.single.content, contains('GT'));
      expect(feedbackMessages.single.content, contains('水电'));
      expect(feedbackMessages.single.content, contains('等待师傅接单'));
      expect(feedbackMessages.single.eventType, 'PENDING');
      expect(feedbackMessages.single.bookingId, 'remote-booking-pending');
      expect(feedbackMessages.single.serviceRequestId, 'sr-test-1');
      expect(feedbackMessages.single.targetAction, 'OWNER_BOOKING');
    },
  );

  test(
    'fetchRemoteBookings adds owner message when worker proposes visit time',
    () async {
      final bookingApi = _FakeOwnerBookingApi()
        ..remoteBookings = [
          _remoteOwnerBooking(
            id: 'remote-booking-visit-proposed',
            status: 'PENDING',
            workerName: 'ren',
            trade: 'painting',
            address: 'chengdu',
          ),
        ];
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: bookingApi,
      );

      bookingApi.remoteBookings = [
        _remoteOwnerBooking(
          id: 'remote-booking-visit-proposed',
          status: 'VISIT_PROPOSED',
          workerName: 'ren',
          trade: 'painting',
          address: 'chengdu',
        ),
      ];
      await state.fetchRemoteBookings();
      await state.fetchRemoteBookings();

      expect(
        state.appointments
            .singleWhere(
              (appointment) =>
                  appointment.id == 'rm-remote-booking-visit-proposed',
            )
            .status,
        '待确认上门时间',
      );
      final visitMessages = state.messages.where(
        (message) =>
            message.id == 'owner:VISIT_PROPOSED:remote-booking-visit-proposed',
      );
      expect(visitMessages, hasLength(1));
      expect(visitMessages.single.title, '待确认上门时间');
      expect(visitMessages.single.category, '预约');
      expect(visitMessages.single.isRead, isFalse);
      expect(visitMessages.single.content, contains('ren'));
      expect(visitMessages.single.content, contains('油漆'));
      expect(visitMessages.single.content, contains('确认上门时间'));
      expect(visitMessages.single.eventType, 'VISIT_PROPOSED');
      expect(visitMessages.single.bookingId, 'remote-booking-visit-proposed');
      expect(visitMessages.single.serviceRequestId, 'sr-test-1');
      expect(visitMessages.single.targetAction, 'OWNER_BOOKING');
    },
  );

  test(
    'pending proposal does not populate appointment scheduled time',
    () async {
      final proposedTime = DateTime.utc(2026, 8, 10, 1, 30);
      final bookingApi = _FakeOwnerBookingApi()
        ..remoteBookings = [
          _remoteOwnerBooking(
            id: 'remote-booking-proposed-time',
            status: 'VISIT_PROPOSED',
            proposedTime: proposedTime,
          ),
        ];
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: bookingApi,
      );

      await state.fetchRemoteBookings();

      final appointment = state.appointments.singleWhere(
        (item) => item.bookingId == 'remote-booking-proposed-time',
      );
      expect(appointment.scheduledVisitAt, isNull);
      expect(appointment.actualOnSiteAt, isNull);
      expect(appointment.visitTime, isEmpty);
    },
  );

  test(
    'owner booking transitions emit one stable message per server event',
    () async {
      final bookingApi = _FakeOwnerBookingApi()
        ..remoteBookings = [
          _remoteOwnerBooking(id: 'booking-main', status: 'PENDING'),
          _remoteOwnerBooking(id: 'booking-not-selected', status: 'PENDING'),
        ];
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: bookingApi,
      );

      final transitions = <(String, String, String)>[
        ('ACCEPTED', 'ACCEPTED', 'OWNER_BOOKING'),
        ('VISIT_PROPOSED', 'VISIT_PROPOSED', 'OWNER_BOOKING'),
        ('VISIT_SCHEDULED', 'VISIT_SCHEDULED', 'OWNER_BOOKING'),
        ('ARRIVAL_PENDING', 'ARRIVAL_PENDING', 'OWNER_BOOKING'),
        ('QUOTE_PENDING', 'QUOTE_SUBMITTED', 'OWNER_QUOTE_COMPARISON'),
        ('HIRED', 'HIRED', 'OWNER_BOOKING'),
      ];
      for (final (status, eventType, targetAction) in transitions) {
        bookingApi.remoteBookings = [
          _remoteOwnerBooking(id: 'booking-main', status: status),
          _remoteOwnerBooking(id: 'booking-not-selected', status: 'PENDING'),
        ];
        await state.fetchRemoteBookings();
        await state.fetchRemoteBookings();

        final messages = state.messages.where(
          (message) => message.id == 'owner:$eventType:booking-main',
        );
        expect(messages, hasLength(1), reason: '$status must be idempotent');
        expect(messages.single.eventType, eventType);
        expect(messages.single.bookingId, 'booking-main');
        expect(messages.single.serviceRequestId, 'sr-test-1');
        expect(messages.single.targetAction, targetAction);
      }

      bookingApi.remoteBookings = [
        _remoteOwnerBooking(id: 'booking-main', status: 'HIRED'),
        _remoteOwnerBooking(id: 'booking-not-selected', status: 'NOT_SELECTED'),
      ];
      await state.fetchRemoteBookings();
      await state.fetchRemoteBookings();

      final notSelected = state.messages.where(
        (message) => message.id == 'owner:NOT_SELECTED:booking-not-selected',
      );
      expect(notSelected, hasLength(1));
      expect(notSelected.single.eventType, 'NOT_SELECTED');
      expect(notSelected.single.targetAction, 'OWNER_BOOKING');
    },
  );

  test(
    'concurrent owner booking refreshes share one server snapshot',
    () async {
      final bookingApi = _FakeOwnerBookingApi()
        ..remoteBookings = [
          _remoteOwnerBooking(id: 'booking-coalesced', status: 'PENDING'),
        ];
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: bookingApi,
      );
      final gate = Completer<List<RemoteOwnerBooking>>();
      bookingApi.nextList = gate;

      final first = state.fetchRemoteBookings();
      final second = state.fetchRemoteBookings();
      await Future<void>.delayed(Duration.zero);
      final callsWhileBlocked = bookingApi.listCalls;
      gate.complete([
        _remoteOwnerBooking(id: 'booking-coalesced', status: 'ACCEPTED'),
      ]);
      await Future.wait([first, second]);

      expect(callsWhileBlocked, 2);
      expect(
        state.messages.where(
          (message) => message.id == 'owner:ACCEPTED:booking-coalesced',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'concurrent owner business refreshes share one server snapshot',
    () async {
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: _FakeOwnerBookingApi(),
      );
      final requestApi = _FakeServiceRequestApi(requests: const []);
      final gate = Completer<List<RemoteServiceRequest>>();
      requestApi.nextList = gate;
      final paymentApi = PaymentApiClient(
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

      final first = state.fetchRemoteBusinessNotifications(
        serviceRequestApi: requestApi,
        inspectionApi: _FakeInspectionApi(nodes: const []),
        paymentApi: paymentApi,
      );
      final second = state.fetchRemoteBusinessNotifications(
        serviceRequestApi: requestApi,
        inspectionApi: _FakeInspectionApi(nodes: const []),
        paymentApi: paymentApi,
      );
      await Future<void>.delayed(Duration.zero);
      final callsWhileBlocked = requestApi.listCalls;
      gate.complete(const []);
      await Future.wait([first, second]);

      expect(callsWhileBlocked, 1);
    },
  );

  test(
    'older explicit request refresh cannot overwrite newer business snapshot',
    () async {
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: _FakeOwnerBookingApi(),
      );
      final oldSnapshot = Completer<List<RemoteServiceRequest>>();
      final requestApi = _FakeServiceRequestApi(requests: const [])
        ..queuedLists.add(oldSnapshot.future)
        ..queuedLists.add(
          Future.value([_remoteServiceRequest(status: 'HIRED')]),
        );
      final paymentApi = PaymentApiClient(
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

      final older = state.fetchRemoteServiceRequests(
        serviceRequestApi: requestApi,
      );
      await Future<void>.delayed(Duration.zero);
      await state.fetchRemoteBusinessNotifications(
        serviceRequestApi: requestApi,
        inspectionApi: _FakeInspectionApi(nodes: const []),
        paymentApi: paymentApi,
      );
      oldSnapshot.complete([_remoteServiceRequest(status: 'PENDING')]);
      await older;

      expect(
        state.remoteServiceRequests.single.candidates.single.status,
        'HIRED',
      );
    },
  );

  test(
    'service-request loading clears when a business refresh supersedes it',
    () async {
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: _FakeOwnerBookingApi(),
      );
      final delayedRequests = Completer<List<RemoteServiceRequest>>();
      final requestApi = _FakeServiceRequestApi(requests: const [])
        ..queuedLists.add(delayedRequests.future)
        ..queuedLists.add(
          Future.value([_remoteServiceRequest(status: 'HIRED')]),
        );
      final paymentApi = PaymentApiClient(
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

      final explicitRefresh = state.fetchRemoteServiceRequests(
        serviceRequestApi: requestApi,
      );
      await Future<void>.delayed(Duration.zero);
      expect(state.isFetchingRemoteServiceRequests, isTrue);

      await state.fetchRemoteBusinessNotifications(
        serviceRequestApi: requestApi,
        inspectionApi: _FakeInspectionApi(nodes: const []),
        paymentApi: paymentApi,
      );
      delayedRequests.complete([_remoteServiceRequest(status: 'PENDING')]);
      await explicitRefresh;

      expect(state.isFetchingRemoteServiceRequests, isFalse);
    },
  );

  test('owner project count includes requests without candidates', () async {
    final state = await OwnerAppState.memory(
      store: MemoryOwnerStore(),
      sessionStore: MemoryAuthSessionStore(_session()),
      profileApi: _FakeOwnerProfileApi(),
      bookingApi: _FakeOwnerBookingApi(),
    );
    final paymentApi = PaymentApiClient(
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

    await state.fetchRemoteBusinessNotifications(
      serviceRequestApi: _FakeServiceRequestApi(
        requests: [
          _remoteServiceRequest(status: 'PENDING', bookingIds: const []),
        ],
      ),
      inspectionApi: _FakeInspectionApi(nodes: const []),
      paymentApi: paymentApi,
    );

    expect(state.remoteProjectCount, 1);
    expect(state.appointments, isEmpty);
  });

  test(
    'service request snapshot persists and a failed refresh keeps the last success',
    () async {
      final store = MemoryOwnerStore();
      final requestApi = _FakeServiceRequestApi(
        requests: [_remoteServiceRequest(status: 'OPEN', bookingIds: const [])],
      );
      final state = await OwnerAppState.memory(
        store: store,
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: _FakeOwnerBookingApi(),
      );

      await state.fetchRemoteServiceRequests(serviceRequestApi: requestApi);
      expect(state.remoteServiceRequests, hasLength(1));
      expect(state.remoteServiceRequests.single.id, 'sr-test-1');
      expect(state.remoteProjectCount, 1);

      final gate = Completer<List<RemoteServiceRequest>>();
      requestApi.nextList = gate;
      final failedRefresh = state.fetchRemoteServiceRequests(
        serviceRequestApi: requestApi,
      );
      gate.completeError(StateError('temporary request feed failure'));
      await failedRefresh;

      expect(state.remoteServiceRequests, hasLength(1));
      expect(state.remoteServiceRequests.single.id, 'sr-test-1');
      expect(state.remoteServiceRequestError, contains('暂时无法加载'));

      final restored = await OwnerAppState.memory(
        store: store,
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: _FakeOwnerBookingApi(),
      );
      expect(restored.remoteServiceRequests, hasLength(1));
      expect(restored.remoteServiceRequests.single.id, 'sr-test-1');
    },
  );

  test(
    'owner business snapshot does not poll the legacy inspection feed',
    () async {
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: _FakeOwnerBookingApi(),
      );
      final requestApi = _FakeServiceRequestApi(
        requests: [
          _remoteServiceRequest(
            status: 'HIRED',
            bookingIds: const ['booking-first', 'booking-second'],
          ),
        ],
      );
      final inspectionApi = _FakeInspectionApi(nodes: const []);
      final paymentApi = PaymentApiClient(
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

      await state.fetchRemoteBusinessNotifications(
        serviceRequestApi: requestApi,
        inspectionApi: inspectionApi,
        paymentApi: paymentApi,
      );

      expect(inspectionApi.bookingCalls, isEmpty);
    },
  );

  test(
    'owner keeps payment snapshots but never fabricates inspection or after-sale events',
    () async {
      final bookingApi = _FakeOwnerBookingApi()
        ..remoteBookings = [
          _remoteOwnerBooking(id: 'booking-business', status: 'HIRED'),
        ];
      final serviceRequestApi = _FakeServiceRequestApi(
        requests: [_remoteServiceRequest(status: 'HIRED')],
      );
      final inspectionApi = _FakeInspectionApi(
        nodes: [
          _remoteInspectionNode(status: 'PENDING'),
          _remoteInspectionNode(
            id: 'unrelated-masonry-node',
            name: '泥瓦验收',
            status: 'FAILED',
          ),
        ],
      );
      var paymentStatus = 'PENDING';
      var constructionStatus = 'NOT_REPORTED';
      String? workerConfirmedReceivedAt;
      var afterSaleStatus = 'OPEN';
      var afterSaleCalls = 0;
      final paymentApi = PaymentApiClient(
        baseUrl: Uri.parse('http://example.test'),
        httpClient: MockClient((request) async {
          final Object data = switch (request.url.path) {
            '/api/v1/payment/orders' => {
              'content': [
                _paymentOrderJson(
                  status: paymentStatus,
                  constructionPaymentStatus: constructionStatus,
                  workerConfirmedReceivedAt: workerConfirmedReceivedAt,
                ),
              ],
            },
            '/api/v1/after-sales' => () {
              afterSaleCalls += 1;
              return [_afterSaleJson(status: afterSaleStatus)];
            }(),
            _ => <Object>[],
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
      final state = await OwnerAppState.memory(
        store: MemoryOwnerStore(),
        sessionStore: MemoryAuthSessionStore(_session()),
        profileApi: _FakeOwnerProfileApi(),
        bookingApi: bookingApi,
      );

      await state.fetchRemoteBusinessNotifications(
        serviceRequestApi: serviceRequestApi,
        inspectionApi: inspectionApi,
        paymentApi: paymentApi,
      );

      inspectionApi.nodes = [
        _remoteInspectionNode(status: 'INSPECTING'),
        _remoteInspectionNode(
          id: 'unrelated-masonry-node',
          name: '泥瓦验收',
          status: 'FAILED',
        ),
      ];
      paymentStatus = 'OWNER_REPORTED_PAID';
      afterSaleStatus = 'RESOLVED';
      await state.fetchRemoteBusinessNotifications(
        serviceRequestApi: serviceRequestApi,
        inspectionApi: inspectionApi,
        paymentApi: paymentApi,
      );
      await state.fetchRemoteBusinessNotifications(
        serviceRequestApi: serviceRequestApi,
        inspectionApi: inspectionApi,
        paymentApi: paymentApi,
      );

      expect(
        state.messages.where(
          (message) =>
              message.id == 'owner:INSPECTION_REQUESTED:booking-business',
        ),
        isEmpty,
      );
      expect(
        state.messages.where(
          (message) => message.id == 'owner:PAYMENT_REPORTED:booking-business',
        ),
        hasLength(1),
      );
      expect(
        state.messages
            .singleWhere(
              (message) =>
                  message.id == 'owner:PAYMENT_REPORTED:booking-business',
            )
            .paymentOrderId,
        'payment-business',
      );
      expect(
        state.messages.where(
          (message) =>
              message.id == 'owner:AFTER_SALE_RESOLVED:booking-business',
        ),
        isEmpty,
      );
      expect(inspectionApi.bookingCalls, isEmpty);
      expect(afterSaleCalls, 0);

      inspectionApi.nodes = [
        _remoteInspectionNode(status: 'FAILED'),
        _remoteInspectionNode(
          id: 'unrelated-masonry-node',
          name: '泥瓦验收',
          status: 'FAILED',
        ),
      ];
      paymentStatus = 'PAID';
      constructionStatus = 'CONFIRMED';
      workerConfirmedReceivedAt = '2026-08-08T10:30:00Z';
      afterSaleStatus = 'RESOLVED';
      await state.fetchRemoteBusinessNotifications(
        serviceRequestApi: serviceRequestApi,
        inspectionApi: inspectionApi,
        paymentApi: paymentApi,
      );
      inspectionApi.nodes = [
        _remoteInspectionNode(status: 'PASSED'),
        _remoteInspectionNode(
          id: 'unrelated-masonry-node',
          name: '泥瓦验收',
          status: 'FAILED',
        ),
      ];
      await state.fetchRemoteBusinessNotifications(
        serviceRequestApi: serviceRequestApi,
        inspectionApi: inspectionApi,
        paymentApi: paymentApi,
      );

      expect(
        state.messages.where(
          (message) => message.id == 'owner:RECEIPT_CONFIRMED:booking-business',
        ),
        hasLength(1),
      );
      for (final legacyEventType in [
        'INSPECTION_RECTIFICATION',
        'INSPECTION_PASSED',
        'AFTER_SALE_RESOLVED',
      ]) {
        expect(
          state.messages.where(
            (message) =>
                message.id == 'owner:$legacyEventType:booking-business',
          ),
          isEmpty,
          reason: legacyEventType,
        );
      }
    },
  );
}

RemoteOwnerBooking _remoteOwnerBooking({
  required String id,
  required String status,
  String workerName = '周师傅',
  String trade = 'carpentry',
  String? address = '四川省成都市武侯区科华路 1 号',
  DateTime? proposedTime,
  DateTime? scheduledVisitAt,
  DateTime? actualOnSiteAt,
}) => RemoteOwnerBooking(
  id: id,
  ownerUserId: 'owner-user-id',
  serviceRequestId: 'sr-test-1',
  workerUserId: 'worker-user-id',
  workerName: workerName,
  trade: trade,
  serviceCity: '成都',
  serviceAddress: address,
  remark: null,
  status: status,
  proposedTime: proposedTime,
  scheduledVisitAt: scheduledVisitAt,
  actualOnSiteAt: actualOnSiteAt,
  createdAt: DateTime.utc(2026, 8, 8, 8),
  updatedAt: DateTime.utc(2026, 8, 8, 9),
);

RemoteServiceRequest _remoteServiceRequest({
  required String status,
  List<String> bookingIds = const ['booking-business'],
}) => RemoteServiceRequest(
  id: 'sr-test-1',
  ownerUserId: 'owner-user-id',
  trade: 'carpentry',
  serviceCity: '成都',
  serviceAddress: '四川省成都市武侯区科华路 1 号',
  remark: null,
  status: 'ACTIVE',
  candidates: [
    for (final bookingId in bookingIds)
      RemoteCandidateBooking(
        id: bookingId,
        serviceRequestId: 'sr-test-1',
        ownerUserId: 'owner-user-id',
        ownerName: '王先生',
        ownerPhone: '13800138000',
        workerUserId: 'worker-user-id',
        workerName: '周师傅',
        trade: 'carpentry',
        serviceCity: '成都',
        serviceAddress: '四川省成都市武侯区科华路 1 号',
        remark: null,
        status: status,
        createdAt: DateTime.utc(2026, 8, 8, 8),
        updatedAt: DateTime.utc(2026, 8, 8, 9),
      ),
  ],
  createdAt: DateTime.utc(2026, 8, 8, 8),
  updatedAt: DateTime.utc(2026, 8, 8, 9),
);

RemoteInspectionNode _remoteInspectionNode({
  required String status,
  String id = 'inspection-node-1',
  String name = '木工验收',
}) => RemoteInspectionNode(
  id: id,
  bookingId: 'booking-business',
  name: name,
  status: status,
  sortOrder: 1,
  createdAt: DateTime.utc(2026, 8, 8, 9),
  updatedAt: DateTime.utc(2026, 8, 8, 10),
);

Map<String, dynamic> _paymentOrderJson({
  required String status,
  required String constructionPaymentStatus,
  String? workerConfirmedReceivedAt,
}) => {
  'id': 'payment-business',
  'bookingId': 'booking-business',
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
  'workerConfirmedReceivedAt': workerConfirmedReceivedAt,
  'createdAt': '2026-08-08T09:00:00Z',
  'updatedAt': '2026-08-08T10:00:00Z',
};

Map<String, dynamic> _afterSaleJson({required String status}) => {
  'id': 'after-sale-1',
  'bookingId': 'booking-business',
  'ownerUserId': 'owner-user-id',
  'type': 'COMPLAINT',
  'reason': '需要平台协助',
  'status': status,
  'createdAt': '2026-08-08T09:00:00Z',
  'updatedAt': '2026-08-08T10:00:00Z',
};

BookedWorker _worker({required String id}) => BookedWorker(
  id: id,
  name: '周师傅',
  trade: '泥工师傅',
  phaseName: '泥工',
  phaseIndex: 3,
  rating: 4.8,
  completedOrders: 20,
  years: 8,
  avatarEmoji: '🧱',
  skills: const ['贴砖'],
);

AuthSession _session() => AuthSession(
  accessToken: 'jwt-token',
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(const Duration(days: 1)),
  userId: 'owner-user-id',
  phone: '13800138000',
  roles: const ['OWNER'],
);

RemoteOwnerAddress _defaultAddress() => RemoteOwnerAddress(
  id: 'address-1',
  recipient: '林先生',
  phone: '13800138201',
  province: '四川省',
  city: '成都市',
  district: '武侯区',
  detail: '科华路 1 号',
  isDefault: true,
  createdAt: DateTime.utc(2026, 8, 2),
  updatedAt: DateTime.utc(2026, 8, 2),
);

RemoteOwnerAddress _secondAddress() => RemoteOwnerAddress(
  id: 'address-2',
  recipient: '林先生',
  phone: '13800138201',
  province: '浙江省',
  city: '杭州市',
  district: '西湖区',
  detail: '文三路 2 号',
  isDefault: false,
  createdAt: DateTime.utc(2026, 8, 2),
  updatedAt: DateTime.utc(2026, 8, 2),
);

final class _StaticOwnerAddressApi implements OwnerAddressApi {
  _StaticOwnerAddressApi(List<RemoteOwnerAddress> values)
    : values = List.of(values);

  List<RemoteOwnerAddress> values;

  @override
  Future<List<RemoteOwnerAddress>> list(String accessToken) async => values;

  @override
  Future<RemoteOwnerAddress> create(
    String accessToken,
    OwnerAddressDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<void> delete(String accessToken, String addressId) =>
      throw UnimplementedError();

  @override
  Future<RemoteOwnerAddress> setDefault(
    String accessToken,
    String addressId,
  ) async {
    values = [
      for (final address in values)
        RemoteOwnerAddress(
          id: address.id,
          recipient: address.recipient,
          phone: address.phone,
          province: address.province,
          city: address.city,
          district: address.district,
          detail: address.detail,
          isDefault: address.id == addressId,
          createdAt: address.createdAt,
          updatedAt: address.updatedAt,
        ),
    ];
    return values.singleWhere((address) => address.id == addressId);
  }

  @override
  Future<RemoteOwnerAddress> update(
    String accessToken,
    String addressId,
    OwnerAddressDraft draft,
  ) => throw UnimplementedError();
}

final class _FakeServiceRequestApi implements ServiceRequestApi {
  _FakeServiceRequestApi({required this.requests});

  List<RemoteServiceRequest> requests;
  Completer<List<RemoteServiceRequest>>? nextList;
  final List<Future<List<RemoteServiceRequest>>> queuedLists = [];
  int listCalls = 0;

  @override
  Future<List<RemoteServiceRequest>> listOwnerRequests(
    String accessToken,
  ) async {
    listCalls += 1;
    if (queuedLists.isNotEmpty) return queuedLists.removeAt(0);
    return nextList?.future ?? requests;
  }

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

final class _FakeInspectionApi implements InspectionApi {
  _FakeInspectionApi({required this.nodes});

  List<RemoteInspectionNode> nodes;
  Completer<List<RemoteInspectionNode>>? nextGet;
  final bookingCalls = <String>[];

  @override
  Future<List<RemoteInspectionNode>> getNodes(
    String accessToken,
    String bookingId,
  ) async {
    bookingCalls.add(bookingId);
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

final class _FakeOwnerBookingApi implements OwnerBookingApi {
  final tokens = <String>[];
  final requests = <OwnerBookingCreateRequest>[];
  List<RemoteOwnerBooking> remoteBookings = const [];
  Completer<List<RemoteOwnerBooking>>? nextList;
  int listCalls = 0;

  @override
  Future<RemoteOwnerBooking> createBooking(
    String accessToken,
    OwnerBookingCreateRequest request,
  ) async {
    tokens.add(accessToken);
    requests.add(request);
    final booking = RemoteOwnerBooking(
      id: 'booking-1',
      ownerUserId: 'owner-user-id',
      workerUserId: request.workerUserId,
      workerName: '周师傅',
      trade: request.trade ?? '泥工师傅',
      serviceCity: request.serviceCity ?? '杭州',
      serviceAddress: request.serviceAddress,
      remark: request.remark,
      houseInfo: request.houseInfo,
      status: 'PENDING',
      serviceRequestId: 'sr-test-1',
      createdAt: DateTime.utc(2026, 7, 15, 10),
      updatedAt: DateTime.utc(2026, 7, 15, 10),
    );
    remoteBookings = [booking, ...remoteBookings];
    return booking;
  }

  @override
  Future<List<RemoteOwnerBooking>> listOwnerBookings(String accessToken) async {
    tokens.add(accessToken);
    listCalls += 1;
    return nextList?.future ?? remoteBookings;
  }

  @override
  Future<RemoteOwnerBooking> cancelBooking(
    String accessToken,
    String bookingId,
    String reason,
  ) async {
    tokens.add(accessToken);
    return RemoteOwnerBooking(
      id: bookingId,
      ownerUserId: 'owner-user-id',
      workerUserId: 'worker-1',
      workerName: '周师傅',
      trade: '泥工师傅',
      serviceCity: '杭州',
      serviceAddress: null,
      remark: null,
      serviceRequestId: 'sr-test-1',
      cancelledBy: null,
      cancelReason: null,
      cancelledAt: null,
      status: 'CANCELLED',
      createdAt: DateTime.utc(2026, 7, 15, 10),
      updatedAt: DateTime.utc(2026, 7, 15, 11),
    );
  }
}

final class _FakeOwnerProfileApi implements OwnerProfileApi {
  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async =>
      const RemoteOwnerProfile(
        userId: 'owner-user-id',
        phone: '13800138000',
        name: '王先生',
        city: '成都',
        decorationType: '旧房翻新',
        address: '杭州市西湖区测试路 1 号',
        area: 88,
        profileComplete: true,
      );

  @override
  Future<RemoteOwnerProfile> updateCurrent(
    String accessToken,
    OwnerProfileUpdate request,
  ) async => RemoteOwnerProfile(
    userId: 'owner-user-id',
    phone: '13800138000',
    name: request.name,
    city: request.city,
    decorationType: request.decorationType,
    address: request.address,
    area: request.area,
    profileComplete: true,
  );
}
