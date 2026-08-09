import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/design/components.dart';
import 'package:zhidi_app/pages/worker/inspection_page.dart';
import 'package:zhidi_app/services/inspection_api_client.dart';

void main() {
  testWidgets('worker inspection page creates only the order trade node', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _FakeInspectionApi();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: InspectionPage(
            orderId: 'booking-1',
            tradeLabel: '水电',
            api: api,
            pickImages: () async => [File('/tmp/inspection-worker-proof.jpg')],
            uploadImage: (file, token, nodeId) async {
              expect(token, 'worker-jwt');
              expect(nodeId, 'node-1');
              return 'http://example.com/uploads/inspection-evidence/worker-proof.jpg';
            },
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(api.createdBookingId, 'booking-1');
    expect(api.createdNodes, hasLength(1));
    expect(api.createdNodes.single['name'], '水电验收');
    expect(find.text('水电验收'), findsOneWidget);
    expect(find.text('木工验收'), findsNothing);
    expect(find.text('油漆验收'), findsNothing);
    expect(find.text('申请验收'), findsOneWidget);

    await tester.tap(find.text('申请验收'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ZdPrimaryButton, '提交验收申请'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '水电施工已完成，请验收');
    await tester.tap(find.text('添加现场照片'));
    await tester.pump();
    expect(find.text('inspection-worker-proof.jpg'), findsOneWidget);
    await tester.tap(find.widgetWithText(ZdPrimaryButton, '提交验收申请'));
    await tester.pumpAndSettle();
    expect(api.requestedNodeId, 'node-1');
    expect(api.requestedNote, '水电施工已完成，请验收');
    expect(api.requestedPhotos, [
      'http://example.com/uploads/inspection-evidence/worker-proof.jpg',
    ]);
  });

  testWidgets('worker inspection page hides stale nodes from other trades', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _FakeInspectionApi(
      existingNodes: [
        _node('node-1', '水电验收', '水管、电路布线验收', 1),
        _node('node-2', '木工验收', '吊顶、柜体结构验收', 2),
        _node('node-3', '油漆验收', '墙面平整度、颜色均匀度验收', 3),
      ],
    );

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: InspectionPage(
            orderId: 'booking-1',
            tradeLabel: '水电',
            api: api,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(api.createdBookingId, isNull);
    expect(find.text('水电验收'), findsOneWidget);
    expect(find.text('木工验收'), findsNothing);
    expect(find.text('油漆验收'), findsNothing);
  });

  testWidgets('completed project inspection is read-only and creates no node', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _FakeInspectionApi(
      existingNodes: [
        _node('node-1', '水电验收', '水管、电路布线验收', 1, status: 'PASSED'),
      ],
    );

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: InspectionPage(
            orderId: 'booking-1',
            tradeLabel: '水电',
            readOnly: true,
            api: api,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.text('验收记录'), findsOneWidget);
    expect(find.text('水电验收'), findsOneWidget);
    expect(find.text('已通过'), findsOneWidget);
    expect(find.text('申请验收'), findsNothing);
    expect(find.text('申请重新验收'), findsNothing);
    expect(api.createdBookingId, isNull);
  });

  testWidgets('failed inspection lets worker re-submit after rectification', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _FakeInspectionApi(
      existingNodes: [
        _node('node-failed', '水电验收', '水管、电路布线验收', 1, status: 'FAILED'),
      ],
    );

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: InspectionPage(
            orderId: 'booking-1',
            tradeLabel: '水电',
            api: api,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.text('申请重新验收'), findsOneWidget);
    await tester.tap(find.text('申请重新验收'));
    await tester.pumpAndSettle();
    expect(find.text('整改说明'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '已按意见重新固定管线');
    await tester.pump();
    await tester.tap(find.widgetWithText(ZdPrimaryButton, '提交复验申请'));
    await tester.pumpAndSettle();
    expect(api.requestedNodeId, 'node-failed');
    expect(api.requestedNote, '已按意见重新固定管线');
  });

  testWidgets('failed worker can read owner evidence in multi-round timeline', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _FakeInspectionApi(
      existingNodes: [
        _node('node-failed', '水电验收', '水管、电路布线验收', 1, status: 'FAILED'),
      ],
      timeline: [
        RemoteInspectionTimelineEvent(
          id: 'submission-1',
          nodeId: 'node-failed',
          version: 1,
          type: 'WORKER_SUBMISSION',
          actorUserId: 'worker-1',
          note: '第一次完工',
          photos: const [],
          createdAt: DateTime.utc(2026, 8, 6, 8),
        ),
        RemoteInspectionTimelineEvent(
          id: 'decision-1',
          nodeId: 'node-failed',
          version: 1,
          type: 'OWNER_DECISION',
          actorUserId: 'owner-1',
          result: 'FAIL',
          note: '厨房插座线路需要整改',
          photos: const [
            'http://example.com/uploads/inspection-evidence/owner-fail.jpg',
          ],
          createdAt: DateTime.utc(2026, 8, 6, 9),
        ),
      ],
    );

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: InspectionPage(
            orderId: 'booking-1',
            tradeLabel: '水电',
            api: api,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    await tester.tap(find.text('查看验收时间线'));
    await tester.pumpAndSettle();
    expect(find.text('第 1 轮 · 师傅提交'), findsOneWidget);
    expect(find.text('第一次完工'), findsOneWidget);
    expect(find.text('第 1 轮 · 业主验收'), findsOneWidget);
    expect(find.text('厨房插座线路需要整改'), findsOneWidget);
    expect(find.textContaining('2026-08-06'), findsNWidgets(2));
  });

  testWidgets('inspecting node waits for owner and cannot be re-submitted', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _FakeInspectionApi(
      existingNodes: [
        _node('node-inspecting', '水电验收', '水管、电路布线验收', 1, status: 'INSPECTING'),
      ],
    );

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: InspectionPage(
            orderId: 'booking-1',
            tradeLabel: '水电',
            api: api,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.text('等待业主验收'), findsOneWidget);
    expect(find.text('申请验收'), findsNothing);
    expect(find.text('申请重新验收'), findsNothing);
  });

  testWidgets('passed node has no inspection submission action', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _FakeInspectionApi(
      existingNodes: [
        _node('node-passed', '水电验收', '水管、电路布线验收', 1, status: 'PASSED'),
      ],
    );

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: InspectionPage(
            orderId: 'booking-1',
            tradeLabel: '水电',
            api: api,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.text('已通过'), findsOneWidget);
    expect(find.text('申请验收'), findsNothing);
    expect(find.text('申请重新验收'), findsNothing);
  });

  testWidgets(
    'worker account switch during upload prevents old-token request',
    (tester) async {
      final state = await WorkerAppState.memory();
      state.loginWithToken('worker-jwt');
      final upload = Completer<String>();
      final api = _FakeInspectionApi(
        existingNodes: [_node('node-1', '水电验收', '水管、电路布线验收', 1)],
      );
      await tester.pumpWidget(
        WorkerAppScope(
          state: state,
          child: MaterialApp(
            home: InspectionPage(
              orderId: 'booking-1',
              tradeLabel: '水电',
              api: api,
              pickImages: () async => [File('/tmp/session-switch-worker.jpg')],
              uploadImage: (_, token, nodeId) {
                expect(token, 'worker-jwt');
                expect(nodeId, 'node-1');
                return upload.future;
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      await tester.tap(find.text('申请验收'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('添加现场照片'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ZdPrimaryButton, '提交验收申请'));
      await tester.pump();

      await state.logout();
      state.loginWithToken('different-worker-token');
      upload.complete('/uploads/inspection-evidence/old-worker.jpg');
      await tester.pumpAndSettle();

      expect(api.requestedNodeId, isNull);
      expect(find.textContaining('登录账号已切换'), findsOneWidget);
    },
  );
}

final class _FakeInspectionApi implements InspectionApi, InspectionEvidenceApi {
  _FakeInspectionApi({this.existingNodes = const [], this.timeline = const []});

  final List<RemoteInspectionNode> existingNodes;
  final List<RemoteInspectionTimelineEvent> timeline;
  String? createdBookingId;
  List<Map<String, dynamic>> createdNodes = const [];
  String? requestedNodeId;
  String? requestedNote;
  List<String> requestedPhotos = const [];

  @override
  Future<List<RemoteInspectionNode>> getNodes(
    String accessToken,
    String bookingId,
  ) async {
    expect(accessToken, 'worker-jwt');
    expect(bookingId, 'booking-1');
    return existingNodes;
  }

  @override
  Future<List<RemoteInspectionNode>> createNodes(
    String accessToken,
    String bookingId,
    List<Map<String, dynamic>> nodes,
  ) async {
    createdBookingId = bookingId;
    createdNodes = nodes;
    return nodes
        .map(
          (node) => RemoteInspectionNode(
            id: 'node-${node['sortOrder']}',
            bookingId: bookingId,
            name: node['name'] as String,
            description: node['description'] as String,
            status: 'PENDING',
            sortOrder: node['sortOrder'] as int,
            createdAt: DateTime.utc(2026, 7, 18),
          ),
        )
        .toList();
  }

  @override
  Future<RemoteInspectionNode> requestInspection(
    String accessToken,
    String nodeId,
  ) async {
    expect(accessToken, 'worker-jwt');
    requestedNodeId = nodeId;
    final source = [
      ...existingNodes,
      ...createdNodes.map(
        (node) => RemoteInspectionNode(
          id: 'node-${node['sortOrder']}',
          bookingId: 'booking-1',
          name: node['name'] as String,
          description: node['description'] as String,
          status: 'PENDING',
          sortOrder: node['sortOrder'] as int,
          createdAt: DateTime.utc(2026, 7, 18),
        ),
      ),
    ].firstWhere((node) => node.id == nodeId);
    return RemoteInspectionNode(
      id: source.id,
      bookingId: source.bookingId,
      name: source.name,
      description: source.description,
      status: 'INSPECTING',
      sortOrder: source.sortOrder,
      createdAt: source.createdAt,
    );
  }

  @override
  Future<RemoteInspectionNode> requestInspectionWithEvidence(
    String accessToken,
    String nodeId,
    String? note,
    List<String> photos,
  ) async {
    requestedNote = note;
    requestedPhotos = photos;
    return requestInspection(accessToken, nodeId);
  }

  @override
  Future<List<RemoteInspectionTimelineEvent>> getInspectionTimeline(
    String accessToken,
    String nodeId,
  ) async {
    expect(accessToken, 'worker-jwt');
    return timeline;
  }

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

RemoteInspectionNode _node(
  String id,
  String name,
  String description,
  int sortOrder, {
  String status = 'PENDING',
}) => RemoteInspectionNode(
  id: id,
  bookingId: 'booking-1',
  name: name,
  description: description,
  status: status,
  sortOrder: sortOrder,
  createdAt: DateTime.utc(2026, 7, 18),
);
