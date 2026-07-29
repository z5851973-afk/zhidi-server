import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/models/chat_models.dart';
import 'package:zhidi_app/pages/worker/worker_home_page.dart';
import 'package:zhidi_app/services/auth_api_client.dart';
import 'package:zhidi_app/services/chat_api_client.dart';

void main() {
  testWidgets('opening worker messages tab clears local unread notification badge', (
    tester,
  ) async {
    final state = WorkerAppState.fromJson({
      'profile': {
        'name': '',
        'phone': '',
        'avatar': '',
        'trade': 'demolition',
        'tradeSelected': false,
        'serviceCity': '',
        'experienceYears': 0,
        'dailyRate': 0,
        'rating': 0,
        'totalOrders': 0,
        'certifications': <String>[],
        'serviceAreas': <String>[],
        'bio': '',
        'idCard': '',
        'isVerified': false,
      },
      'orders': <Map<String, dynamic>>[],
      'dailyReports': <Map<String, dynamic>>[],
      'inspectionRequests': <Map<String, dynamic>>[],
      'earnings': <Map<String, dynamic>>[],
      'messages': [
        {
          'id': 'notice-1',
          'title': '新的预约待接单',
          'content': '业主预约了您的泥瓦服务，请及时处理。',
          'category': '订单',
          'createdAt': '2026-07-29T10:00:00.000',
          'isRead': false,
        },
      ],
      'settings': <String, dynamic>{},
      'quotations': <Map<String, dynamic>>[],
      'isLoggedIn': true,
      'remoteBookings': <Map<String, dynamic>>[],
    });
    state.loginWithToken('worker-token');

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerHomePage(chatApi: _FakeChatApi(rooms: const [])),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(state.unreadMessageCount, 1);

    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();

    expect(state.unreadMessageCount, 0);
    expect(find.textContaining('条通知未读'), findsNothing);
  });

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
    final api = _FakeChatApi();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerHomePage(chatApi: api),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('消息'));
    await tester.pumpAndSettle();

    expect(find.text('wz'), findsOneWidget);
    expect(find.text('hhh'), findsOneWidget);
    expect(find.text('暂无消息'), findsNothing);

    await tester.tap(find.text('wz'));
    await tester.pumpAndSettle();

    expect(api.markedRoomIds, contains('room-1'));
    expect(find.text('1'), findsNothing);
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
  _FakeChatApi({this.rooms});

  final List<ChatRoomModel>? rooms;

  @override
  Future<ChatRoomModel> getOrCreateRoom(String accessToken, String bookingId) =>
      throw UnimplementedError();

  final List<String> markedRoomIds = [];

  @override
  Future<List<ChatRoomModel>> getRooms(String accessToken) async {
    expect(accessToken, 'worker-token');
    if (rooms != null) return rooms!;
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
  Future<void> markRoomRead(String accessToken, String roomId) async {
    markedRoomIds.add(roomId);
  }

  @override
  Future<List<ChatMessageModel>> getMessages(
    String accessToken,
    String roomId, {
    int page = 0,
    int size = 30,
  }) async =>
      const [];

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
