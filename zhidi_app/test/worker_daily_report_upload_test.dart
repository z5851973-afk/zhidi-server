import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/pages/worker/daily_report_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/daily_report_api_client.dart';

void main() {
  test('uploads every selected report image and preserves URL order', () async {
    final uploadedPaths = <String>[];

    final urls = await uploadDailyReportImages(
      [XFile('/tmp/first.jpg'), XFile('/tmp/second.png')],
      (File file) async {
        uploadedPaths.add(file.path);
        return 'http://api.example.test/uploads/${file.uri.pathSegments.last}';
      },
    );

    expect(uploadedPaths, ['/tmp/first.jpg', '/tmp/second.png']);
    expect(urls, [
      'http://api.example.test/uploads/first.jpg',
      'http://api.example.test/uploads/second.png',
    ]);
  });

  test('does not report success when an image upload fails', () async {
    await expectLater(
      uploadDailyReportImages([
        XFile('/tmp/broken.jpg'),
      ], (_) async => throw const FileSystemException('upload failed')),
      throwsA(isA<FileSystemException>()),
    );
  });

  test(
    'retry uploads only failed report images and keeps successful URLs',
    () async {
      final images = [
        XFile('/tmp/first.jpg'),
        XFile('/tmp/second.jpg'),
        XFile('/tmp/third.jpg'),
      ];
      final attemptedPaths = <String>[];
      var failSecond = true;

      final firstBatch = await uploadPendingDailyReportImages(
        images,
        const {},
        (file) async {
          attemptedPaths.add(file.path);
          if (file.path.endsWith('second.jpg') && failSecond) {
            throw const FileSystemException('upload failed');
          }
          return 'https://cdn.example/${file.uri.pathSegments.last}';
        },
      );

      expect(firstBatch.uploadedUrls.keys, {
        '/tmp/first.jpg',
        '/tmp/third.jpg',
      });
      expect(firstBatch.failedPaths, {'/tmp/second.jpg'});

      failSecond = false;
      final secondBatch = await uploadPendingDailyReportImages(
        images,
        firstBatch.uploadedUrls,
        (file) async {
          attemptedPaths.add(file.path);
          return 'https://cdn.example/${file.uri.pathSegments.last}';
        },
      );

      expect(attemptedPaths, [
        '/tmp/first.jpg',
        '/tmp/second.jpg',
        '/tmp/third.jpg',
        '/tmp/second.jpg',
      ]);
      expect(secondBatch.failedPaths, isEmpty);
      expect(secondBatch.orderedUrls(images), [
        'https://cdn.example/first.jpg',
        'https://cdn.example/second.jpg',
        'https://cdn.example/third.jpg',
      ]);
    },
  );

  testWidgets('completed project report page only shows report history', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: DailyReportPage(
            orderId: 'booking-1',
            readOnly: true,
            api: _FakeDailyReportApi(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.text('施工记录'), findsOneWidget);
    expect(find.text('墙面底漆与面漆已完成'), findsOneWidget);
    expect(find.text('2026-08-01 · 第2版'), findsOneWidget);
    expect(
      find.byKey(const Key('worker-report-photo-report-1-0')),
      findsOneWidget,
    );
    expect(find.text('提交新日报'), findsNothing);
    expect(find.text('提交日报'), findsNothing);
    expect(find.byKey(const Key('add-report-photos')), findsNothing);
  });

  testWidgets('report history exposes load failure and retries', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _FailThenDailyReportApi();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: DailyReportPage(orderId: 'booking-1', readOnly: true, api: api),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('施工记录加载失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);

    await tester.tap(find.text('重试'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('墙面底漆与面漆已完成'), findsOneWidget);
    expect(api.calls, 2);
  });

  testWidgets('report submit keeps successful uploads and retries only failures', (
    tester,
  ) async {
    final temp = Directory(
      '${Directory.systemTemp.path}/daily-report-test-${DateTime.now().microsecondsSinceEpoch}',
    )..createSync();
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final imageBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2nGQAAAAASUVORK5CYII=',
    );
    final images = <XFile>[];
    for (final name in ['first.png', 'second.png', 'third.png']) {
      final file = File('${temp.path}/$name')..writeAsBytesSync(imageBytes);
      images.add(XFile(file.path));
    }
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _RecordingDailyReportApi();
    final attempts = <String>[];
    var failSecond = true;

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: DailyReportPage(
            orderId: 'booking-1',
            api: api,
            pickImages: () async => images,
            uploadImage: (file, accessToken) async {
              expect(accessToken, 'worker-jwt');
              attempts.add(file.path);
              if (file.path.endsWith('second.png') && failSecond) {
                throw const FileSystemException('upload failed');
              }
              return 'https://cdn.example/${file.uri.pathSegments.last}';
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    await tester.enterText(find.byType(TextField).first, '今日木工施工完成');
    await tester.tap(find.byKey(const Key('add-report-photos')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.ensureVisible(find.text('提交日报'));
    await tester.tap(find.text('提交日报'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(api.submissions, isEmpty);
    expect(find.textContaining('1 张照片未上传成功'), findsOneWidget);
    expect(attempts, images.map((image) => image.path).toList());

    failSecond = false;
    await tester.tap(find.text('提交日报'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(attempts.last, images[1].path);
    expect(attempts.length, 4);
    expect(api.submissions.single, [
      'https://cdn.example/first.png',
      'https://cdn.example/second.png',
      'https://cdn.example/third.png',
    ]);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('日报已提交'), findsOneWidget);
  });

  testWidgets(
    'worker account switch during upload never submits with the old token',
    (tester) async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final upload = Completer<String>();
      final api = _RecordingDailyReportApi();
      final uploadTokens = <String>[];

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: DailyReportPage(
              orderId: 'booking-1',
              api: api,
              pickImages: () async => [XFile('/tmp/session-switch.jpg')],
              uploadImage: (_, token) {
                uploadTokens.add(token);
                if (token == 'worker-jwt') return upload.future;
                return Future.value(
                  'https://cdn.example/new-session-switch.jpg',
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      await tester.enterText(find.byType(TextField).first, '旧账号施工日报');
      await tester.tap(find.byKey(const Key('add-report-photos')));
      await tester.pump();
      await tester.tap(find.text('提交日报'));
      await tester.pump();

      await state.logout();
      state.loginWithToken('different-worker-token');
      upload.complete('https://cdn.example/session-switch.jpg');
      await tester.pumpAndSettle();

      expect(api.submissions, isEmpty);
      expect(find.textContaining('登录账号已切换'), findsNothing);

      await tester.enterText(find.byType(TextField).first, '新账号施工日报');
      await tester.tap(find.byKey(const Key('add-report-photos')));
      await tester.pump();
      await tester.tap(find.text('提交日报'));
      await tester.pumpAndSettle();

      expect(api.submissions, [
        ['https://cdn.example/new-session-switch.jpg'],
      ]);
      expect(api.submissionTokens, ['different-worker-token']);
      expect(uploadTokens, ['worker-jwt', 'different-worker-token']);
    },
  );

  testWidgets('old picker result cannot enter a newer booking draft', (
    tester,
  ) async {
    final temp = _testImageDirectory('picker-booking');
    addTearDown(() => temp.deleteSync(recursive: true));
    final staleImage = _writeTestImage(temp, 'stale.png');
    final picker = Completer<List<XFile>>();
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');

    Widget build(String bookingId) => WorkerAppScope(
      state: state,
      child: MaterialApp(
        home: DailyReportPage(
          key: const Key('worker-picker-booking-race'),
          orderId: bookingId,
          api: _RecordingDailyReportApi(),
          pickImages: () => picker.future,
        ),
      ),
    );

    await tester.pumpWidget(build('booking-old'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-report-photos')));
    await tester.pump();

    await tester.pumpWidget(build('booking-new'));
    await tester.pump();
    picker.complete([staleImage]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('remove-report-photo-0')), findsNothing);
  });

  testWidgets('old picker result cannot enter a newer worker session draft', (
    tester,
  ) async {
    final temp = _testImageDirectory('picker-session');
    addTearDown(() => temp.deleteSync(recursive: true));
    final staleImage = _writeTestImage(temp, 'stale.png');
    final picker = Completer<List<XFile>>();
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: DailyReportPage(
            orderId: 'booking-1',
            api: _RecordingDailyReportApi(),
            pickImages: () => picker.future,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-report-photos')));
    await tester.pump();

    await state.logout();
    state.loginWithToken('different-worker-token');
    await tester.pump();
    picker.complete([staleImage]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('remove-report-photo-0')), findsNothing);
  });

  testWidgets(
    'editing selected photos cannot change an in-flight submit batch',
    (tester) async {
      final temp = _testImageDirectory('submit-snapshot');
      addTearDown(() => temp.deleteSync(recursive: true));
      final first = _writeTestImage(temp, 'first.png');
      final second = _writeTestImage(temp, 'second.png');
      final secondUpload = Completer<String>();
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final api = _RecordingDailyReportApi();

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: DailyReportPage(
              orderId: 'booking-1',
              api: api,
              pickImages: () async => [first, second],
              uploadImage: (file, _) {
                if (file.path == second.path) return secondUpload.future;
                return Future.value('https://cdn.example/first.png');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '批次快照日报');
      await tester.tap(find.byKey(const Key('add-report-photos')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('提交日报'));
      await tester.pump();

      await tester.tap(find.byKey(const Key('remove-report-photo-0')));
      await tester.pump();
      secondUpload.complete('https://cdn.example/second.png');
      await tester.pumpAndSettle();

      expect(api.submissions, [
        ['https://cdn.example/first.png', 'https://cdn.example/second.png'],
      ]);
      expect(find.textContaining('提交失败'), findsNothing);
    },
  );

  testWidgets(
    'old upload failure after account switch cannot surface in new session',
    (tester) async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final oldUpload = Completer<String>();
      final api = _RecordingDailyReportApi();

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: DailyReportPage(
              orderId: 'booking-1',
              api: api,
              pickImages: () async => [
                XFile('/tmp/session-upload-failure.jpg'),
              ],
              uploadImage: (_, token) => token == 'worker-jwt'
                  ? oldUpload.future
                  : Future.value('https://cdn.example/new-upload.jpg'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '旧账号施工日报');
      await tester.tap(find.byKey(const Key('add-report-photos')));
      await tester.pump();
      await tester.tap(find.text('提交日报'));
      await tester.pump();

      await state.logout();
      state.loginWithToken('different-worker-token');
      await tester.pump();

      expect(find.text('提交日报'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '新账号施工日报');
      await tester.tap(find.byKey(const Key('add-report-photos')));
      await tester.pump();
      await tester.tap(find.text('提交日报'));
      await tester.pumpAndSettle();

      expect(api.submissionTokens, ['different-worker-token']);
      expect(api.submissions, [
        ['https://cdn.example/new-upload.jpg'],
      ]);

      oldUpload.completeError(
        const FileSystemException('old session upload failed'),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('登录账号已切换'), findsNothing);
      expect(find.textContaining('照片上传失败'), findsNothing);
      expect(find.text('提交日报'), findsOneWidget);
    },
  );

  testWidgets(
    'old POST failure after account switch cannot surface in new session',
    (tester) async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final api = _DeferredOldSubmitDailyReportApi();

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: DailyReportPage(orderId: 'booking-1', api: api),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '旧账号施工日报');
      await tester.tap(find.text('提交日报'));
      await tester.pump();
      expect(api.submissionTokens, ['worker-jwt']);

      await state.logout();
      state.loginWithToken('different-worker-token');
      await tester.pump();

      expect(find.text('提交日报'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, '新账号施工日报');
      await tester.tap(find.text('提交日报'));
      await tester.pumpAndSettle();
      expect(api.submissionTokens, ['worker-jwt', 'different-worker-token']);

      api.oldSubmission.completeError(StateError('old session POST failed'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('提交失败'), findsNothing);
      expect(find.text('提交日报'), findsOneWidget);
    },
  );

  testWidgets('hanging old upload does not block new session submission', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final oldUpload = Completer<String>();
    final api = _RecordingDailyReportApi();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: DailyReportPage(
            orderId: 'booking-1',
            api: api,
            pickImages: () async => [XFile('/tmp/session-hanging.jpg')],
            uploadImage: (_, token) => token == 'worker-jwt'
                ? oldUpload.future
                : Future.value('https://cdn.example/new-session.jpg'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '旧账号施工日报');
    await tester.tap(find.byKey(const Key('add-report-photos')));
    await tester.pump();
    await tester.tap(find.text('提交日报'));
    await tester.pump();

    await state.logout();
    state.loginWithToken('different-worker-token');
    await tester.pump();

    expect(find.text('提交日报'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '新账号施工日报');
    await tester.tap(find.byKey(const Key('add-report-photos')));
    await tester.pump();
    await tester.tap(find.text('提交日报'));
    await tester.pumpAndSettle();

    expect(api.submissionTokens, ['different-worker-token']);
    expect(api.submissions, [
      ['https://cdn.example/new-session.jpg'],
    ]);

    oldUpload.complete('https://cdn.example/old-session.jpg');
    await tester.pumpAndSettle();
    expect(api.submissionTokens, ['different-worker-token']);
  });

  testWidgets('worker account switch clears already loaded report history', (
    tester,
  ) async {
    final oldState = await WorkerAppState.memory();
    oldState.loginWithToken('worker-jwt');
    final newState = await WorkerAppState.memory();
    newState.loginWithToken('different-worker-token');
    final api = _TokenAwareDailyReportApi();

    Widget build(WorkerAppState state) => WorkerAppScope(
      state: state,
      child: MaterialApp(
        home: DailyReportPage(
          key: const Key('persistent-worker-report-page'),
          orderId: 'booking-1',
          readOnly: true,
          api: api,
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
    expect(api.tokens, ['worker-jwt', 'different-worker-token']);
  });

  testWidgets('worker report photo failure provides an actual retry action', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: DailyReportPage(
            orderId: 'booking-1',
            readOnly: true,
            api: _FakeDailyReportApi(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final retry = find.byKey(const Key('retry-worker-report-photo-report-1-0'));
    expect(retry, findsOneWidget);
    expect(
      find.byKey(const Key('worker-report-photo-image-report-1-0-attempt-0')),
      findsOneWidget,
    );

    await tester.tap(retry);
    await tester.pump();

    expect(
      find.byKey(const Key('worker-report-photo-image-report-1-0-attempt-1')),
      findsOneWidget,
    );
  });

  testWidgets(
    'worker resolves a relative report photo against the API origin',
    (tester) async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      const relativePhoto = '/uploads/daily-reports/worker-proof.jpg';

      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: DailyReportPage(
              orderId: 'booking-1',
              readOnly: true,
              api: _FakeDailyReportApi(photos: const [relativePhoto]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final image = tester.widget<Image>(
        find.byKey(const Key('worker-report-photo-image-report-1-0-attempt-0')),
      );
      expect(
        (image.image as NetworkImage).url,
        Uri.parse(
          AuthApiClient.configuredBaseUrl,
        ).resolve(relativePhoto).toString(),
      );
    },
  );

  testWidgets('worker account switch rejects an old report list response', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _DeferredDailyReportApi();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: DailyReportPage(orderId: 'booking-1', readOnly: true, api: api),
        ),
      ),
    );
    await tester.pump();

    await state.logout();
    state.loginWithToken('different-worker-token');
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
    expect(api.tokens, ['worker-jwt', 'different-worker-token']);
  });

  testWidgets('worker report response cannot overwrite a newer booking', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _DeferredByBookingDailyReportApi();

    Widget build(String bookingId) => WorkerAppScope(
      state: state,
      child: MaterialApp(
        home: DailyReportPage(
          key: const Key('changing-worker-report-page'),
          orderId: bookingId,
          readOnly: true,
          api: api,
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
}

final class _FakeDailyReportApi implements DailyReportApi {
  const _FakeDailyReportApi({
    this.photos = const ['https://files.example/report-1.jpg'],
  });

  final List<String> photos;

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) async => [
    RemoteDailyReport(
      id: 'report-1',
      bookingId: bookingId,
      workerUserId: 'worker-1',
      reportDate: '2026-08-01',
      reportRevision: 2,
      content: '墙面底漆与面漆已完成',
      photos: photos,
      createdAt: DateTime.utc(2026, 8, 1),
    ),
  ];

  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String reportDate,
    String content,
    List<String> photos,
  ) => throw StateError('read-only archive must not submit reports');
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
  ) => throw StateError('read-only archive must not submit reports');
}

final class _RecordingDailyReportApi implements DailyReportApi {
  final List<List<String>> submissions = [];
  final List<String> submissionTokens = [];

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) async => const [];

  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String reportDate,
    String content,
    List<String> photos,
  ) async {
    submissionTokens.add(accessToken);
    submissions.add(List.of(photos));
    return RemoteDailyReport(
      id: 'submitted-report',
      bookingId: bookingId,
      workerUserId: 'worker-1',
      reportDate: reportDate,
      content: content,
      photos: photos,
      createdAt: DateTime.utc(2026, 8, 8),
    );
  }
}

final class _DeferredOldSubmitDailyReportApi implements DailyReportApi {
  final oldSubmission = Completer<RemoteDailyReport>();
  final List<String> submissionTokens = [];

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) async => const [];

  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String reportDate,
    String content,
    List<String> photos,
  ) {
    submissionTokens.add(accessToken);
    if (accessToken == 'worker-jwt') return oldSubmission.future;
    return Future.value(
      RemoteDailyReport(
        id: 'new-session-report',
        bookingId: bookingId,
        workerUserId: 'new-worker',
        reportDate: reportDate,
        content: content,
        photos: List.of(photos),
        createdAt: DateTime.utc(2026, 8, 9),
      ),
    );
  }
}

final class _TokenAwareDailyReportApi implements DailyReportApi {
  final List<String> tokens = [];

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) async {
    tokens.add(accessToken);
    final isOld = accessToken == 'worker-jwt';
    return [
      RemoteDailyReport(
        id: isOld ? 'old-report' : 'new-report',
        bookingId: bookingId,
        workerUserId: isOld ? 'old-worker' : 'new-worker',
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
  ) => throw StateError('read-only test must not submit');
}

final class _DeferredDailyReportApi implements DailyReportApi {
  final reports = Completer<List<RemoteDailyReport>>();
  final List<String> tokens = [];

  @override
  Future<List<RemoteDailyReport>> getReportsByBooking(
    String accessToken,
    String bookingId,
  ) {
    tokens.add(accessToken);
    return accessToken == 'worker-jwt'
        ? reports.future
        : Future.value(const []);
  }

  @override
  Future<RemoteDailyReport> submitReport(
    String accessToken,
    String bookingId,
    String reportDate,
    String content,
    List<String> photos,
  ) => throw StateError('read-only load test must not submit');
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
  ) => throw StateError('read-only load test must not submit');
}

Directory _testImageDirectory(String label) => Directory(
  '${Directory.systemTemp.path}/daily-report-$label-${DateTime.now().microsecondsSinceEpoch}',
)..createSync();

XFile _writeTestImage(Directory directory, String name) {
  final file = File('${directory.path}/$name')
    ..writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2nGQAAAAASUVORK5CYII=',
      ),
    );
  return XFile(file.path);
}
