import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';

BookedWorker _worker() {
  return BookedWorker(
    id: 'worker-1',
    name: '李师傅',
    trade: '拆除工',
    phaseName: '拆除',
    phaseIndex: 0,
    rating: 4.9,
    completedOrders: 128,
    years: 8,
    avatarEmoji: '👷',
    skills: const ['拆墙', '垃圾清运'],
  );
}

void main() {
  test('approving inspection creates and persists renovation archive', () async {
    final store = MemoryOwnerStore();
    final state = await OwnerAppState.memory(store: store);

    await state.bookWorker(_worker());
    await state.requestInspection('worker-1');
    await state.approveInspection(state.inspections.single.id);

    expect(state.archives, hasLength(1));
    expect(state.archives.single.workerName, '李师傅');
    expect(state.archives.single.phaseName, '拆除');
    expect(state.archives.single.status, '验收通过');

    final restored = await OwnerAppState.memory(store: store);

    expect(restored.archives, hasLength(1));
    expect(restored.archives.single.workerId, 'worker-1');
    expect(restored.archives.single.completedAt, isNotNull);
  });
}
