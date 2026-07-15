import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';

BookedWorker _worker({
  String id = 'worker-1',
  String name = '李师傅',
  String trade = '拆除工',
  String phaseName = '拆除',
  int phaseIndex = 0,
}) {
  return BookedWorker(
    id: id,
    name: name,
    trade: trade,
    phaseName: phaseName,
    phaseIndex: phaseIndex,
    rating: 4.9,
    completedOrders: 128,
    years: 8,
    avatarEmoji: '👷',
    skills: const ['拆墙', '垃圾清运'],
  );
}

void main() {
  test('requests inspection and approves phase completion', () async {
    final store = MemoryOwnerStore();
    final state = await OwnerAppState.memory(store: store);

    await state.bookWorker(_worker());
    await state.requestInspection('worker-1');

    expect(state.inspections, hasLength(1));
    expect(state.inspections.single.workerName, '李师傅');
    expect(state.inspections.single.status, InspectionStatus.pending);
    expect(state.completedPhases, isNot(contains(0)));

    final restored = await OwnerAppState.memory(store: store);
    expect(restored.inspections.single.status, InspectionStatus.pending);

    await restored.approveInspection(restored.inspections.single.id);

    expect(restored.inspections.single.status, InspectionStatus.approved);
    expect(restored.completedPhases, contains(0));
    expect(
      restored.bookedWorkers.firstWhere((item) => item.id == 'worker-1').status,
      '已完成',
    );
    expect(restored.messages.first.title, '验收已通过');
  });

  test('rejects inspection without completing phase', () async {
    final state = await OwnerAppState.memory(store: MemoryOwnerStore());

    await state.bookWorker(_worker());
    await state.requestInspection('worker-1');
    await state.rejectInspection(state.inspections.single.id, note: '墙面未清理');

    expect(state.inspections.single.status, InspectionStatus.rejected);
    expect(state.inspections.single.ownerNote, '墙面未清理');
    expect(state.completedPhases, isNot(contains(0)));
    expect(
      state.bookedWorkers.firstWhere((item) => item.id == 'worker-1').status,
      isNot('已完成'),
    );
    expect(state.messages.first.title, '验收已驳回');
  });
}
