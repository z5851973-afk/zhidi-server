import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/main.dart';
import 'package:zhidi_app/pages/profile/profile_page.dart';

void main() {
  Future<OwnerAppState> openProfile(
    WidgetTester tester, {
    OwnerAppState? ownerState,
  }) async {
    final state = ownerState ?? OwnerAppState.memory();
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

  testWidgets(
    'profile edit disables save while writing and recovers on error',
    (tester) async {
      final store = _ControlledStore();
      await openProfile(tester, ownerState: OwnerAppState.memory(store: store));
      await tester.tap(find.text('编辑资料'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('profile-name-field')),
        '李女士',
      );
      await tester.tap(find.text('保存'));
      await tester.pump();

      expect(find.text('保存中…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      store.fail(StateError('disk unavailable'));
      await tester.pumpAndSettle();

      expect(find.text('保存失败，请稍后重试'), findsOneWidget);
      expect(find.text('编辑资料'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );

      await tester.tap(find.text('保存'));
      await tester.pump();
      store.succeed();
      await tester.pumpAndSettle();

      expect(find.text('李女士'), findsOneWidget);
    },
  );

  testWidgets('profile header handles long data at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final state = OwnerAppState.memory();
    await state.updateProfile(
      state.profile.copyWith(
        name: '这是一个非常非常长的业主姓名用于测试',
        city: '这是一个非常非常长的城市名称用于测试',
      ),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(body: ProfilePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('编辑资料'), findsOneWidget);
    expect(find.text('已实名认证'), findsOneWidget);
  });
}

class _ControlledStore implements OwnerKeyValueStore {
  Completer<void> _write = Completer<void>();

  @override
  String? getString(String key) => null;

  @override
  Future<void> setString(String key, String value) => _write.future;

  void fail(Object error) {
    _write.completeError(error);
    _write = Completer<void>();
  }

  void succeed() {
    _write.complete();
    _write = Completer<void>();
  }
}
