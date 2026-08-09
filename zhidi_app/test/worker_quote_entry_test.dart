import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/worker/worker_detail_page.dart';

void main() {
  testWidgets('worker detail exposes current trade pricing details', (
    tester,
  ) async {
    final state = await OwnerAppState.memory();

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

    await tester.scrollUntilVisible(find.text('工价详情'), 500);
    await tester.tap(find.text('工价详情'));
    await tester.pumpAndSettle();

    expect(find.text('拆墙'), findsOneWidget);
    expect(find.text('¥35-50/㎡'), findsOneWidget);
    expect(state.savedQuotes, isEmpty);
  });
}
