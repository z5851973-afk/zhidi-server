import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';

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

Future<OwnerAppState> _stateWithWorker() async {
  final state = await OwnerAppState.memory(store: MemoryOwnerStore());
  await state.bookWorker(_worker());
  return state;
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
  testWidgets('requests and approves inspection from my home', (tester) async {
    final state = await _stateWithWorker();

    await _pumpMyHome(tester, state);
    await tester.tap(find.text('申请验收'));
    await tester.pumpAndSettle();

    expect(state.inspections, hasLength(1));
    expect(state.inspections.single.status, InspectionStatus.pending);
    expect(find.text('待验收'), findsWidgets);

    await tester.tap(find.text('通过验收'));
    await tester.pumpAndSettle();

    expect(state.inspections.single.status, InspectionStatus.approved);
    expect(state.completedPhases, contains(0));
    expect(find.text('已完成'), findsWidgets);
  });
}
