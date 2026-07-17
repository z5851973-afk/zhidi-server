import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/pages/splash/splash_page.dart';

void main() {
  testWidgets('splash starts once after two seconds and fade completes', (
    tester,
  ) async {
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(home: SplashPage(onStart: () => starts++)),
    );

    await tester.pump(const Duration(milliseconds: 1999));
    expect(starts, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(starts, 0);
    await tester.pumpAndSettle();
    expect(starts, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(starts, 1);
  });

  for (final width in <double>[320, 390]) {
    testWidgets('splash content fits ${width}px without a button', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: SplashPage()),
      );

      expect(find.byType(Image), findsWidgets);
      expect(find.text('知底'), findsOneWidget);
      expect(find.text('装修找知底，心里就有底'), findsOneWidget);
      expect(find.text('工人透明  |  工价透明  |  工艺透明  |  平台保障'), findsOneWidget);
      expect(find.text('开启安心装修之旅'), findsNothing);
      expect(find.byType(GestureDetector), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
