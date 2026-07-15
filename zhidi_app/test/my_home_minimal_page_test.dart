import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';

BookedWorker _worker({
  String id = 'worker-1',
  String name = '李师傅',
  int phaseIndex = 0,
  String phaseName = '拆除',
  String status = '已接单待上门',
}) {
  return BookedWorker(
    id: id,
    name: name,
    trade: '拆除工',
    phaseName: phaseName,
    phaseIndex: phaseIndex,
    rating: 4.9,
    completedOrders: 128,
    years: 8,
    avatarEmoji: '👷',
    skills: const ['拆墙', '垃圾清运'],
    status: status,
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
  testWidgets('shows current construction worker and phase progress', (
    tester,
  ) async {
    final state = await _stateWithWorker();

    await _pumpMyHome(tester, state);

    expect(find.text('我的家'), findsOneWidget);
    expect(find.text('麓湖新居翻新'), findsOneWidget);
    expect(find.text('施工进度'), findsOneWidget);
    expect(find.text('李师傅'), findsAtLeastNWidgets(1));
    expect(find.text('拆除'), findsWidgets);
    expect(find.text('进行中'), findsAtLeastNWidgets(1));
  });

  testWidgets('can confirm a booked worker phase complete', (tester) async {
    final state = await _stateWithWorker();

    await _pumpMyHome(tester, state);
    await tester.tap(find.text('确认完成'));
    await tester.pumpAndSettle();

    expect(state.completedPhases, contains(0));
    expect(find.text('已完成'), findsWidgets);
  });
}
