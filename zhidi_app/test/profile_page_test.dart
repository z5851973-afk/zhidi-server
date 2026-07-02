import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/main.dart';

void main() {
  Future<OwnerAppState> openProfile(WidgetTester tester) async {
    final state = OwnerAppState.memory();
    await tester.pumpWidget(ZhidiApp(state: state));
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    return state;
  }

  testWidgets('profile tab shows owner summary and all service entries', (
    tester,
  ) async {
    await openProfile(tester);

    expect(find.text('王先生'), findsOneWidget);
    expect(find.text('已实名认证'), findsOneWidget);
    expect(find.text('成都'), findsOneWidget);
    expect(find.text('1 个项目'), findsOneWidget);

    for (final label in const [
      '我的预约',
      '在线咨询',
      '我的收藏',
      '平台客服',
      '地址管理',
      '保障与售后',
      '帮助与反馈',
      '设置',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('every profile entry opens an explicit destination', (
    tester,
  ) async {
    await openProfile(tester);

    for (final label in const [
      '我的预约',
      '在线咨询',
      '我的收藏',
      '平台客服',
      '地址管理',
      '保障与售后',
      '帮助与反馈',
      '设置',
    ]) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.text('功能建设中'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('profile edit validates required fields and saves changes', (
    tester,
  ) async {
    final state = await openProfile(tester);

    await tester.tap(find.text('编辑资料'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, '王先生'), '');
    await tester.enterText(find.widgetWithText(TextFormField, '成都'), '');
    await tester.tap(find.text('保存'));
    await tester.pump();

    expect(find.text('请输入姓名'), findsOneWidget);
    expect(find.text('请输入城市'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('profile-name-field')), '李女士');
    await tester.enterText(find.byKey(const Key('profile-city-field')), '杭州');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(find.text('李女士'), findsOneWidget);
    expect(find.text('杭州'), findsOneWidget);
    expect(state.profile.name, '李女士');
    expect(state.profile.city, '杭州');
  });
}
