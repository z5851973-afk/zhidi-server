import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/daily_report_api_client.dart';

void main() {
  testWidgets('owner daily report section loads remote reports', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(_validSession()),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: DailyReportSection(
              bookingId: 'booking-1',
              workerName: '张师傅',
              api: _FakeDailyReportApi(),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.text('施工日报'), findsOneWidget);
    expect(find.text('2026-07-18 · 第2版'), findsOneWidget);
    expect(
      find.text('onsite precheck done, prepare carpentry work'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('owner-report-photo-report-1-0')),
      findsOneWidget,
    );
  });

  testWidgets('owner daily report section exposes load failure and retries', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(_validSession()),
    );
    final api = _FailThenDailyReportApi();

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: DailyReportSection(
              bookingId: 'booking-1',
              workerName: '张师傅',
              api: api,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('施工日报加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(
      find.text('onsite precheck done, prepare carpentry work'),
      findsOneWidget,
    );
    expect(api.calls, 2);
  });

  testWidgets('owner logout rejects an old report list response', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(_validSession()),
    );
    final api = _DeferredDailyReportApi();

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: DailyReportSection(
              bookingId: 'booking-1',
              workerName: '张师傅',
              api: api,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await state.logout();
    api.reports.complete([
      RemoteDailyReport(
        id: 'old-report',
        bookingId: 'booking-1',
        workerUserId: 'old-worker',
        reportDate: '2026-08-09',
        content: '旧账号施工日报',
        photos: const [],
        createdAt: DateTime.utc(2026, 8, 9),
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('旧账号施工日报'), findsNothing);
    expect(find.textContaining('登录已过期'), findsOneWidget);
  });

  testWidgets('owner account switch clears already loaded report history', (
    tester,
  ) async {
    final oldState = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(_validSession()),
    );
    final newState = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(
        _validSession(
          accessToken: 'owner-jwt-2',
          userId: 'owner-2',
          phone: '13900000002',
        ),
      ),
    );
    final api = _TokenAwareDailyReportApi();

    Widget build(OwnerAppState state) => OwnerAppScope(
      state: state,
      child: MaterialApp(
        home: Scaffold(
          body: DailyReportSection(
            key: const Key('persistent-owner-report-section'),
            bookingId: 'booking-1',
            api: api,
          ),
        ),
      ),
    );

    await tester.pumpWidget(build(oldState));
    await tester.pumpAndSettle();
    expect(find.text('旧账号施工日报'), findsOneWidget);

    await tester.pumpWidget(build(newState));
    await tester.pumpAndSettle();

    expect(find.text('旧账号施工日报'), findsNothing);
    expect(find.text('新账号施工日报'), findsOneWidget);
    expect(api.tokens, ['owner-jwt', 'owner-jwt-2']);
  });

  testWidgets('owner report response cannot overwrite a newer booking', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(_validSession()),
    );
    final api = _DeferredByBookingDailyReportApi();

    Widget build(String bookingId) => OwnerAppScope(
      state: state,
      child: MaterialApp(
        home: Scaffold(
          body: DailyReportSection(
            key: const Key('changing-owner-report-section'),
            bookingId: bookingId,
            api: api,
          ),
        ),
      ),
    );

    await tester.pumpWidget(build('booking-old'));
    await tester.pump();
    await tester.pumpWidget(build('booking-new'));
    await tester.pump();

    api.complete('booking-new', '新工地施工日报');
    await tester.pumpAndSettle();
    expect(find.text('新工地施工日报'), findsOneWidget);

    api.complete('booking-old', '旧工地施工日报');
    await tester.pumpAndSettle();

    expect(find.text('新工地施工日报'), findsOneWidget);
    expect(find.text('旧工地施工日报'), findsNothing);
  });

  testWidgets(
    'owner account switch during token recheck cannot restore old reports',
    (tester) async {
      final oldStore = _DeferredReadAuthSessionStore(_validSession());
      final oldState = await OwnerAppState.memory(sessionStore: oldStore);
      final newState = await OwnerAppState.memory(
        sessionStore: MemoryAuthSessionStore(
          _validSession(
            accessToken: 'owner-jwt-2',
            userId: 'owner-2',
            phone: '13900000002',
          ),
        ),
      );
      final api = _DeferredOldTokenDailyReportApi();

      Widget build(OwnerAppState state) => OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: DailyReportSection(
              key: const Key('owner-report-token-race'),
              bookingId: 'booking-1',
              api: api,
            ),
          ),
        ),
      );

      await tester.pumpWidget(build(oldState));
      await tester.pump();
      oldStore.deferNextRead();
      api.completeOld();
      await tester.pump();
      expect(oldStore.hasDeferredRead, isTrue);

      await tester.pumpWidget(build(newState));
      await tester.pumpAndSettle();
      expect(find.text('新账号施工日报'), findsOneWidget);

      oldStore.completeDeferredRead(_validSession());
      await tester.pumpAndSettle();

      expect(find.text('新账号施工日报'), findsOneWidget);
      expect(find.text('旧账号施工日报'), findsNothing);
    },
  );

  testWidgets(
    'owner booking switch during initial token read cannot show stale expiry',
    (tester) async {
      final store = _DeferredReadAuthSessionStore(_validSession());
      final state = await OwnerAppState.memory(sessionStore: store);
      final api = _ImmediateByBookingDailyReportApi();

      Widget build(String bookingId) => OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: DailyReportSection(
              key: const Key('owner-report-initial-token-race'),
              bookingId: bookingId,
              api: api,
            ),
          ),
        ),
      );

      store.deferNextRead();
      await tester.pumpWidget(build('booking-old'));
      await tester.pump();
      expect(store.hasDeferredRead, isTrue);

      await tester.pumpWidget(build('booking-new'));
      await tester.pumpAndSettle();
      expect(find.text('新工地施工日报'), findsOneWidget);

      store.completeDeferredRead(null);
      await tester.pumpAndSettle();

      expect(find.text('新工地施工日报'), findsOneWidget);
      expect(find.textContaining('登录已过期'), findsNothing);
    },
  );

  testWidgets(
    'owner booking switch during catch token read cannot show stale error',
    (tester) async {
      final store = _DeferredReadAuthSessionStore(_validSession());
      final state = await OwnerAppState.memory(sessionStore: store);
      final api = _DeferredFailureByBookingDailyReportApi();

      Widget build(String bookingId) => OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: DailyReportSection(
              key: const Key('owner-report-catch-token-race'),
              bookingId: bookingId,
              api: api,
            ),
          ),
        ),
      );

      await tester.pumpWidget(build('booking-old'));
      await tester.pump();
      store.deferNextRead();
      api.failOld();
      await tester.pump();
      expect(store.hasDeferredRead, isTrue);

      await tester.pumpWidget(build('booking-new'));
      await tester.pumpAndSettle();
      expect(find.text('新工地施工日报'), findsOneWidget);

      store.completeDeferredRead(_validSession());
      await tester.pumpAndSettle();

      expect(find.text('新工地施工日报'), findsOneWidget);
      expect(find.text('施工日报加载失败'), findsNothing);
    },
  );

  testWidgets('owner report photo failure provides an actual retry action', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(_validSession()),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: DailyReportSection(
              bookingId: 'booking-1',
              api: _FakeDailyReportApi(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final retry = find.byKey(const Key('retry-owner-report-photo-report-1-0'));
    expect(retry, findsOneWidget);
    expect(
      find.byKey(const Key('owner-report-photo-image-report-1-0-attempt-0')),
      findsOneWidget,
    );

    await tester.tap(retry);
    await tester.pump();

    expect(
      find.byKey(const Key('owner-report-photo-image-report-1-0-attempt-1')),
      findsOneWidget,
    );
  });

  testWidgets('owner resolves a relative report photo against the API origin', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(_validSession()),
    );
    const relativePhoto = '/uploads/daily-reports/owner-proof.jpg';

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: Scaffold(
            body: DailyReportSection(
              bookingId: 'booking-1',
              api: _FakeDailyReportApi(photos: const [relativePhoto]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final image = tester.widget<Image>(
      find.byKey(const Key('owner-report-photo-image-report-1-0-attempt-0')),
    );
    expect(
      (image.image as NetworkImage).url,
      Uri.parse(
        AuthApiClient.configuredBaseUrl,
      ).resolve(relativePhoto).toString(),
    );
  });
}

AuthSession _validSession({
  String accessToken = 'owner-jwt',
  String userId = 'owner-1',
  String phone = '13812345678',
}) => AuthSession(
  accessToken: accessToken,
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  userId: userId,
  phone: phone,
  roles: const ['OWNER'],
);

final class _FakeDailyReportApi implements DailyReportApi {
  const _FakeDailyReportApi({
    this.photos = const ['https://files.example/report-1.jpg'],
  });

  final List<String> photos;

  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String reportDate,
    String content,
    List<String> photos,
  ) => throw UnimplementedError();

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) async {
    expect(accessToken, 'owner-jwt');
    expect(bookingId, 'booking-1');
    return [
      RemoteDailyReport(
        id: 'report-1',
        bookingId: bookingId,
        workerUserId: 'worker-1',
        reportDate: '2026-07-18',
        reportRevision: 2,
        content: 'onsite precheck done, prepare carpentry work',
        photos: photos,
        createdAt: DateTime.utc(2026, 7, 18),
      ),
    ];
  }
}

