import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';
import 'package:zhidi_app/pages/home/worker/worker_detail_page.dart';

void main() {
  testWidgets('booking from worker detail appears in my home progress', (
    tester,
  ) async {
    final state = await OwnerAppState.memory(store: MemoryOwnerStore());

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(
          home: WorkerDetailPage(
            workerId: 'worker-li',
            name: '李师傅',
            workerJob: '拆除师傅',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('预约拆除师傅'));
    await tester.pumpAndSettle();

    expect(state.bookedWorkers, hasLength(1));
    expect(state.bookedWorkers.single.name, '李师傅');
    expect(state.bookedWorkers.single.phaseName, '拆除');

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(home: Scaffold(body: MyHomePage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('李师傅'), findsAtLeastNWidgets(1));
    expect(find.text('拆除'), findsAtLeastNWidgets(1));
    expect(find.text('进行中'), findsAtLeastNWidgets(1));
  });
}
