import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/home/my_home_page.dart';

Future<void> _pumpMyHome(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final state = await OwnerAppState.memory();

  await tester.pumpWidget(
    OwnerAppScope(
      state: state,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const Scaffold(body: MyHomePage()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('my home page renders core refreshed sections', (tester) async {
    await _pumpMyHome(tester, width: 390);

    expect(find.byKey(const Key('my-home-hero')), findsOneWidget);
    expect(find.byKey(const Key('my-home-quick-actions')), findsOneWidget);
    expect(find.byKey(const Key('my-home-progress-card')), findsOneWidget);
    expect(find.byKey(const Key('my-home-reminder-card')), findsOneWidget);
    expect(find.byKey(const Key('my-home-next-step-card')), findsOneWidget);
  });

  testWidgets('hero keeps project title dominant over address', (tester) async {
    await _pumpMyHome(tester, width: 390);

    final title = tester.widget<Text>(find.text('全屋装修'));
    final address = tester.widget<Text>(find.text('金牛区 XX小区 3栋2单元'));

    expect(title.style?.fontSize, greaterThan(address.style?.fontSize ?? 0));
  });

  testWidgets('hero notification stays inside hero bounds', (tester) async {
    await _pumpMyHome(tester, width: 390);

    final heroRect = tester.getRect(find.byKey(const Key('my-home-hero')));
    final bellRect = tester.getRect(find.byKey(const Key('my-home-hero-bell')));

    expect(heroRect.contains(bellRect.topLeft), isTrue);
    expect(heroRect.contains(bellRect.bottomRight), isTrue);
  });

  testWidgets('core status cards stay ordered and vertically separated', (
    tester,
  ) async {
    await _pumpMyHome(tester, width: 390);

    final progress = tester.getTopLeft(find.byKey(const Key('my-home-progress-card')));
    final reminder = tester.getTopLeft(find.byKey(const Key('my-home-reminder-card')));
    final nextStep = tester.getTopLeft(find.byKey(const Key('my-home-next-step-card')));

    expect(progress.dy, lessThan(reminder.dy));
    expect(reminder.dy, lessThan(nextStep.dy));
  });

  testWidgets('narrow layout keeps refreshed cards overflow-free', (
    tester,
  ) async {
    await _pumpMyHome(tester, width: 320, textScale: 1.2);

    expect(find.byKey(const Key('my-home-progress-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
