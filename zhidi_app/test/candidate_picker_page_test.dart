import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/pages/home/worker/candidate_picker_page.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/services/service_request_api_client.dart';
import 'package:zhidi_app/services/worker_directory_api_client.dart';

void main() {
  final apiBase = Uri.parse('https://api.example.test/root/');

  final sampleWorkers = [
    {
      'userId': 'worker-a',
      'name': '张师傅',
      'primaryTrade': '水电',
      'experienceYears': 8,
      'serviceCity': '成都',
      'bio': '十年水电经验',
      'dailyRate': 350.0,
    },
    {
      'userId': 'worker-b',
      'name': '李师傅',
      'primaryTrade': '水电',
      'experienceYears': 5,
      'serviceCity': '成都',
      'bio': '年轻靠谱',
      'dailyRate': 280.0,
    },
    {
      'userId': 'worker-c',
      'name': '王师傅',
      'primaryTrade': '泥工',
      'experienceYears': 12,
      'serviceCity': '成都',
      'bio': '老泥工',
      'dailyRate': 400.0,
    },
  ];

  MockClient mockDirectoryApi(List<Map<String, dynamic>> workers) {
    return MockClient((request) async {
      return http.Response(
        jsonEncode({'code': 'OK', 'message': 'success', 'data': workers}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  }

  MockClient mockServiceRequestApi({
    required List<String> addedCandidates,
    String? conflictWorkerId,
  }) {
    var candidates = [...addedCandidates];
    return MockClient((request) async {
      final url = request.url.toString();
      if (request.method == 'POST' &&
          url.contains(
            '/api/v1/owners/me/service-requests/request-1/candidates',
          )) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final workerUserId = body['workerUserId'] as String;
        if (workerUserId == conflictWorkerId) {
          return http.Response(
            jsonEncode({
              'code': 'CANDIDATE_ALREADY_EXISTS',
              'message': '该工匠已经是候选',
              'data': null,
            }),
            409,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        candidates.add(workerUserId);
        return http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': {
              'id': 'request-1',
              'ownerUserId': 'owner-1',
              'trade': '水电',
              'serviceCity': '成都',
              'serviceAddress': null,
              'remark': null,
              'status': 'OPEN',
              'candidates': candidates
                  .map(
                    (id) => {
                      'id': 'bk-$id',
                      'serviceRequestId': 'request-1',
                      'ownerUserId': 'owner-1',
                      'ownerName': '业主',
                      'ownerPhone': '13800000000',
                      'workerUserId': id,
                      'workerName': id == 'worker-a' ? '张师傅' : '李师傅',
                      'trade': '水电',
                      'serviceCity': '成都',
                      'serviceAddress': null,
                      'remark': null,
                      'status': 'PENDING',
                      'arrivalConfirmedByOwner': false,
                      'arrivalConfirmedByWorker': false,
                      'createdAt': '2026-07-01T00:00:00Z',
                      'updatedAt': '2026-07-01T00:00:00Z',
                    },
                  )
                  .toList(),
              'createdAt': '2026-07-01T00:00:00Z',
              'updatedAt': '2026-07-01T00:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('not found', 404);
    });
  }

  Widget buildPage({
    List<Map<String, dynamic>>? workers,
    List<String>? initialCandidates,
    String? conflictWorkerId,
  }) {
    return MaterialApp(
      home: CandidatePickerPage(
        requestId: 'request-1',
        accessToken: 'test-token',
        trade: '水电',
        serviceCity: '成都',
        workerDirectoryApi: WorkerDirectoryApiClient(
          baseUrl: apiBase,
          httpClient: mockDirectoryApi(workers ?? sampleWorkers),
        ),
        serviceRequestApi: ServiceRequestApiClient(
          baseUrl: apiBase,
          httpClient: mockServiceRequestApi(
            addedCandidates: initialCandidates ?? [],
            conflictWorkerId: conflictWorkerId,
          ),
        ),
      ),
    );
  }

  testWidgets('shows request header with trade and city', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('水电师傅 · 成都'), findsOneWidget);
    expect(find.textContaining('最多可选 3 位'), findsOneWidget);
    expect(find.text('综合排序'), findsOneWidget);
    expect(find.text('经验优先'), findsOneWidget);
    expect(find.text('资料完整'), findsWidgets);
  });

  testWidgets('shows Chinese label for API trade in request header', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CandidatePickerPage(
          requestId: 'request-1',
          accessToken: 'test-token',
          trade: 'plumbing',
          serviceCity: '成都',
          workerDirectoryApi: WorkerDirectoryApiClient(
            baseUrl: apiBase,
            httpClient: mockDirectoryApi(sampleWorkers),
          ),
          serviceRequestApi: ServiceRequestApiClient(
            baseUrl: apiBase,
            httpClient: mockServiceRequestApi(addedCandidates: []),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('水电师傅 · 成都'), findsOneWidget);
    expect(find.text('plumbing · 成都'), findsNothing);
  });

  testWidgets('worker cards show comparable trust information', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.textContaining('8年经验'), findsOneWidget);
    expect(find.textContaining('成都服务'), findsWidgets);
    expect(find.text('资料完整'), findsWidgets);
    expect(find.textContaining('十年水电经验'), findsOneWidget);
    expect(find.text('查看详情'), findsWidgets);
    expect(find.text('加入候选'), findsWidgets);
    expect(find.text('已认证 · 可预约 · 详情看案例'), findsWidgets);
  });

  testWidgets('experience sort places senior workers first', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    await tester.tap(find.text('经验优先'));
    await tester.pumpAndSettle();

    final zhangTop = tester.getTopLeft(find.text('张师傅'));
    final liTop = tester.getTopLeft(find.text('李师傅'));
    expect(zhangTop.dy, lessThan(liTop.dy));
  });

  testWidgets('filters workers by trade', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    // 张师傅 and 李师傅 (水电) should appear
    expect(find.text('张师傅'), findsOneWidget);
    expect(find.text('李师傅'), findsOneWidget);
    // 王师傅 (泥工) should NOT appear
    expect(find.text('王师傅'), findsNothing);
  });

  testWidgets('add candidate button triggers API call', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    // first add button — tap it
    await tester.tap(find.text('加入候选').first);
    await tester.pumpAndSettle();

    // should show '已选' badge for that worker
    expect(find.text('已选'), findsWidgets);
    // header should update count
    expect(find.text('已选 1 位候选人'), findsOneWidget);
    expect(find.text('完成选择（已选 1/3）'), findsOneWidget);
  });

  testWidgets('tapping a candidate opens the real worker profile', (
    tester,
  ) async {
    final state = await OwnerAppState.memory();
    await tester.pumpWidget(OwnerAppScope(state: state, child: buildPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('张师傅'));
    await tester.pumpAndSettle();

    expect(find.textContaining('十年水电经验'), findsOneWidget);
    expect(find.text('添加为候选'), findsOneWidget);
  });

  testWidgets('complete selection is disabled until a server add succeeds', (
    tester,
  ) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('candidate-complete')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('加入候选').first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('candidate-complete')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('already-candidate server conflict marks worker as selected', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(workers: [sampleWorkers[0]], conflictWorkerId: 'worker-a'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('加入候选'));
    await tester.pumpAndSettle();

    expect(find.text('已选'), findsWidgets);
    expect(find.text('已选 1 位候选人'), findsOneWidget);
    expect(find.text('添加失败: 该工匠已经是候选'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('candidate-complete')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'already added candidate shows check icon',
    (tester) async {
      await tester.pumpWidget(
        buildPage(workers: [sampleWorkers[0]], initialCandidates: ['worker-a']),
      );
      await tester.pumpAndSettle();

      // add button should not appear
      expect(find.text('加入候选'), findsNothing);
      // should show check icon and 已选 badge
      expect(find.text('已选'), findsOneWidget);
    },
    skip:
        true, // CandidatePickerPage no longer accepts initialCandidates — _candidateIds always starts empty
  );
}
