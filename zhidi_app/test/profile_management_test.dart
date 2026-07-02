import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/profile/address_page.dart';
import 'package:zhidi_app/pages/profile/feedback_page.dart';
import 'package:zhidi_app/pages/profile/settings_page.dart';
import 'package:zhidi_app/pages/profile/support_page.dart';

void main() {
  Future<void> pumpPage(
    WidgetTester tester,
    Widget page,
    OwnerAppState state,
  ) => tester.pumpWidget(
    OwnerAppScope(
      state: state,
      child: MaterialApp(home: page),
    ),
  );

  testWidgets(
    'address form validates phone and supports add edit default delete',
    (tester) async {
      final state = OwnerAppState.memory();
      await pumpPage(tester, const AddressPage(), state);

      await tester.tap(find.text('新增地址'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('address-recipient')), '李女士');
      await tester.enterText(find.byKey(const Key('address-phone')), '123');
      await tester.enterText(find.byKey(const Key('address-city')), '成都');
      await tester.enterText(find.byKey(const Key('address-district')), '锦江区');
      await tester.enterText(
        find.byKey(const Key('address-detail')),
        '春熙路 1 号',
      );
      await tester.tap(find.text('保存地址'));
      await tester.pump();
      expect(find.text('请输入正确的中国大陆手机号'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('address-phone')),
        '13900000000',
      );
      await tester.tap(find.text('设为默认地址'));
      await tester.tap(find.text('保存地址'));
      await tester.pumpAndSettle();
      expect(find.text('地址已新增'), findsOneWidget);
      expect(
        state.addresses.where((address) => address.isDefault),
        hasLength(1),
      );
      expect(find.textContaining('春熙路 1 号'), findsOneWidget);

      await tester.tap(find.byKey(Key('edit-${state.addresses.last.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('address-detail')),
        '春熙路 2 号',
      );
      await tester.tap(find.text('保存地址'));
      await tester.pumpAndSettle();
      expect(find.text('地址已更新'), findsOneWidget);
      expect(find.textContaining('春熙路 2 号'), findsOneWidget);

      await tester.tap(find.byKey(Key('delete-${state.addresses.last.id}')));
      await tester.pumpAndSettle();
      expect(find.text('确认删除这个地址？'), findsOneWidget);
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      expect(find.textContaining('春熙路 2 号'), findsNothing);
    },
  );

  testWidgets('address form cannot unset the sole default address', (
    tester,
  ) async {
    final state = OwnerAppState.memory();
    await pumpPage(tester, const AddressPage(), state);
    final address = state.addresses.single;

    await tester.tap(find.byTooltip('编辑 ${address.recipient} 的地址'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设为默认地址'));
    await tester.tap(find.text('保存地址'));
    await tester.pumpAndSettle();

    expect(state.addresses.where((item) => item.isDefault), hasLength(1));
    expect(state.addresses.single.isDefault, isTrue);
  });

  testWidgets('first address added from empty state becomes default', (
    tester,
  ) async {
    final state = OwnerAppState.memory();
    await state.deleteAddress(state.addresses.single.id);
    await pumpPage(tester, const AddressPage(), state);
    await tester.tap(find.text('新增地址'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('address-recipient')), '李女士');
    await tester.enterText(
      find.byKey(const Key('address-phone')),
      '13900000000',
    );
    await tester.enterText(find.byKey(const Key('address-city')), '成都');
    await tester.enterText(find.byKey(const Key('address-district')), '锦江区');
    await tester.enterText(find.byKey(const Key('address-detail')), '春熙路 1 号');
    await tester.tap(find.text('保存地址'));
    await tester.pumpAndSettle();

    expect(state.addresses.single.isDefault, isTrue);
  });

  testWidgets('support validates and persists a submitted request', (
    tester,
  ) async {
    final state = OwnerAppState.memory();
    await pumpPage(tester, const SupportPage(), state);
    expect(find.text('平台保障说明'), findsOneWidget);
    await tester.tap(find.text('提交售后申请'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('提交申请'));
    await tester.pump();
    expect(find.text('请选择问题类型'), findsOneWidget);
    await tester.tap(find.byKey(const Key('support-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('施工质量').last);
    await tester.enterText(
      find.byKey(const Key('support-description')),
      '墙面出现裂纹',
    );
    await tester.tap(find.text('提交申请'));
    await tester.pumpAndSettle();
    expect(state.afterSalesRequests, hasLength(1));
    expect(find.text('墙面出现裂纹'), findsOneWidget);
  });

  testWidgets('feedback validates category and description then saves', (
    tester,
  ) async {
    final state = OwnerAppState.memory();
    await pumpPage(tester, const FeedbackPage(), state);
    await tester.tap(find.text('提交反馈'));
    await tester.pump();
    expect(find.text('请选择反馈分类'), findsOneWidget);
    expect(find.text('请输入反馈内容'), findsOneWidget);
    await tester.tap(find.byKey(const Key('feedback-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('产品建议').last);
    await tester.enterText(
      find.byKey(const Key('feedback-description')),
      '希望增加进度日历',
    );
    await tester.tap(find.text('提交反馈'));
    await tester.pumpAndSettle();
    expect(state.feedbackEntries, hasLength(1));
    expect(find.text('反馈提交成功'), findsOneWidget);
  });

  testWidgets('settings switches persist and details are available', (
    tester,
  ) async {
    final state = OwnerAppState.memory();
    await pumpPage(tester, const SettingsPage(), state);
    await tester.tap(find.byKey(const Key('push-switch')));
    await tester.pumpAndSettle();
    expect(state.settings.pushNotifications, isFalse);
    await tester.tap(find.text('关于智地'));
    await tester.pumpAndSettle();
    expect(find.text('智地业主端'), findsOneWidget);
  });

  testWidgets('settings reset confirms and performs a persisted reset', (
    tester,
  ) async {
    final state = OwnerAppState.memory();
    await state.updateSettings(
      state.settings.copyWith(pushNotifications: false, hidePhone: false),
    );
    await pumpPage(tester, const SettingsPage(), state);
    await tester.tap(find.text('恢复默认通知与隐私设置'));
    await tester.pumpAndSettle();
    expect(find.text('恢复默认设置？'), findsOneWidget);
    await tester.tap(find.text('确认恢复'));
    await tester.pumpAndSettle();
    expect(state.settings.toJson(), const OwnerSettings().toJson());
    expect(find.text('默认设置已恢复'), findsOneWidget);
  });

  testWidgets('settings reset reports persistence failure without success', (
    tester,
  ) async {
    final document = OwnerAppState.memory().toJson();
    document['settings'] = const OwnerSettings(
      pushNotifications: false,
    ).toJson();
    final store = _ControlledStore(jsonEncode(document));
    final state = OwnerAppState.memory(store: store);
    await pumpPage(tester, const SettingsPage(), state);
    await tester.tap(find.text('恢复默认通知与隐私设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认恢复'));
    await tester.pump();
    store.fail(StateError('disk unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('恢复失败，设置未更改，请重试'), findsOneWidget);
    expect(find.text('默认设置已恢复'), findsNothing);
  });
}

class _ControlledStore implements OwnerKeyValueStore {
  _ControlledStore(this.initialValue);
  final String initialValue;
  Completer<void> _write = Completer<void>();
  @override
  String? getString(String key) => initialValue;
  @override
  Future<void> setString(String key, String value) => _write.future;
  void fail(Object error) {
    _write.completeError(error);
    _write = Completer<void>();
  }
}
