import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/message/message_page.dart';
import 'package:zhidi_app/pages/home/home_page.dart';

OwnerAppState _state({OwnerKeyValueStore? store}) {
  final state = OwnerAppState.memory(store: store);
  final json = state.toJson();
  json['messages'] = <Map<String, dynamic>>[
    {
      'id': 'human-1',
      'title': '张师傅',
      'content': '材料已经备齐，明天八点到',
      'category': '互动',
      'createdAt': DateTime(2026, 7, 2, 9, 15).toIso8601String(),
      'isRead': false,
    },
    {
      'id': 'order-1',
      'title': '订单助手',
      'content': '订单 #20260702001 已生成，请及时付款',
      'category': '订单',
      'createdAt': DateTime(2026, 7, 2, 8).toIso8601String(),
      'isRead': false,
    },
    {
      'id': 'system-1',
      'title': '平台通知',
      'content': '请通过平台确认验收结果',
      'category': '系统',
      'createdAt': DateTime(2026, 7, 1).toIso8601String(),
      'isRead': true,
    },
  ];
  return OwnerAppState.fromJson(json);
}

Widget _app(OwnerAppState state) => OwnerAppScope(
  state: state,
  child: const MaterialApp(home: Scaffold(body: MessagePage())),
);

void main() {
  testWidgets('combines keyword, category, and unread filters', (tester) async {
    final state = _state();
    await tester.pumpWidget(_app(state));

    await tester.enterText(find.byKey(const Key('message-search')), '材料');
    await tester.pump();
    expect(find.text('张师傅'), findsOneWidget);
    expect(find.text('订单助手'), findsNothing);

    await tester.tap(find.text('订单通知'));
    await tester.pump();
    expect(find.text('暂无匹配消息'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('message-search')), '');
    await tester.tap(find.text('未读'));
    await tester.pump();
    expect(find.text('订单助手'), findsOneWidget);
    expect(find.text('平台通知'), findsNothing);
  });

  testWidgets('marks one read and routes human conversations to chat', (
    tester,
  ) async {
    final state = _state();
    await tester.pumpWidget(_app(state));

    await tester.tap(find.text('张师傅'));
    await tester.pumpAndSettle();

    expect(state.messages.singleWhere((m) => m.id == 'human-1').isRead, isTrue);
    expect(find.text('张师傅'), findsWidgets);
    expect(find.byType(TextField), findsWidgets);
  });

  testWidgets(
    'routes notices to a detail with time content and action summary',
    (tester) async {
      final state = _state();
      await tester.pumpWidget(_app(state));

      await tester.tap(find.text('订单助手'));
      await tester.pumpAndSettle();

      expect(find.text('通知详情'), findsOneWidget);
      expect(find.textContaining('#20260702001'), findsOneWidget);
      expect(find.text('相关操作'), findsOneWidget);
      expect(find.textContaining('2026-07-02'), findsOneWidget);
    },
  );

  testWidgets('mark all persists read state and updates the unread filter', (
    tester,
  ) async {
    final state = _state();
    await tester.pumpWidget(_app(state));

    await tester.tap(find.text('全部已读'));
    await tester.pumpAndSettle();
    expect(state.messages.every((message) => message.isRead), isTrue);

    await tester.tap(find.text('未读'));
    await tester.pump();
    expect(find.text('暂无匹配消息'), findsOneWidget);
  });

  testWidgets('keeps unread state and reports persistence failures', (
    tester,
  ) async {
    final seeded = _state();
    final store = _FailingStore(jsonEncode(seeded.toJson()));
    final state = OwnerAppState.memory(store: store);
    await tester.pumpWidget(_app(state));

    await tester.tap(find.text('全部已读'));
    await tester.pumpAndSettle();

    expect(state.unreadMessageCount, 2);
    expect(find.text('标记失败，请稍后重试'), findsOneWidget);
  });

  testWidgets('one page-wide lock prevents distinct rows stacking routes', (
    tester,
  ) async {
    final seeded = _state();
    final store = _DelayedStore(jsonEncode(seeded.toJson()));
    final state = OwnerAppState.memory(store: store);
    await tester.pumpWidget(_app(state));

    await tester.tap(find.text('张师傅'));
    await tester.pump();
    await tester.tap(find.text('订单助手'));
    await tester.pump();

    expect(store.writeCount, 1);
    store.completeWrite();
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('通知详情'), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('订单助手'), findsOneWidget);
    expect(find.text('通知详情'), findsNothing);
    expect(store.writeCount, 1);
  });

  testWidgets('bottom message badge follows app unread state', (tester) async {
    final state = _state();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(home: HomePage()),
      ),
    );

    expect(find.byKey(const Key('bottom-message-badge')), findsOneWidget);
    await state.markAllMessagesRead();
    await tester.pump();
    expect(find.byKey(const Key('bottom-message-badge')), findsNothing);
  });
}

class _FailingStore implements OwnerKeyValueStore {
  _FailingStore(this.value);
  final String value;

  @override
  String? getString(String key) => value;

  @override
  Future<void> setString(String key, String value) =>
      Future<void>.error(StateError('disk full'));
}

class _DelayedStore implements OwnerKeyValueStore {
  _DelayedStore(this.value);
  String value;
  int writeCount = 0;
  final _write = Completer<void>();

  @override
  String? getString(String key) => value;

  @override
  Future<void> setString(String key, String value) {
    writeCount += 1;
    this.value = value;
    return _write.future;
  }

  void completeWrite() => _write.complete();
}
