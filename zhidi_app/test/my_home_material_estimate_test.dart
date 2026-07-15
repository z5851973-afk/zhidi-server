import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';

MaterialEstimate _estimate() {
  return MaterialEstimate(
    id: 'estimate-1',
    workerId: 'worker-1',
    workerName: '李师傅',
    phaseName: '拆除',
    phaseIndex: 0,
    createdAt: DateTime(2026, 7, 15, 10),
    items: const [
      MaterialItem(
        id: 'item-1',
        name: '垃圾袋',
        quantity: 20,
        unit: '个',
        unitPrice: 1.5,
      ),
      MaterialItem(
        id: 'item-2',
        name: '保护膜',
        quantity: 5,
        unit: '卷',
        unitPrice: 18,
      ),
    ],
  );
}

Future<void> _pumpMyHome(WidgetTester tester, OwnerAppState state) async {
  await tester.pumpWidget(
    OwnerAppScope(
      state: state,
      child: const MaterialApp(home: Scaffold(body: MyHomePage())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows and confirms material estimate from my home', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(store: MemoryOwnerStore());
    await state.addMaterialEstimate(_estimate());

    await _pumpMyHome(tester, state);

    expect(find.text('材料估算'), findsOneWidget);
    expect(find.text('拆除材料清单'), findsOneWidget);
    expect(find.text('垃圾袋 20个'), findsOneWidget);
    expect(find.textContaining('预计 ¥120.00'), findsOneWidget);

    await tester.tap(find.text('确认采购'));
    await tester.pumpAndSettle();

    expect(
      state.materialEstimates.single.status,
      MaterialEstimateStatus.ordered,
    );
    expect(find.text('已确认采购'), findsAtLeastNWidgets(1));
  });
}
