import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/warranty_card_page.dart';
import 'package:zhidi_app/pages/profile/profile_page.dart';
import 'package:zhidi_app/pages/renovation/worker_detail_page.dart';
import 'package:zhidi_app/pages/renovation/worker_chat_page.dart';

Future<OwnerAppState> _pumpOwnerPage(WidgetTester tester, Widget page) async {
  final state = await OwnerAppState.memory();
  await tester.pumpWidget(
    OwnerAppScope(
      state: state,
      child: MaterialApp(home: page),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

void main() {
  testWidgets('profile online consult opens a real chat page', (tester) async {
    await _pumpOwnerPage(tester, const ProfilePage());

    await tester.tap(find.text('在线咨询'));
    await tester.pumpAndSettle();

    expect(find.text('平台客服'), findsWidgets);
    expect(find.text('请输入咨询内容'), findsOneWidget);
    expect(find.text('在线咨询'), findsNothing);
  });

  testWidgets('warranty card share button gives visible feedback', (
    tester,
  ) async {
    await _pumpOwnerPage(
      tester,
      WarrantyCardPage(
        phaseName: '水电验收',
        phaseIndex: 2,
        worker: null,
        startedAt: DateTime(2026, 7, 1),
        completedAt: DateTime(2026, 7, 10),
      ),
    );

    await tester.tap(find.byIcon(Icons.share_outlined));
    await tester.pump();

    expect(find.textContaining('分享'), findsWidgets);
  });

  testWidgets('worker chat send button appends the typed message', (
    tester,
  ) async {
    await _pumpOwnerPage(tester, const WorkerChatPage(workerName: '王师傅'));

    await tester.enterText(find.byType(TextField), '明天几点上门？');
    await tester.tap(find.text('发送'));
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
    expect(find.text('明天几点上门？'), findsOneWidget);
  });

  testWidgets('worker chat persists sent messages to owner state', (
    tester,
  ) async {
    final state = await _pumpOwnerPage(
      tester,
      const WorkerChatPage(workerName: '王师傅'),
    );

    await tester.enterText(find.byType(TextField), '明天几点上门？');
    await tester.tap(find.text('发送'));
    await tester.pump();

    final messages = state.getChatMessages('王师傅');
    expect(messages, hasLength(1));
    expect(messages.single.text, '明天几点上门？');
    expect(messages.single.isMe, isTrue);
  });

  testWidgets('renovation worker detail favorite writes to owner favorites', (
    tester,
  ) async {
    final state = await _pumpOwnerPage(
      tester,
      const WorkerDetailPage(workerName: '王师傅'),
    );

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    expect(state.favoriteWorkers.map((w) => w.name), contains('王师傅'));
  });
}
