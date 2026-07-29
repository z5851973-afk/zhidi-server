import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/worker_app_scope.dart';
import 'package:zhidi_app/app/worker_app_state.dart';
import 'package:zhidi_app/pages/worker/worker_home_page.dart';

void main() {
  testWidgets('worker bottom navigation stays above Android system inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await WorkerAppState.memory();

    await tester.pumpWidget(
      WorkerAppScope(
        state: state,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: const EdgeInsets.only(bottom: 48),
              viewPadding: const EdgeInsets.only(bottom: 48),
            ),
            child: child!,
          ),
          home: const WorkerHomePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final navigation = find.byKey(
      const Key('worker-bottom-navigation-content'),
    );
    expect(navigation, findsOneWidget);
    expect(tester.getBottomRight(navigation).dy, 752);
  });
}
