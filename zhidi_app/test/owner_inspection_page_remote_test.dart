import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/design/components.dart';
import 'package:zhidi_app/pages/home/owner_inspection_page.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/inspection_api_client.dart';

void main() {
  testWidgets('owner can inspect only after worker starts inspection', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      api: _FakeInspectionApi(nodes: [_node(status: 'INSPECTING')]),
    );

    expect(find.text('木工验收'), findsOneWidget);
    expect(find.text('待您验收'), findsOneWidget);
    expect(find.text('去验收'), findsOneWidget);
    expect(find.text('申请验收'), findsNothing);
  });

  testWidgets('owner can review worker evidence before making a decision', (
    tester,
  ) async {
    final api = _FakeInspectionApi(
      nodes: [_node(status: 'INSPECTING')],
      timeline: [
        RemoteInspectionTimelineEvent(
          id: 'submission-1',
          nodeId: 'node-INSPECTING',
          version: 1,
          type: 'WORKER_SUBMISSION',
          actorUserId: 'worker-1',
          note: '吊顶龙骨已加固，请验收',
          photos: const [
            'http://example.com/uploads/inspection-evidence/work.jpg',
          ],
          createdAt: DateTime.utc(2026, 8, 6, 8),
        ),
      ],
    );
    await _pumpPage(tester, api: api);

    expect(find.text('查看验收时间线'), findsOneWidget);
    await tester.tap(find.text('查看验收时间线'));
    await tester.pumpAndSettle();

    expect(find.text('吊顶龙骨已加固，请验收'), findsOneWidget);
    expect(find.text('第 1 轮 · 师傅提交'), findsOneWidget);
  });

  testWidgets('inspection conclusion starts empty and FAIL requires comment', (
    tester,
  ) async {
    final api = _FakeInspectionApi(
      nodes: [_node(status: 'INSPECTING')],
      timeline: [_workerSubmission()],
    );
    await _pumpPage(tester, api: api);

    await tester.tap(find.text('去验收'));
    await tester.pumpAndSettle();

    expect(find.text('请选择验收结论'), findsOneWidget);
    expect(_primaryButton(tester, '提交验收').onTap, isNull);

    await tester.tap(find.text('不通过'));
    await tester.pump();
    expect(find.text('整改意见（必填）'), findsOneWidget);
    expect(_primaryButton(tester, '提交验收').onTap, isNull);

    await tester.enterText(find.byType(TextField), '请重新固定吊顶龙骨');
    await tester.pump();
    expect(_primaryButton(tester, '提交验收').onTap, isNotNull);
  });

  testWidgets('owner form loads current worker evidence before PASS', (
    tester,
  ) async {
    final api = _FakeInspectionApi(
      nodes: [_node(status: 'INSPECTING')],
      timeline: [_workerSubmission()],
    );
    await _pumpPage(tester, api: api);

    await tester.tap(find.text('去验收'));
    await tester.pumpAndSettle();

    expect(find.text('本轮师傅提交'), findsOneWidget);
    expect(find.text('吊顶龙骨已加固，请验收'), findsOneWidget);
    expect(find.text('第 1 轮'), findsOneWidget);
    expect(find.text('1 张现场照片'), findsOneWidget);
    expect(find.text('通过'), findsOneWidget);
  });

  testWidgets(
    'photo upload failure prevents inspection and retry preserves evidence',
    (tester) async {
      final api = _FakeInspectionApi(
        nodes: [_node(status: 'INSPECTING')],
        timeline: [_workerSubmission()],
      );
      var uploadAttempts = 0;
      await _pumpPage(
        tester,
        api: api,
        pickImages: () async => [File('/tmp/inspection-owner-proof.jpg')],
        uploadImage: (file, token, nodeId) async {
          expect(token, 'owner-jwt');
          expect(nodeId, 'node-INSPECTING');
          uploadAttempts += 1;
          if (uploadAttempts == 1) throw Exception('上传失败');
          return 'http://example.com/uploads/inspection-evidence/owner-proof.jpg';
        },
      );

      await tester.tap(find.text('去验收'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('通过'));
      await tester.ensureVisible(find.text('添加现场照片'));
      await tester.tap(find.text('添加现场照片'));
      await tester.pump();
      expect(find.text('inspection-owner-proof.jpg'), findsOneWidget);

      await tester.ensureVisible(find.text('提交验收'));
      await tester.tap(find.text('提交验收'));
      await tester.pumpAndSettle();
      expect(api.inspectCalls, 0);
      expect(find.textContaining('上传失败'), findsOneWidget);
      expect(find.text('inspection-owner-proof.jpg'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('提交验收'));
      await tester.tap(find.text('提交验收'));
      await tester.pumpAndSettle();
      expect(api.inspectCalls, 1);
      expect(api.inspectedResult, 'PASS');
      expect(api.inspectedPhotos, [
        'http://example.com/uploads/inspection-evidence/owner-proof.jpg',
      ]);
    },
  );

  testWidgets('owner account switch during upload prevents old-token inspect', (
    tester,
  ) async {
    final store = MemoryAuthSessionStore(_validSession());
    final upload = Completer<String>();
    final api = _FakeInspectionApi(
      nodes: [_node(status: 'INSPECTING')],
      timeline: [_workerSubmission()],
    );
    await _pumpPage(
      tester,
      api: api,
      sessionStore: store,
      pickImages: () async => [File('/tmp/session-switch-owner.jpg')],
      uploadImage: (_, token, nodeId) {
        expect(token, 'owner-jwt');
        expect(nodeId, 'node-INSPECTING');
        return upload.future;
      },
    );
    await tester.tap(find.text('去验收'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('通过'));
    await tester.ensureVisible(find.text('添加现场照片'));
    await tester.tap(find.text('添加现场照片'));
    await tester.pump();
    await tester.ensureVisible(find.text('提交验收'));
    await tester.tap(find.text('提交验收'));
    await tester.pump();

    await store.save(
      _validSession(token: 'different-owner-token', userId: 'owner-2'),
    );
    upload.complete('/uploads/inspection-evidence/old-owner.jpg');
    await tester.pumpAndSettle();

    expect(api.inspectCalls, 0);
    expect(find.textContaining('登录账号已切换'), findsOneWidget);
  });

  testWidgets('owner sees worker-not-started message when no node exists', (
    tester,
  ) async {
    await _pumpPage(tester, api: _FakeInspectionApi(nodes: const []));

    expect(find.text('师傅尚未发起验收'), findsOneWidget);
    expect(find.text('申请验收'), findsNothing);
    expect(find.text('去验收'), findsNothing);
  });

  testWidgets('pending node waits for worker to initiate inspection', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      api: _FakeInspectionApi(nodes: [_node(status: 'PENDING')]),
    );

    expect(find.text('等待师傅发起验收'), findsOneWidget);
    expect(find.text('申请验收'), findsNothing);
    expect(find.text('去验收'), findsNothing);
  });

  testWidgets('failed node waits for worker to rectify and re-submit', (
    tester,
  ) async {
    await _pumpPage(
      tester,
      api: _FakeInspectionApi(nodes: [_node(status: 'FAILED')]),
    );

    expect(find.text('等待师傅整改并重新发起'), findsOneWidget);
    expect(find.text('查看验收记录'), findsOneWidget);
    expect(find.text('去验收'), findsNothing);
  });

  testWidgets('passed node is read-only for owner', (tester) async {
    await _pumpPage(
      tester,
      api: _FakeInspectionApi(nodes: [_node(status: 'PASSED')]),
    );

    expect(find.text('验收已通过'), findsOneWidget);
    expect(find.text('查看验收记录'), findsOneWidget);
    expect(find.text('去验收'), findsNothing);
  });

  testWidgets('passed node opens its remote inspection records', (
    tester,
  ) async {
    final record = RemoteInspectionRecord(
      id: 'record-1',
      nodeId: 'node-PASSED',
      inspectorUserId: 'owner-1',
      result: 'PASS',
      comment: '木工验收合格',
      photos: const [],
      version: 1,
      createdAt: DateTime.utc(2026, 8, 6),
    );
    await _pumpPage(
      tester,
      api: _FakeInspectionApi(
        nodes: [_node(status: 'PASSED')],
        records: [record],
      ),
    );

    await tester.tap(find.text('查看验收记录'));
    await tester.pumpAndSettle();

    expect(find.text('验收记录'), findsOneWidget);
    expect(find.text('第 1 轮 · 业主验收'), findsOneWidget);
    expect(find.text('已通过'), findsOneWidget);
    expect(find.text('PASS'), findsNothing);
    expect(find.text('木工验收合格'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'owner sees ordered worker submission and owner decision timeline',
    (tester) async {
      final api = _FakeInspectionApi(
        nodes: [_node(status: 'FAILED')],
        timeline: [
          RemoteInspectionTimelineEvent(
            id: 'submission-1',
            nodeId: 'node-FAILED',
            version: 1,
            type: 'WORKER_SUBMISSION',
            actorUserId: 'worker-1',
            note: '第一次施工已完成',
            photos: const [
              'http://example.com/uploads/inspection-evidence/work-1.jpg',
            ],
            createdAt: DateTime.utc(2026, 8, 6, 8),
          ),
          RemoteInspectionTimelineEvent(
            id: 'decision-1',
            nodeId: 'node-FAILED',
            version: 1,
            type: 'OWNER_DECISION',
            actorUserId: 'owner-1',
            result: 'FAIL',
            note: '龙骨间距不符合要求',
            photos: const [
              'http://example.com/uploads/inspection-evidence/fail-1.jpg',
            ],
            createdAt: DateTime.utc(2026, 8, 6, 9),
          ),
        ],
      );
      await _pumpPage(tester, api: api);

      await tester.tap(find.text('查看验收记录'));
      await tester.pumpAndSettle();

      expect(find.text('第 1 轮 · 师傅提交'), findsOneWidget);
      expect(find.text('第一次施工已完成'), findsOneWidget);
      expect(find.text('第 1 轮 · 业主验收'), findsOneWidget);
      expect(find.text('龙骨间距不符合要求'), findsOneWidget);
      expect(find.text('整改'), findsOneWidget);
    },
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  _FakeInspectionApi? api,
  Future<List<File>> Function()? pickImages,
  Future<String> Function(File file, String accessToken, String nodeId)?
  uploadImage,
  MemoryAuthSessionStore? sessionStore,
}) async {
  final state = await OwnerAppState.memory(
    sessionStore: sessionStore ?? MemoryAuthSessionStore(_validSession()),
  );
  await tester.pumpWidget(
    OwnerAppScope(
      state: state,
      child: MaterialApp(
        home: OwnerInspectionPage(
          bookingId: 'booking-1',
          api: api ?? _FakeInspectionApi(nodes: const []),
          pickImages: pickImages,
          uploadImage: uploadImage,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 1));
  await tester.pump();
}

ZdPrimaryButton _primaryButton(WidgetTester tester, String label) {
  return tester.widget<ZdPrimaryButton>(
    find.widgetWithText(ZdPrimaryButton, label),
  );
}

RemoteInspectionNode _node({required String status}) => RemoteInspectionNode(
  id: 'node-$status',
  bookingId: 'booking-1',
  name: '木工验收',
  description: '吊顶、柜体结构验收',
  status: status,
  sortOrder: 2,
  createdAt: DateTime.utc(2026, 7, 18),
);

AuthSession _validSession({
  String token = 'owner-jwt',
  String userId = 'owner-1',
}) => AuthSession(
  accessToken: token,
  tokenType: 'Bearer',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  userId: userId,
  phone: '13812345678',
  roles: const ['OWNER'],
);

RemoteInspectionTimelineEvent _workerSubmission() =>
    RemoteInspectionTimelineEvent(
      id: 'submission-1',
      nodeId: 'node-INSPECTING',
      version: 1,
      type: 'WORKER_SUBMISSION',
      actorUserId: 'worker-1',
      note: '吊顶龙骨已加固，请验收',
      photos: const ['/uploads/inspection-evidence/worker-proof.jpg'],
      createdAt: DateTime.utc(2026, 8, 9),
    );

final class _FakeInspectionApi implements InspectionApi, InspectionEvidenceApi {
  _FakeInspectionApi({
    required this.nodes,
    this.records = const [],
    this.timeline = const [],
  });

  final List<RemoteInspectionNode> nodes;
  final List<RemoteInspectionRecord> records;
  final List<RemoteInspectionTimelineEvent> timeline;
  int inspectCalls = 0;
  String? inspectedResult;
  List<String> inspectedPhotos = const [];

  @override
  Future<List<RemoteInspectionNode>> getNodes(
    String accessToken,
    String bookingId,
  ) async {
    expect(accessToken, 'owner-jwt');
    expect(bookingId, 'booking-1');
    return nodes;
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
  ) async {
    inspectCalls += 1;
    inspectedResult = result;
    inspectedPhotos = photos;
    return RemoteInspectionRecord(
      id: 'record-$inspectCalls',
      nodeId: nodeId,
      inspectorUserId: 'owner-1',
      result: result,
      comment: comment,
      photos: photos,
      version: 1,
      createdAt: DateTime.utc(2026, 8, 6),
    );
  }

  @override
  Future<List<RemoteInspectionRecord>> getRecords(
    String accessToken,
    String nodeId,
  ) async {
    expect(accessToken, 'owner-jwt');
    expect(nodeId, 'node-PASSED');
    return records;
  }

  @override
  Future<RemoteInspectionNode> requestInspectionWithEvidence(
    String accessToken,
    String nodeId,
    String? note,
    List<String> photos,
  ) => throw UnimplementedError();

  @override
  Future<List<RemoteInspectionTimelineEvent>> getInspectionTimeline(
    String accessToken,
    String nodeId,
  ) async {
    expect(accessToken, 'owner-jwt');
    if (timeline.isNotEmpty) return timeline;
    return records
        .map(
          (record) => RemoteInspectionTimelineEvent(
            id: record.id,
            nodeId: record.nodeId,
            version: record.version,
            type: 'OWNER_DECISION',
            actorUserId: record.inspectorUserId,
            result: record.result,
            note: record.comment,
            photos: record.photos,
            createdAt: record.createdAt,
          ),
        )
        .toList();
  }
}
