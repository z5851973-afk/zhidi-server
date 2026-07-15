import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/worker/worker_detail_page.dart';

void main() {
  testWidgets('worker detail opens quote page and can save quote', (
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

    await tester.tap(find.text('看报价'));
    await tester.pumpAndSettle();

    expect(find.text('李师傅的报价清单'), findsOneWidget);

    await tester.tap(find.text('价高再考虑'));
    await tester.pumpAndSettle();

    expect(state.savedQuotes, hasLength(1));
    expect(state.savedQuotes.single.workerName, '李师傅');
    expect(state.savedQuotes.single.tradeName, '拆除');
  });
}
