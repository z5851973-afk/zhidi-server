import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';
import 'package:zhidi_app/pages/home/worker/worker_detail_page.dart';
import 'package:zhidi_app/pages/home/worker/worker_list_page.dart';

void main() {
  testWidgets('demolition worker list opens detail and booking progress', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(store: MemoryOwnerStore());

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(
          home: WorkerListPage(serviceType: 'demolition'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('找拆除师傅'), findsOneWidget);
    expect(find.text('全部工种'), findsNothing);
    expect(find.text('拆除师傅'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('何师傅').first);
    await tester.pumpAndSettle();

    expect(find.byType(WorkerDetailPage), findsOneWidget);

    await tester.tap(find.text('预约拆除师傅'));
    await tester.pumpAndSettle();

    expect(state.bookedWorkers, hasLength(1));
    expect(state.bookedWorkers.single.name, '何师傅');
    expect(state.bookedWorkers.single.phaseName, '拆除');

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(home: Scaffold(body: MyHomePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('何师傅'), findsAtLeastNWidgets(1));
  });
}
