import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/warranty_card_page.dart';
import 'package:zhidi_app/pages/profile/profile_page.dart';

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
  testWidgets(
    'profile online consult reports that platform chat is unavailable',
    (tester) async {
      await _pumpOwnerPage(tester, const Scaffold(body: ProfilePage()));

      await tester.tap(find.text('在线咨询'));
      await tester.pump();

      expect(find.text('平台咨询暂未开放'), findsOneWidget);
      expect(find.text('请输入咨询内容'), findsNothing);
      expect(find.text('在线咨询'), findsOneWidget);
    },
  );

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
}
