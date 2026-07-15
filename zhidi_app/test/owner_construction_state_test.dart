import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_state.dart';

BookedWorker _worker({
  String id = 'worker-1',
  String name = '李师傅',
  String trade = '拆除工',
  String phaseName = '阳台改造',
  int phaseIndex = 42,
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
  test('books workers by phase, replaces same phase, and cancels booking', () async {
    final state = await OwnerAppState.memory(store: MemoryOwnerStore());

    await state.bookWorker(_worker());

    final booked = state.bookedWorkers.where((item) => item.phaseIndex == 42);
    expect(booked, hasLength(1));
    expect(booked.single.name, '李师傅');
    expect(booked.single.bookedAt, isNotNull);
    expect(state.messages.first.title, '预约已确认');

    await state.bookWorker(
      _worker(id: 'worker-2', name: '王师傅', trade: '拆除工'),
    );

    final replaced = state.bookedWorkers.where((item) => item.phaseIndex == 42);
    expect(replaced, hasLength(1));
    expect(replaced.single.id, 'worker-2');

    await state.cancelBookedWorker('worker-2');

    expect(
      state.bookedWorkers.where((item) => item.phaseIndex == 42),
      isEmpty,
    );
    expect(state.messages.first.title, '预约已取消');
  });

  test('confirms phase completion and persists construction state', () async {
    final store = MemoryOwnerStore();
    final state = await OwnerAppState.memory(store: store);

    await state.bookWorker(_worker());
    await state.confirmPhaseComplete(42);

    expect(state.completedPhases, contains(42));
    expect(
      state.bookedWorkers.firstWhere((item) => item.id == 'worker-1').status,
      '已完成',
    );

    final restored = await OwnerAppState.memory(store: store);

    final restoredWorker = restored.bookedWorkers.firstWhere(
      (item) => item.id == 'worker-1',
    );
    expect(restoredWorker.name, '李师傅');
    expect(restoredWorker.status, '已完成');
    expect(restored.completedPhases, contains(42));
  });
}
