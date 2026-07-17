import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/worker/worker_detail_page.dart';
import 'package:zhidi_app/pages/order/create_order_page.dart';

void main() {
  testWidgets('local worker detail opens form and creates local appointment', (
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

    expect(find.byType(CreateOrderPage), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '刘先生');
    await tester.enterText(fields.at(1), '13800138000');
    await tester.enterText(fields.at(2), '成都市高新区 1 号');
    await tester.enterText(fields.at(3), '89');
    await tester.enterText(fields.at(4), '拆除旧墙体');
    await tester.tap(find.text('提交预约'));
    await tester.pumpAndSettle();

    expect(state.appointments, hasLength(1));
    expect(state.appointments.single.workerName, '李师傅');
    expect(state.appointments.single.customerName, '刘先生');
  });
}
