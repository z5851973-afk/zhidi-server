import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/worker/worker_detail_page.dart';
import 'package:zhidi_app/pages/order/create_order_page.dart';
import 'package:zhidi_app/pages/order/my_orders_page.dart';
import 'package:zhidi_app/pages/order/order_store.dart';
import 'package:zhidi_app/pages/profile/favorites_page.dart';

void main() {
  Widget app(OwnerAppState state, Widget child) => OwnerAppScope(
    state: state,
    child: MaterialApp(home: child),
  );

  test('appointments survive rebuilding state from the same store', () async {
    final store = MemoryOwnerStore();
    final state = OwnerAppState.memory(store: store);
    final order = OrderItem(
      workerName: '李师傅',
      customerName: '王先生',
      phone: '13800000000',
      address: '成都高新区',
      area: '89㎡',
      description: '水电改造',
      visitTime: '明天下午',
      status: '待师傅确认',
      createdAt: DateTime(2026, 7, 2, 10),
    );

    await state.addAppointment(order);

    final restored = OwnerAppState.memory(store: store);
    expect(restored.appointments, hasLength(1));
    expect(restored.appointments.single.toJson(), order.toJson());
  });

  testWidgets('submitting an appointment makes it visible in my appointments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final state = OwnerAppState.memory();
    await tester.pumpWidget(
      app(state, const CreateOrderPage(workerName: '李师傅')),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, '请输入联系人姓名'),
      '王先生',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '请输入手机号'),
      '13800000000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '请输入小区 / 街道 / 门牌号'),
      '成都高新区',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '例如：厨房水电改造、旧房翻新等'),
      '水电改造',
    );
    await tester.tap(find.text('提交预约'));
    await tester.pumpAndSettle();

    expect(state.appointments, hasLength(1));
    expect(state.appointments.single.description, '水电改造');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app(state, const MyOrdersPage()));
    await tester.pumpAndSettle();
    expect(find.text('李师傅'), findsOneWidget);
    expect(find.text('水电改造'), findsOneWidget);
  });

  testWidgets(
    'worker detail favorite appears in favorites and can be removed',
    (tester) async {
      final state = OwnerAppState.memory();
      await tester.pumpWidget(
        app(state, const WorkerDetailPage(name: '李师傅', workerJob: '水电师傅')),
      );

      await tester.tap(find.byKey(const Key('worker-favorite-button')));
      await tester.pumpAndSettle();
      expect(state.isFavorite('李师傅|水电师傅'), isTrue);

      await tester.pumpWidget(app(state, const FavoritesPage()));
      await tester.pumpAndSettle();
      expect(find.text('李师傅'), findsOneWidget);
      await tester.tap(find.byKey(const Key('remove-favorite-李师傅|水电师傅')));
      await tester.pumpAndSettle();
      expect(state.favoriteWorkers, isEmpty);
      expect(find.text('暂无收藏'), findsOneWidget);
      expect(find.text('去发现师傅'), findsOneWidget);
    },
  );

  testWidgets('favorite save failure restores an enabled action', (
    tester,
  ) async {
    final store = _ControlledStore();
    final state = OwnerAppState.memory(store: store);
    await tester.pumpWidget(
      app(state, const WorkerDetailPage(name: '李师傅', workerJob: '水电师傅')),
    );

    await tester.tap(find.byKey(const Key('worker-favorite-button')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    store.fail(StateError('disk unavailable'));
    await tester.pumpAndSettle();

    expect(find.text('收藏保存失败，请稍后重试'), findsOneWidget);
    expect(state.favoriteWorkers, isEmpty);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('worker-favorite-button')))
          .onPressed,
      isNotNull,
    );
  });
}

class _ControlledStore implements OwnerKeyValueStore {
  final List<Completer<void>> _writes = [];

  @override
  String? getString(String key) => null;

  @override
  Future<void> setString(String key, String value) {
    final completer = Completer<void>();
    _writes.add(completer);
    return completer.future;
  }

  void fail(Object error) => _writes.removeAt(0).completeError(error);
}
