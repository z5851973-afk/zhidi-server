import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/owner_inspection_page.dart';
import 'package:zhidi_app/services/auth_session_store.dart';
import 'package:zhidi_app/services/inspection_api_client.dart';

void main() {
  testWidgets('owner inspection page loads remote inspection nodes', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(
      sessionStore: MemoryAuthSessionStore(_validSession()),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: OwnerInspectionPage(
            bookingId: 'booking-1',
            api: _FakeInspectionApi(),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(find.text('木工验收'), findsOneWidget);
    expect(find.text('验收中'), findsOneWidget);
    expect(find.text('去验收'), findsOneWidget);
  });
}

AuthSession _validSession() => AuthSession(
      accessToken: 'owner-jwt',
      tokenType: 'Bearer',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      userId: 'owner-1',
      phone: '13812345678',
      roles: const ['OWNER'],
    );

final class _FakeInspectionApi implements InspectionApi {
  @override
  Future<List<RemoteInspectionNode>> getNodes(
    String accessToken,
    String bookingId,
  ) async {
    expect(accessToken, 'owner-jwt');
    expect(bookingId, 'booking-1');
    return [
      RemoteInspectionNode(
        id: 'node-1',
        bookingId: bookingId,
        name: '木工验收',
        description: '吊顶、柜体结构验收',
        status: 'INSPECTING',
        sortOrder: 2,
        createdAt: DateTime.utc(2026, 7, 18),
      ),
    ];
  }

  @override
  Future<List<RemoteInspectionNode>> createNodes(
    String accessToken,
    String bookingId,
    List<Map<String, dynamic>> nodes,
  ) =>
      throw UnimplementedError();

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
