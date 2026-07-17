import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';

MaterialEstimate _estimate() {
  return MaterialEstimate(
    id: 'estimate-1',
    workerId: 'worker-1',
    workerName: '李师傅',
    workerTrade: '拆除工',
    phaseName: '拆除',
    phaseIndex: 0,
    createdAt: DateTime(2026, 7, 15, 10),
    items: const [
      MaterialItem(
        id: 'item-1',
        name: '垃圾袋',
        category: MaterialCategory.auxiliary,
        quantity: 20,
        unit: '个',
        unitPrice: 1.5,
      ),
      MaterialItem(
        id: 'item-2',
        name: '保护膜',
        category: MaterialCategory.auxiliary,
        quantity: 5,
        unit: '卷',
        unitPrice: 18,
      ),
    ],
  );
}

void main() {
  test('adds and confirms material estimate with persistence', () async {
    final store = MemoryOwnerStore();
    final state = await OwnerAppState.memory(store: store);

    await state.addMaterialEstimate(_estimate());

    expect(state.materialEstimates, hasLength(1));
    expect(
      state.materialEstimates.single.items
          .fold<double>(0, (sum, item) => sum + item.totalPrice),
      120,
    );
    expect(
      state.materialEstimates.single.status,
      EstimateStatus.pending,
    );

    final restored = await OwnerAppState.memory(store: store);
    expect(restored.materialEstimates.single.items, hasLength(2));

    await restored.toggleMaterialItem('estimate-1', 'item-1');
    await restored.toggleMaterialItem('estimate-1', 'item-2');
    await restored.confirmMaterialEstimate('estimate-1');

    expect(restored.materialEstimates.single.status, EstimateStatus.ordered);
    expect(restored.messages.first.title, '材料已下单');
  });
}
