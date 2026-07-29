import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
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
}

final class _FakeInspectionApi implements InspectionApi {
  _FakeInspectionApi({this.existingNodes = const []});

  final List<RemoteInspectionNode> existingNodes;
  String? createdBookingId;
  List<Map<String, dynamic>> createdNodes = const [];

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

RemoteInspectionNode _node(
  String id,
  String name,
  String description,
  int sortOrder,
) => RemoteInspectionNode(
  id: id,
  bookingId: 'booking-1',
  name: name,
  description: description,
  status: 'PENDING',
  sortOrder: sortOrder,
  createdAt: DateTime.utc(2026, 7, 18),
);
