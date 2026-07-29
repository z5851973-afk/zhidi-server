import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/pages/worker/inspection_page.dart';
import 'package:zhidi_app/services/inspection_api_client.dart';

void main() {
  testWidgets('worker inspection page creates and shows default nodes', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    state.loginWithToken('worker-jwt');
    final api = _FakeInspectionApi();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: InspectionPage(orderId: 'booking-1', api: api),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(api.createdBookingId, 'booking-1');
    expect(find.text('水电验收'), findsOneWidget);
    expect(find.text('木工验收'), findsOneWidget);
    expect(find.text('申请验收'), findsWidgets);
  });
}

final class _FakeInspectionApi implements InspectionApi {
  String? createdBookingId;

  @override
  Future<List<RemoteInspectionNode>> getNodes(
    String accessToken,
    String bookingId,
  ) async {
    expect(accessToken, 'worker-jwt');
    expect(bookingId, 'booking-1');
    return const [];
  }

  @override
  Future<List<RemoteInspectionNode>> createNodes(
    String accessToken,
    String bookingId,
    List<Map<String, dynamic>> nodes,
  ) async {
    createdBookingId = bookingId;
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
  ) =>
      throw UnimplementedError();

  @override
  Future<RemoteInspectionRecord> inspect(
    String accessToken,
    String nodeId,
    String result,
    String? comment,
    List<String> photos,
  ) =>
      throw UnimplementedError();

  @override
  Future<List<RemoteInspectionRecord>> getRecords(
    String accessToken,
    String nodeId,
  ) =>
      throw UnimplementedError();
}
