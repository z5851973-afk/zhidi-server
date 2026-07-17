import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';
import 'package:zhidi_app/pages/home/renovation_archive_page.dart';

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
  testWidgets('opens renovation archive from inspection records', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(store: MemoryOwnerStore());
    await state.bookWorker(_worker());
    await state.requestInspection('worker-1');
    await state.approveInspection(state.inspections.single.id);

    await _pumpMyHome(tester, state);

    await tester.scrollUntilVisible(
      find.text('验收记录'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('验收记录'));
    await tester.pumpAndSettle();

    expect(find.byType(RenovationArchivePage), findsOneWidget);
    expect(find.text('装修档案'), findsOneWidget);
    expect(find.text('拆除'), findsAtLeastNWidgets(1));
    expect(find.text('李师傅 · 拆除工'), findsOneWidget);
    expect(find.text('验收合格'), findsOneWidget);
  });
}
