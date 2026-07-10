import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/pages/home/home_page.dart';

Future<void> _pumpHome(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const Scaffold(
        body: SingleChildScrollView(child: HomeRequirementHub()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in <double>[320, 390]) {
    for (final textScale in <double>[1, 2]) {
      testWidgets(
        'requirement hub has no overflow at ${width}px and ${textScale}x text',
        (tester) async {
          await _pumpHome(tester, width: width, textScale: textScale);

          expect(find.text('立即匹配工人'), findsOneWidget);
          expect(find.text('平均30分钟'), findsOneWidget);
          expect(find.text('帮我选服务'), findsOneWidget);
          for (final service in <String>[
            '全屋装修',
            '旧房改造',
            '局部改造',
            '防水维修',
            '验房收房',
            '更多服务',
          ]) {
            expect(find.text(service), findsAtLeastNWidgets(1));
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('service consultant action opens AI consultant chat', (
    tester,
  ) async {
    await _pumpHome(tester, width: 390, textScale: 1);

    await tester.tap(find.text('帮我选服务'));
    await tester.pumpAndSettle();

    expect(find.text('AI装修顾问'), findsWidgets);
    expect(find.textContaining('您好，我是知底AI装修顾问'), findsOneWidget);
  });

  testWidgets('hero worker image is visually prominent', (tester) async {
    await _pumpHome(tester, width: 390, textScale: 1);

    final workerImage = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/images/worker_confident.png',
    );

    expect(workerImage, findsOneWidget);
    final image = tester.widget<Image>(workerImage);
    expect(image.width, greaterThanOrEqualTo(86));
    expect(image.height, greaterThanOrEqualTo(92));
  });

  testWidgets('statistics panel stays visually compact', (tester) async {
    await _pumpHome(tester, width: 390, textScale: 1);

    final panel = find.byKey(const Key('home-stats-panel'));
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).height, lessThanOrEqualTo(200));
  });

  testWidgets('hero copy and worker form one visual group', (tester) async {
    await _pumpHome(tester, width: 390, textScale: 1);

    final copyRect = tester.getRect(find.text('匹配合适工人'));
    final worker = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName ==
              'assets/images/worker_confident.png',
    );
    final workerRect = tester.getRect(worker);

    expect(workerRect.left - copyRect.right, lessThanOrEqualTo(48));
  });

  testWidgets('hero action does not visually span the whole card', (
    tester,
  ) async {
    await _pumpHome(tester, width: 390, textScale: 1);

    final cardWidth = tester.getSize(find.byKey(const Key('home-hero-card'))).width;
    final actionWidth = tester.getSize(find.byKey(const Key('home-match-action'))).width;

    expect(actionWidth / cardWidth, inInclusiveRange(0.62, 0.72));
  });
}
