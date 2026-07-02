import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';

Widget _app(OwnerAppState state) => OwnerAppScope(
  state: state,
  child: const MaterialApp(home: Scaffold(body: MyHomePage())),
);

Future<void> _scrollTo(WidgetTester tester, String text) async {
  await tester.scrollUntilVisible(
    find.text(text),
    300,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  testWidgets('uses Chengdu project and 2026 schedule from owner state', (
    tester,
  ) async {
    await tester.pumpWidget(_app(OwnerAppState.memory()));

    expect(find.text('麓湖新居翻新'), findsOneWidget);
    expect(find.textContaining('成都'), findsWidgets);
    expect(find.text('2项待处理'), findsOneWidget);
    await _scrollTo(tester, '查看下一步');
    expect(find.textContaining('2026-07-04'), findsOneWidget);
  });

  testWidgets('project operations open focused pages and edit persists', (
    tester,
  ) async {
    final document = OwnerAppState.memory().toJson();
    document['projects'] = [
      ...(document['projects'] as List<dynamic>),
      OwnerProject(
        id: 'project-2',
        name: '锦江花园局部改造',
        city: '成都',
        address: '锦江区静安路 88 号',
        startDate: DateTime(2026, 8, 6),
      ).toJson(),
    ];
    final state = OwnerAppState.fromJson(document);
    await tester.pumpWidget(_app(state));

    await tester.tap(find.text('切换项目'));
    await tester.pumpAndSettle();
    expect(find.text('选择项目'), findsOneWidget);
    await tester.tap(find.text('锦江花园局部改造'));
    await tester.pumpAndSettle();
    expect(state.selectedProjectId, 'project-2');
    expect(find.text('锦江花园局部改造'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('编辑项目'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('project-name-field')),
      '麓湖 2026 新家',
    );
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(state.selectedProject!.name, '麓湖 2026 新家');

    for (final entry in <String, String>{
      '项目成员': '项目成员',
      '项目群聊': '麓湖 2026 新家项目群',
      '项目设置': '项目设置',
    }.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('分享家'));
    await tester.pump();
    expect(find.text('项目分享信息已准备'), findsOneWidget);
  });

  testWidgets('reminder completion updates pending count and is recoverable', (
    tester,
  ) async {
    final state = OwnerAppState.memory();
    await tester.pumpWidget(_app(state));

    await tester.tap(find.text('完成').first);
    await tester.pumpAndSettle();
    expect(find.text('1项待处理'), findsOneWidget);
    expect(state.reminders.where((item) => !item.isCompleted), hasLength(1));
  });

  testWidgets('lower dashboard actions navigate to truthful destinations', (
    tester,
  ) async {
    await tester.pumpWidget(_app(OwnerAppState.memory()));

    for (final entry in <String, String>{
      '查看下一步': '下一步计划',
      '查看全部工人': '全部工人',
      '查看验收记录': '验收记录',
      '查看全部档案': '装修档案',
      '了解资金托管': '资金托管说明',
      '申请售后': '保障与售后',
    }.entries) {
      await _scrollTo(tester, entry.key);
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsWidgets);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });
}
