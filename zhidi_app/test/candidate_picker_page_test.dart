import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zhidi_app/pages/home/worker/candidate_picker_page.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/models/house_info.dart';
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
      'caseCount': 2,
      'hiredCount': 3,
    },
    {
      'userId': 'worker-b',
      'name': '李师傅',
      'primaryTrade': '水电',
      'experienceYears': 5,
      'serviceCity': '成都',
      'bio': '年轻靠谱',
      'dailyRate': 280.0,
      'caseCount': 0,
      'hiredCount': 0,
    },
    {
      'userId': 'worker-c',
      'name': '王师傅',
      'primaryTrade': '泥工',
      'experienceYears': 12,
      'serviceCity': '成都',
      'bio': '老泥工',
      'dailyRate': 400.0,
      'caseCount': 1,
      'hiredCount': 0,
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
    required List<Map<String, dynamic>> ownerRequests,
    String? conflictWorkerId,
    List<String>? lifecycleCalls,
  }) {
    var candidates = [...addedCandidates];
    if (candidates.isEmpty) {
      for (final request in ownerRequests) {
        if (request['id'] != 'request-1') continue;
        for (final raw in request['candidates'] as List<dynamic>) {
          final candidate = raw as Map<String, dynamic>;
          if (!const {
            'REJECTED',
            'CANCELLED',
            'NOT_SELECTED',
            'HIRED',
            'COMPLETED',
          }.contains(candidate['status'])) {
            candidates.add(candidate['workerUserId'] as String);
          }
        }
      }
    }

    Map<String, dynamic> currentRequest() => {
      'id': 'request-1',
      'ownerUserId': 'owner-1',
      'trade': '水电',
      'serviceCity': '成都',
      'serviceAddress': null,
      'remark': null,
      'status': candidates.isEmpty ? 'OPEN' : 'COMPARING',
      'candidates': candidates
          .map(
            (id) => {
              'id': 'booking-request-1-$id',
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
              'canRemove': true,
              'canReplace': true,
              'createdAt': '2026-07-01T00:00:00Z',
              'updatedAt': '2026-07-01T00:00:00Z',
            },
          )
          .toList(),
      'activeCandidateCount': candidates.length,
      'availableCandidateSlots': 3 - candidates.length,
      'canAddCandidates': candidates.length < 3,
      'createdAt': '2026-07-01T00:00:00Z',
      'updatedAt': '2026-07-01T00:00:00Z',
    };

    http.Response okCurrent() => http.Response(
      jsonEncode({
        'code': 'OK',
        'message': 'success',
        'data': currentRequest(),
      }),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

    return MockClient((request) async {
      final url = request.url.toString();
      final path = request.url.path;
      lifecycleCalls?.add('${request.method} $path');
      if (request.method == 'GET' &&
          url.contains('/api/v1/owners/me/service-requests')) {
        return http.Response(
          jsonEncode({
            'code': 'OK',
            'message': 'success',
            'data': ownerRequests,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.method == 'POST' && path.endsWith('/remove')) {
        final bookingId = path.split('/').reversed.elementAt(1);
        candidates.removeWhere(
          (workerId) => 'booking-request-1-$workerId' == bookingId,
        );
        return okCurrent();
      }
      if (request.method == 'POST' && path.endsWith('/replace')) {
        final bookingId = path.split('/').reversed.elementAt(1);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        candidates.removeWhere(
          (workerId) => 'booking-request-1-$workerId' == bookingId,
        );
        candidates.add(body['workerUserId'] as String);
        return okCurrent();
      }
      if (request.method == 'POST' &&
          path == '/api/v1/owners/me/service-requests/request-1/candidates') {
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
        return okCurrent();
      }
      return http.Response('not found', 404);
    });
  }

  Widget buildPage({
    List<Map<String, dynamic>>? workers,
    List<String>? initialCandidates,
    List<Map<String, dynamic>> ownerRequests = const [],
    String? conflictWorkerId,
    List<String>? lifecycleCalls,
    HouseInfo? houseInfo,
  }) {
    return MaterialApp(
      home: CandidatePickerPage(
        requestId: 'request-1',
        accessToken: 'test-token',
        trade: '水电',
        serviceCity: '成都',
        houseInfo: houseInfo,
        workerDirectoryApi: WorkerDirectoryApiClient(
          baseUrl: apiBase,
          httpClient: mockDirectoryApi(workers ?? sampleWorkers),
        ),
        serviceRequestApi: ServiceRequestApiClient(
          baseUrl: apiBase,
          httpClient: mockServiceRequestApi(
            addedCandidates: initialCandidates ?? [],
            ownerRequests: ownerRequests,
            conflictWorkerId: conflictWorkerId,
            lifecycleCalls: lifecycleCalls,
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> candidateFixture({
    required String requestId,
    required String workerUserId,
    required String workerName,
    required String status,
  }) {
    return {
      'id': 'booking-$requestId-$workerUserId',
      'serviceRequestId': requestId,
      'ownerUserId': 'owner-1',
      'ownerName': '业主',
      'ownerPhone': '13800000000',
      'workerUserId': workerUserId,
      'workerName': workerName,
      'trade': '水电',
      'serviceCity': '成都',
      'serviceAddress': null,
      'remark': null,
      'status': status,
      'arrivalConfirmedByOwner': false,
      'arrivalConfirmedByWorker': false,
      'canRemove': const {
        'PENDING',
        'ACCEPTED',
        'VISIT_PROPOSED',
        'VISIT_SCHEDULED',
        'ARRIVAL_PENDING',
      }.contains(status),
      'canReplace': const {
        'PENDING',
        'ACCEPTED',
        'VISIT_PROPOSED',
        'VISIT_SCHEDULED',
        'ARRIVAL_PENDING',
      }.contains(status),
      'createdAt': '2026-07-01T00:00:00Z',
      'updatedAt': '2026-07-01T00:00:00Z',
    };
  }

  Map<String, dynamic> ownerRequestFixture({
    required String requestId,
    required String requestStatus,
    required String candidateStatus,
    List<Map<String, dynamic>>? candidates,
  }) {
    return {
      'id': requestId,
      'ownerUserId': 'owner-1',
      'trade': '水电',
      'serviceCity': '成都',
      'serviceAddress': null,
      'remark': null,
      'status': requestStatus,
      'candidates':
          candidates ??
          [
            candidateFixture(
              requestId: requestId,
              workerUserId: 'worker-a',
              workerName: '张师傅',
              status: candidateStatus,
            ),
          ],
      'activeCandidateCount': candidates?.length ?? 1,
      'availableCandidateSlots': 3 - (candidates?.length ?? 1),
      'canAddCandidates':
          requestStatus == 'OPEN' || requestStatus == 'COMPARING',
      'createdAt': '2026-07-01T00:00:00Z',
      'updatedAt': '2026-07-01T00:00:00Z',
    };
  }

  testWidgets('shows request header with trade and city', (tester) async {
    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();

    expect(find.text('水电师傅 · 成都'), findsOneWidget);
    expect(find.text('房屋信息未填写'), findsOneWidget);
    expect(find.text('可选 2 位师傅，最多加入 3 位候选'), findsOneWidget);
    expect(find.text('综合排序'), findsOneWidget);
    expect(find.text('经验优先'), findsOneWidget);
    expect(find.text('看案例'), findsOneWidget);
    expect(find.text('资料完整'), findsWidgets);
    expect(find.text('可预约'), findsNothing);
  });

  testWidgets('shows the canonical house summary in the request header', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        houseInfo: const HouseInfo(
          areaSqm: 98.5,
          bedroomCount: 3,
          livingRoomCount: 2,
          kitchenCount: 1,
          bathroomCount: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('98.5㎡ · 3室2厅1厨2卫'), findsOneWidget);
    expect(find.text('房屋信息未填写'), findsNothing);
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
            httpClient: mockServiceRequestApi(
              addedCandidates: [],
              ownerRequests: const [],
            ),
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

    expect(find.textContaining('水电师傅 · 8年经验 · 成都'), findsOneWidget);
    expect(find.text('该工种常见服务：水电改造 / 线路排查 / 管道安装'), findsWidgets);
    expect(find.textContaining('简介：十年水电经验'), findsOneWidget);
    expect(find.text('2个案例'), findsOneWidget);
    expect(find.text('3次被选中'), findsOneWidget);
    expect(find.text('0次被选中'), findsOneWidget);
    expect(find.text('暂无案例'), findsOneWidget);
    expect(find.text('资料完整'), findsWidgets);
    expect(find.text('资料已完善'), findsWidgets);
    expect(find.text('查看详情'), findsWidgets);
    expect(find.text('加入候选'), findsWidgets);
    expect(find.text('可预约'), findsNothing);
    expect(find.text('已认证'), findsNothing);
    expect(find.textContaining('擅长：'), findsNothing);
    expect(find.byIcon(Icons.verified_rounded), findsNothing);
  });

  testWidgets(
    'marks a prior completed partner without replacing the add action',
    (tester) async {
      await tester.pumpWidget(
        buildPage(
          workers: [sampleWorkers[0]],
          ownerRequests: [
            ownerRequestFixture(
              requestId: 'request-history-completed',
              requestStatus: 'COMPLETED',
              candidateStatus: 'COMPLETED',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final candidateCard = find.byKey(const Key('candidate-worker-worker-a'));
      expect(candidateCard, findsOneWidget);
      expect(
        find.descendant(of: candidateCard, matching: find.text('已合作')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: candidateCard, matching: find.text('3次被选中')),
        findsOneWidget,
      );
      final addButton = find.descendant(
        of: candidateCard,
        matching: find.widgetWithText(FilledButton, '加入候选'),
      );
      expect(tester.widget<FilledButton>(addButton).onPressed, isNotNull);

      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: candidateCard, matching: find.text('已加入')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'marks qualifying historical booking statuses as prior partners',
    (tester) async {
      for (final status in const ['READY_TO_START', 'HIRED', 'COMPLETED']) {
        await tester.pumpWidget(
          buildPage(
            workers: [sampleWorkers[0]],
            ownerRequests: [
              ownerRequestFixture(
                requestId: 'request-history-$status',
                requestStatus: status,
                candidateStatus: status,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final candidateCard = find.byKey(
          const Key('candidate-worker-worker-a'),
        );
        expect(candidateCard, findsOneWidget, reason: status);
        expect(
          find.descendant(of: candidateCard, matching: find.text('已合作')),
          findsOneWidget,
          reason: status,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets(
    'does not mark pending or rejected history as prior cooperation',
    (tester) async {
      for (final status in const ['PENDING', 'REJECTED']) {
        await tester.pumpWidget(
          buildPage(
            workers: [sampleWorkers[0]],
            ownerRequests: [
              ownerRequestFixture(
                requestId: 'request-history-$status',
                requestStatus: status,
                candidateStatus: status,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final candidateCard = find.byKey(
          const Key('candidate-worker-worker-a'),
        );
        expect(candidateCard, findsOneWidget, reason: status);
        expect(
          find.descendant(of: candidateCard, matching: find.text('已合作')),
          findsNothing,
          reason: status,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets(
    'does not infer prior cooperation from a completed request status',
    (tester) async {
      for (final candidateStatus in const ['PENDING', 'REJECTED']) {
        await tester.pumpWidget(
          buildPage(
            workers: [sampleWorkers[0]],
            ownerRequests: [
              ownerRequestFixture(
                requestId: 'request-completed-$candidateStatus',
                requestStatus: 'COMPLETED',
                candidateStatus: candidateStatus,
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final candidateCard = find.byKey(
          const Key('candidate-worker-worker-a'),
        );
        expect(candidateCard, findsOneWidget, reason: candidateStatus);
        expect(
          find.descendant(of: candidateCard, matching: find.text('已合作')),
          findsNothing,
          reason: candidateStatus,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
  );

  testWidgets('uses the candidate status even when its request remains open', (
    tester,
  ) async {
    for (final candidateStatus in const ['HIRED', 'COMPLETED']) {
      await tester.pumpWidget(
        buildPage(
          workers: [sampleWorkers[0]],
          ownerRequests: [
            ownerRequestFixture(
              requestId: 'request-open-$candidateStatus',
              requestStatus: 'OPEN',
              candidateStatus: candidateStatus,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final candidateCard = find.byKey(const Key('candidate-worker-worker-a'));
      expect(candidateCard, findsOneWidget, reason: candidateStatus);
      expect(
        find.descendant(of: candidateCard, matching: find.text('已合作')),
        findsOneWidget,
        reason: candidateStatus,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets(
    'matches prior cooperation to the worker card by worker user ID',
    (tester) async {
      const requestId = 'request-history-two-workers';
      await tester.pumpWidget(
        buildPage(
          workers: [sampleWorkers[0], sampleWorkers[1]],
          ownerRequests: [
            ownerRequestFixture(
              requestId: requestId,
              requestStatus: 'OPEN',
              candidateStatus: 'PENDING',
              candidates: [
                candidateFixture(
                  requestId: requestId,
                  workerUserId: 'worker-a',
                  workerName: '张师傅',
                  status: 'HIRED',
                ),
                candidateFixture(
                  requestId: requestId,
                  workerUserId: 'worker-b',
                  workerName: '李师傅',
                  status: 'PENDING',
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final workerACard = find.byKey(const Key('candidate-worker-worker-a'));
      final workerBCard = find.byKey(const Key('candidate-worker-worker-b'));
      expect(workerACard, findsOneWidget);
      expect(workerBCard, findsOneWidget);
      expect(
        find.descendant(of: workerACard, matching: find.text('已合作')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: workerBCard, matching: find.text('已合作')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'does not treat the current completed request as prior cooperation',
    (tester) async {
      await tester.pumpWidget(
        buildPage(
          workers: [sampleWorkers[0]],
          ownerRequests: [
            ownerRequestFixture(
              requestId: 'request-1',
              requestStatus: 'COMPLETED',
              candidateStatus: 'COMPLETED',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final candidateCard = find.byKey(const Key('candidate-worker-worker-a'));
      expect(candidateCard, findsOneWidget);
      expect(
        find.descendant(of: candidateCard, matching: find.text('已合作')),
        findsNothing,
      );
    },
  );

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

    // should show selected state for that worker
    expect(find.text('已加入'), findsOneWidget);
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

    expect(find.text('已加入'), findsOneWidget);
    expect(find.text('已选 1 位候选人'), findsOneWidget);
    expect(find.text('添加失败: 该工匠已经是候选'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('candidate-complete')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('hydrates active candidates from the current request', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        workers: [sampleWorkers[0]],
        ownerRequests: [
          ownerRequestFixture(
            requestId: 'request-1',
            requestStatus: 'COMPARING',
            candidateStatus: 'PENDING',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('加入候选'), findsNothing);
    expect(find.text('已加入'), findsOneWidget);
    expect(find.text('移除'), findsOneWidget);
    expect(find.text('更换'), findsOneWidget);
    expect(find.text('完成选择（已选 1/3）'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('candidate-complete')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'shows an explicit reason while no active candidate is selected',
    (tester) async {
      await tester.pumpWidget(buildPage());
      await tester.pumpAndSettle();

      expect(find.text('请先加入至少 1 位候选师傅'), findsOneWidget);
    },
  );

  testWidgets('rejected candidate frees the slot on the same request', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        workers: [sampleWorkers[0], sampleWorkers[1]],
        ownerRequests: [
          ownerRequestFixture(
            requestId: 'request-1',
            requestStatus: 'OPEN',
            candidateStatus: 'REJECTED',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('已加入'), findsNothing);
    expect(find.text('加入候选'), findsNWidgets(2));
  });

  testWidgets('removes a pre-on-site candidate and frees its slot', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      buildPage(
        workers: [sampleWorkers[0]],
        lifecycleCalls: calls,
        ownerRequests: [
          ownerRequestFixture(
            requestId: 'request-1',
            requestStatus: 'COMPARING',
            candidateStatus: 'PENDING',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('移除'));
    await tester.pumpAndSettle();

    expect(find.text('加入候选'), findsOneWidget);
    expect(find.text('请先加入至少 1 位候选师傅'), findsOneWidget);
    expect(calls.where((call) => call.endsWith('/remove')), hasLength(1));
  });

  testWidgets('replaces a candidate with one atomic API request', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      buildPage(
        workers: [sampleWorkers[0], sampleWorkers[1]],
        lifecycleCalls: calls,
        ownerRequests: [
          ownerRequestFixture(
            requestId: 'request-1',
            requestStatus: 'COMPARING',
            candidateStatus: 'PENDING',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('更换'));
    await tester.pumpAndSettle();
    expect(find.textContaining('正在更换 张师傅'), findsOneWidget);
    await tester.ensureVisible(find.text('替换为此师傅'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('替换为此师傅'));
    await tester.pumpAndSettle();

    expect(calls.where((call) => call.endsWith('/replace')), hasLength(1));
    expect(calls.where((call) => call.endsWith('/remove')), isEmpty);
    final workerBCard = find.byKey(const Key('candidate-worker-worker-b'));
    expect(
      find.descendant(of: workerBCard, matching: find.text('已加入')),
      findsOneWidget,
    );
  });
}
