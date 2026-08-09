import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/models/chat_models.dart';
import 'package:zhidi_app/pages/home/home_page.dart';
import 'package:zhidi_app/pages/worker/worker_home_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/business_event_api_client.dart';
import 'package:zhidi_app/services/chat_api_client.dart';
import 'package:zhidi_app/services/owner_booking_api_client.dart';
import 'package:zhidi_app/services/owner_profile_api_client.dart';

void main() {
  test(
    'owner persists each event page with its cursor and resumes after restart',
    () async {
      final store = _RecordingStore();
      final sessions = MemoryAuthSessionStore(_session(role: 'OWNER'));
      final api = _FakeBusinessEventApi({
        0: BusinessEventPage(
          items: [
            _event(1, type: 'DAILY_REPORT_SUBMITTED'),
            _event(2, type: 'INSPECTION_REQUESTED'),
          ],
          nextCursor: 2,
        ),
        2: BusinessEventPage(
          items: [_event(3, type: 'AFTER_SALE_CREATED')],
          nextCursor: 3,
        ),
      });
      final state = await _ownerState(store, sessions);
      store.writes.clear();
      state.initBusinessEventApi(api);

      await state.fetchRemoteBusinessEvents(pageSize: 2);

      expect(api.requestedAfter, [0, 2]);
      expect(state.businessEventCursor, 3);
      expect(
        state.messages.where((message) => message.serverEventId != null),
        hasLength(3),
      );
      expect(state.messages.map((message) => message.serverEventId), [
        'event-3',
        'event-2',
        'event-1',
      ]);
      expect(store.writes, hasLength(2));
      final firstPageDocument = jsonDecode(store.writes.first);
      expect(firstPageDocument['_businessEventCursor'], 2);
      expect(
        (firstPageDocument['messages'] as List).where(
          (value) => value['serverEventId'] != null,
        ),
        hasLength(2),
      );
      final secondPageDocument = jsonDecode(store.writes.last);
      expect(secondPageDocument['_businessEventCursor'], 3);
      expect(
        (secondPageDocument['messages'] as List).where(
          (value) => value['serverEventId'] != null,
        ),
        hasLength(3),
      );

      final restored = await _ownerState(store, sessions);
      expect(restored.businessEventCursor, 3);
      expect(restored.messages.map((message) => message.serverEventId), [
        'event-3',
        'event-2',
        'event-1',
      ]);

      final retryApi = _FakeBusinessEventApi({
        3: BusinessEventPage(
          items: [_event(4, type: 'DAILY_REPORT_SUBMITTED')],
          nextCursor: 4,
        ),
      });
      restored.initBusinessEventApi(retryApi);
      store.failNextWrite = true;
      await expectLater(
        restored.fetchRemoteBusinessEvents(pageSize: 2),
        throwsStateError,
      );
      expect(restored.businessEventCursor, 3);
      expect(
        restored.messages.where(
          (message) => message.serverEventId == 'event-4',
        ),
        isEmpty,
      );
      final persisted =
          jsonDecode(store.getString(OwnerAppState.documentKey)!)
              as Map<String, dynamic>;
      expect(persisted['_businessEventCursor'], 3);
    },
  );

  test(
    'owner rejects a late page and account switch resets event state',
    () async {
      final store = _RecordingStore();
      final sessions = MemoryAuthSessionStore(_session(role: 'OWNER'));
      final state = await _ownerState(store, sessions);
      final result = Completer<BusinessEventPage>();
      final api = _ControlledBusinessEventApi(result);
      state.initBusinessEventApi(api);

      final fetch = state.fetchRemoteBusinessEvents(pageSize: 2);
      await api.waitUntilCalled;
      await state.completeAuthenticatedLogin(_nextOwnerLogin);
      result.complete(
        BusinessEventPage(
          items: [_event(1, type: 'DAILY_REPORT_SUBMITTED')],
          nextCursor: 1,
        ),
      );
      await fetch;

      expect(state.businessEventCursor, 0);
      expect(
        state.messages.where((message) => message.serverEventId != null),
        isEmpty,
      );
    },
  );

  test('owner server read failure never marks the local event read', () async {
    final sessions = MemoryAuthSessionStore(_session(role: 'OWNER'));
    final state = await _ownerState(_RecordingStore(), sessions);
    final api = _FakeBusinessEventApi({
      0: BusinessEventPage(
        items: [_event(1, type: 'INSPECTION_REQUESTED')],
        nextCursor: 1,
      ),
    });
    state.initBusinessEventApi(api);
    await state.fetchRemoteBusinessEvents(pageSize: 2);
    final messageId = state.messages.single.id;

    api.markReadError = StateError('server write failed');
    await expectLater(state.markMessageRead(messageId), throwsStateError);
    expect(state.messages.single.isRead, isFalse);

    api.markReadError = null;
    await state.markMessageRead(messageId);
    expect(api.markedEventIds, ['event-1', 'event-1']);
    expect(state.messages.single.isRead, isTrue);
  });

  test(
    'worker persists pages and logout rejects the old session response',
    () async {
      final store = _RecordingStore();
      final sessions = MemoryAuthSessionStore(_session(role: 'WORKER'));
      final state = await WorkerAppState.memory(
        store: store,
        sessionStore: sessions,
      );
      final api = _FakeBusinessEventApi({
        0: BusinessEventPage(
          items: [
            _event(1, type: 'INSPECTION_RECTIFICATION_REQUIRED'),
            _event(2, type: 'INSPECTION_PASSED'),
          ],
          nextCursor: 2,
        ),
      });
      state.initBusinessEventApi(api);

      await state.fetchRemoteBusinessEvents(pageSize: 2);

      expect(state.businessEventCursor, 2);
      expect(state.messages.map((message) => message.serverEventId), [
        'event-2',
        'event-1',
      ]);
      final persisted = jsonDecode(
        store.getString(WorkerAppState.documentKey)!,
      );
      expect(persisted['_businessEventCursor'], 2);

      final lateResult = Completer<BusinessEventPage>();
      final lateApi = _ControlledBusinessEventApi(lateResult);
      state.initBusinessEventApi(lateApi);
      final lateFetch = state.fetchRemoteBusinessEvents(pageSize: 2);
      await lateApi.waitUntilCalled;
      await state.logout();
      lateResult.complete(
        BusinessEventPage(
          items: [_event(3, type: 'INSPECTION_PASSED')],
          nextCursor: 3,
        ),
      );
      await lateFetch;

      expect(state.businessEventCursor, 0);
      expect(state.messages, isEmpty);
      final afterLogout = jsonDecode(
        store.getString(WorkerAppState.documentKey)!,
      );
      expect(afterLogout['_businessEventCursor'], 0);
    },
  );

  testWidgets('owner foreground polls business events every eight seconds', (
    tester,
  ) async {
    final state = await _ownerState(
      _RecordingStore(),
      MemoryAuthSessionStore(_session(role: 'OWNER')),
    );
    final api = _FakeBusinessEventApi(const {});
    state.initBusinessEventApi(api);

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.requestedAfter, [0]);

    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(api.requestedAfter, [0, 0]);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('worker foreground polls business events every eight seconds', (
    tester,
  ) async {
    final state = await WorkerAppState.memory(
      sessionStore: MemoryAuthSessionStore(_session(role: 'WORKER')),
    );
    final api = _FakeBusinessEventApi(const {});
    state.initBusinessEventApi(api);

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(home: WorkerHomePage(chatApi: _NoopChatApi())),
      ),
    );
    await tester.pumpAndSettle();
    expect(api.requestedAfter, [0]);

    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
    expect(api.requestedAfter, [0, 0]);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<OwnerAppState> _ownerState(
  OwnerKeyValueStore store,
  AuthSessionStore sessions,
) => OwnerAppState.memory(
  store: store,
  sessionStore: sessions,
  profileApi: const _OwnerProfileApiStub(),
  bookingApi: const _OwnerBookingApiStub(),
);

RemoteBusinessEvent _event(int sequenceNo, {required String type}) {
  final aggregateType = type == 'DAILY_REPORT_SUBMITTED'
      ? 'DAILY_REPORT'
      : type.startsWith('INSPECTION_')
      ? 'INSPECTION_NODE'
      : 'AFTER_SALE';
  return RemoteBusinessEvent.fromJson({
    'eventId': 'event-$sequenceNo',
    'sequenceNo': sequenceNo,
    'actorUserId': 'actor-1',
    'eventType': type,
    'aggregateType': aggregateType,
    'aggregateId': 'aggregate-$sequenceNo',
    'bookingId': 'booking-$sequenceNo',
    'serviceRequestId': 'request-$sequenceNo',
    'payload': {'round': sequenceNo, 'revision': sequenceNo},
    'occurredAt': '2026-08-09T0$sequenceNo:00:00Z',
    'readAt': null,
  });
}

final class _FakeBusinessEventApi implements BusinessEventApi {
  _FakeBusinessEventApi(this.pages);

  final Map<int, BusinessEventPage> pages;
  final List<int> requestedAfter = [];
  final List<String> markedEventIds = [];
  Object? markReadError;

  @override
  Future<BusinessEventPage> list(
    String accessToken, {
    required int after,
    int size = 100,
  }) async {
    requestedAfter.add(after);
    return pages[after] ??
        BusinessEventPage(items: const [], nextCursor: after);
  }

  @override
  Future<RemoteBusinessEvent> markRead(
    String accessToken,
    String eventId,
  ) async {
    markedEventIds.add(eventId);
    if (markReadError case final error?) throw error;
    return RemoteBusinessEvent.fromJson({
      'eventId': eventId,
      'sequenceNo': 1,
      'actorUserId': 'actor-1',
      'eventType': 'INSPECTION_REQUESTED',
      'aggregateType': 'INSPECTION_NODE',
      'aggregateId': 'aggregate-1',
      'bookingId': 'booking-1',
      'serviceRequestId': 'request-1',
      'payload': const {},
      'occurredAt': '2026-08-09T01:00:00Z',
      'readAt': '2026-08-09T02:00:00Z',
    });
  }
}

final class _ControlledBusinessEventApi implements BusinessEventApi {
  _ControlledBusinessEventApi(this.result);

  final Completer<BusinessEventPage> result;
  final Completer<void> _called = Completer<void>();
  Future<void> get waitUntilCalled => _called.future;

  @override
  Future<BusinessEventPage> list(
    String accessToken, {
    required int after,
    int size = 100,
  }) {
    if (!_called.isCompleted) _called.complete();
    return result.future;
  }

  @override
  Future<RemoteBusinessEvent> markRead(String accessToken, String eventId) =>
      throw UnimplementedError();
}

final class _NoopChatApi implements ChatApi {
  @override
  Future<List<ChatRoomModel>> getRooms(String accessToken) async => const [];

  @override
  Future<ChatRoomModel> getOrCreateRoom(String accessToken, String bookingId) =>
      throw UnimplementedError();

  @override
  Future<List<ChatMessageModel>> getMessages(
    String accessToken,
    String roomId, {
    int page = 0,
    int size = 30,
  }) async => const [];

  @override
  Future<void> markRoomRead(String accessToken, String roomId) async {}

  @override
  Future<ChatMessageModel> sendMessage(
    String accessToken,
    String roomId, {
    required String content,
    String type = 'TEXT',
    String? imageUrl,
  }) => throw UnimplementedError();
}

final class _RecordingStore implements OwnerKeyValueStore {
  final Map<String, String> _values = {};
  final List<String> writes = [];
  bool failNextWrite = false;

  @override
  String? getString(String key) => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('local persistence failed');
    }
    _values[key] = value;
    writes.add(value);
  }
}

const _nextOwnerLogin = OwnerLoginResponse(
  accessToken: 'next-owner-token',
  tokenType: 'Bearer',
  expiresInSeconds: 3600,
  user: AuthUser(
    id: 'next-owner-id',
    phone: '13800138002',
    status: 'ACTIVE',
    roles: ['OWNER'],
  ),
);

AuthSession _session({required String role}) => AuthSession(
  accessToken: '${role.toLowerCase()}-token',
  tokenType: 'Bearer',
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  userId: '${role.toLowerCase()}-id',
  phone: role == 'OWNER' ? '13800138001' : '13800138003',
  roles: [role],
);

final class _OwnerProfileApiStub implements OwnerProfileApi {
  const _OwnerProfileApiStub();

  @override
  Future<RemoteOwnerProfile> getCurrent(String accessToken) async =>
      const RemoteOwnerProfile(
        userId: 'owner-id',
        phone: '13800138001',
        name: '测试业主',
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
  ) => getCurrent(accessToken);
}

final class _OwnerBookingApiStub implements OwnerBookingApi {
  const _OwnerBookingApiStub();

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
