import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/models/chat_models.dart';
import 'package:zhidi_app/pages/worker/worker_home_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/chat_api_client.dart';

void main() {
  testWidgets('worker bottom navigation stays above Android system inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await WorkerAppState.memory();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(bottom: 48),
              viewPadding: const EdgeInsets.only(bottom: 48),
            ),
            child: child!,
          ),
          home: const WorkerHomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final navigation = find.byKey(
      const Key('worker-bottom-navigation-content'),
    );
    expect(navigation, findsOneWidget);
    expect(tester.getBottomRight(navigation).dy, 752);
  });

  testWidgets('worker messages tab shows remote chat room previews', (
    tester,
  ) async {
    final state = await WorkerAppState.memory();
    await state.loginOnline(_workerLoginResponse);

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerHomePage(chatApi: _FakeChatApi()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();

    expect(find.text('wz'), findsOneWidget);
    expect(find.text('hhh'), findsOneWidget);
    expect(find.text('暂无消息'), findsNothing);
  });
}

const _workerLoginResponse = OwnerLoginResponse(
  accessToken: 'worker-token',
  tokenType: 'Bearer',
  expiresInSeconds: 3600,
  user: AuthUser(
    id: 'worker-id',
    phone: '19800000000',
    status: 'ACTIVE',
    roles: ['WORKER'],
  ),
);

final class _FakeChatApi implements ChatApi {
  @override
  Future<ChatRoomModel> getOrCreateRoom(String accessToken, String bookingId) =>
      throw UnimplementedError();

  @override
  Future<List<ChatRoomModel>> getRooms(String accessToken) async {
    expect(accessToken, 'worker-token');
    return [
      ChatRoomModel(
        id: 'room-1',
        bookingId: 'booking-1',
        ownerUserId: 'owner-id',
        workerUserId: 'worker-id',
        otherUserId: 'owner-id',
        otherUserName: 'wz',
        lastMessageText: 'hhh',
        lastMessageAt: DateTime(2026, 7, 29, 13, 58),
        unreadCount: 1,
        createdAt: DateTime(2026, 7, 29, 13),
      ),
    ];
  }

  @override
  Future<List<ChatMessageModel>> getMessages(
    String accessToken,
    String roomId, {
    int page = 0,
    int size = 30,
  }) =>
      throw UnimplementedError();

  @override
  Future<ChatMessageModel> sendMessage(
    String accessToken,
    String roomId, {
    required String content,
    String type = 'TEXT',
    String? imageUrl,
  }) =>
      throw UnimplementedError();
}