final class _FailThenDailyReportApi implements DailyReportApi {
  int calls = 0;

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) async {
    calls += 1;
    if (calls == 1) throw StateError('temporary report failure');
    return _FakeDailyReportApi().getReportsByBooking(accessToken, bookingId);
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

final class _DeferredDailyReportApi implements DailyReportApi {
  final reports = Completer<List<RemoteDailyReport>>();

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) {
    expect(accessToken, 'owner-jwt');
    return reports.future;
  }

  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String reportDate,
    String content,
    List<String> photos,
  ) => throw StateError('owner report view must not submit');
}

final class _TokenAwareDailyReportApi implements DailyReportApi {
  final List<String> tokens = [];

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) async {
    tokens.add(accessToken);
    final isOld = accessToken == 'owner-jwt';
    return [
      RemoteDailyReport(
        id: isOld ? 'old-report' : 'new-report',
        bookingId: bookingId,
        workerUserId: 'worker-1',
        reportDate: '2026-08-09',
        content: isOld ? '旧账号施工日报' : '新账号施工日报',
        photos: const [],
        createdAt: DateTime.utc(2026, 8, 9),
      ),
    ];
  }

  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String reportDate,
    String content,
    List<String> photos,
  ) => throw StateError('owner report view must not submit');
}

final class _DeferredByBookingDailyReportApi implements DailyReportApi {
  final Map<String, Completer<List<RemoteDailyReport>>> _requests = {};

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) => (_requests[bookingId] ??= Completer<List<RemoteDailyReport>>()).future;

  void complete(String bookingId, String content) {
    _requests[bookingId]!.complete([
      RemoteDailyReport(
        id: 'report-$bookingId',
        bookingId: bookingId,
        workerUserId: 'worker-1',
        reportDate: '2026-08-09',
        content: content,
        photos: const [],
        createdAt: DateTime.utc(2026, 8, 9),
      ),
    ]);
  }

  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String reportDate,
    String content,
    List<String> photos,
  ) => throw StateError('owner report view must not submit');
}

final class _DeferredOldTokenDailyReportApi implements DailyReportApi {
  final _oldReports = Completer<List<RemoteDailyReport>>();

  void completeOld() => _oldReports.complete([
    _report(content: '旧账号施工日报', bookingId: 'booking-1'),
  ]);

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) {
    if (accessToken == 'owner-jwt') return _oldReports.future;
    return Future.value([_report(content: '新账号施工日报', bookingId: bookingId)]);
  }

  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String reportDate,
    String content,
    List<String> photos,
  ) => throw StateError('owner report view must not submit');
}

final class _ImmediateByBookingDailyReportApi implements DailyReportApi {
  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) async => [
    _report(
      content: bookingId == 'booking-new' ? '新工地施工日报' : '旧工地施工日报',
      bookingId: bookingId,
    ),
  ];

  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String reportDate,
    String content,
    List<String> photos,
  ) => throw StateError('owner report view must not submit');
}

final class _DeferredFailureByBookingDailyReportApi implements DailyReportApi {
  final _oldReports = Completer<List<RemoteDailyReport>>();

  void failOld() => _oldReports.completeError(StateError('old booking failed'));

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) {
    if (bookingId == 'booking-old') return _oldReports.future;
    return Future.value([_report(content: '新工地施工日报', bookingId: bookingId)]);
  }

  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String reportDate,
    String content,
    List<String> photos,
  ) => throw StateError('owner report view must not submit');
}

final class _DeferredReadAuthSessionStore implements AuthSessionStore {
  _DeferredReadAuthSessionStore(this._session);

  AuthSession? _session;
  Completer<AuthSession?>? _nextRead;
  Completer<AuthSession?>? _deferredRead;

  bool get hasDeferredRead => _deferredRead != null;

  void deferNextRead() {
    _nextRead = Completer<AuthSession?>();
  }

  void completeDeferredRead(AuthSession? session) {
    final deferred = _deferredRead;
    if (deferred == null) throw StateError('no deferred session read');
    _deferredRead = null;
    deferred.complete(session);
  }

  @override
  Future<AuthSession?> read() {
    final deferred = _nextRead;
    if (deferred == null) return Future.value(_session);
    _nextRead = null;
    _deferredRead = deferred;
    return deferred.future;
  }

  @override
  Future<void> save(AuthSession session) async {
    _session = session;
  }

  @override
  Future<void> clear() async {
    _session = null;
  }
}

RemoteDailyReport _report({
  required String content,
  required String bookingId,
  List<String> photos = const [],
}) => RemoteDailyReport(
  id: 'report-$bookingId-$content',
  bookingId: bookingId,
  workerUserId: 'worker-1',
  reportDate: '2026-08-09',
  content: content,
  photos: photos,
  createdAt: DateTime.utc(2026, 8, 9),
);
