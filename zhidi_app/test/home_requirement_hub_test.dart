import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
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
  testWidgets('complete home page has no overflow at 320px', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = await OwnerAppState.memory();
    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(home: HomePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('工人知底'), findsOneWidget);
    expect(find.text('平台托底'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[320, 390]) {
    for (final textScale in <double>[1, 2]) {
      testWidgets(
        'requirement hub has no overflow at ${width}px and ${textScale}x text',
        (tester) async {
          await _pumpHome(tester, width: width, textScale: textScale);

          expect(find.text('立即找师傅'), findsOneWidget);
          expect(find.text('平均30分钟'), findsOneWidget);
          expect(find.text('装修找师傅，先知底再下单'), findsOneWidget);
          expect(find.text('看预算'), findsOneWidget);
          expect(find.text('托管下单'), findsOneWidget);
          expect(find.text('帮我选服务'), findsOneWidget);
          for (final service in <String>[
            '新房装修',
            '老房翻新',
            '局部改造',
            '找设计师',
            '验房收房',
          ]) {
            expect(find.text(service), findsAtLeastNWidgets(1));
          }
          expect(find.text('防水维修'), findsNothing);
          expect(find.text('更多服务'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('renovation scenario entries open their dedicated flows', (
    tester,
  ) async {
    await _pumpHome(tester, width: 390, textScale: 1);

    const scenarios = <String, String>{
      '新房装修': '新房装修流程',
      '老房翻新': '旧改流程',
      '局部改造': '局改需求',
      '找设计师': '设计师匹配',
      '验房收房': '验房服务',
    };

    for (final entry in scenarios.entries) {
      await tester.ensureVisible(find.text(entry.key));
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
    'new home renovation flow collects demand and opens budget result',
    (tester) async {
      await _pumpHome(tester, width: 390, textScale: 1);

      await tester.ensureVisible(find.text('新房装修'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('新房装修').first);
      await tester.pumpAndSettle();

      expect(find.text('新房装修流程'), findsOneWidget);
      expect(find.text('从毛坯到入住，一站式施工服务'), findsOneWidget);
      expect(find.text('第一步：房屋信息'), findsOneWidget);
      expect(find.text('请输入您的房屋情况'), findsOneWidget);
      expect(find.text('房屋面积：'), findsOneWidget);
      expect(find.text('50㎡以下'), findsOneWidget);
      expect(find.text('50-90㎡'), findsOneWidget);
      expect(find.text('90-120㎡'), findsOneWidget);
      expect(find.text('120㎡以上'), findsOneWidget);
      expect(find.text('房屋类型：'), findsOneWidget);
      expect(find.text('普通住宅'), findsOneWidget);
      expect(find.text('公寓'), findsOneWidget);
      expect(find.text('别墅'), findsOneWidget);

      await tester.ensureVisible(find.text('第二步：装修情况'));
      await tester.pumpAndSettle();

      expect(find.text('第二步：装修情况'), findsOneWidget);
      expect(find.text('装修阶段：'), findsOneWidget);
      expect(find.text('毛坯房'), findsOneWidget);
      expect(find.text('精装改造'), findsOneWidget);
      expect(find.text('装修档次：'), findsOneWidget);
      expect(find.text('简约实用'), findsOneWidget);
      expect(find.text('品质装修'), findsOneWidget);
      expect(find.text('高端装修'), findsOneWidget);
      expect(find.text('生成装修预算'), findsOneWidget);

      await tester.tap(find.text('90-120㎡'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('品质装修'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('生成装修预算'));
      await tester.pumpAndSettle();

      expect(find.text('知底装修预算报告'), findsOneWidget);
      expect(find.text('89㎡'), findsOneWidget);
      expect(find.text('毛坯房'), findsOneWidget);
      expect(find.text('¥58,260'), findsOneWidget);
    },
  );

  testWidgets('service consultant action opens AI consultant chat', (
    tester,
  ) async {
    await _pumpHome(tester, width: 390, textScale: 1);

    await tester.tap(find.text('帮我选服务'));
    await tester.pumpAndSettle();

    expect(find.text('AI装修顾问'), findsWidgets);
    expect(find.textContaining('您好，我是知底AI装修顾问'), findsOneWidget);
  });

  testWidgets('trust flow card appears before service scenarios', (
    tester,
  ) async {
    await _pumpHome(tester, width: 390, textScale: 1);

    final trustFlow = find.byKey(const Key('home-trust-flow-card'));
    expect(trustFlow, findsOneWidget);
    expect(find.text('装修找师傅，先知底再下单'), findsOneWidget);
    expect(find.text('先了解价格和标准，再选择师傅，最后通过平台验收付款'), findsOneWidget);

    final trustFlowTop = tester.getTopLeft(trustFlow).dy;
    final serviceTop = tester.getTopLeft(find.text('按需找服务')).dy;
    expect(trustFlowTop, lessThan(serviceTop));
  });

  testWidgets('trust flow steps open their owner decision pages', (
    tester,
  ) async {
    await _pumpHome(tester, width: 390, textScale: 1);

    final trustFlow = find.byKey(const Key('home-trust-flow-card'));

    const routes = <String, String>{
      '看预算': '新房装修流程',
      '看工价': '工价透明',
      '看标准': '施工标准',
      '找师傅': '找师傅',
      '托管下单': '资金银行托管',
    };

    for (final route in routes.entries) {
      final step = find.descendant(
        of: trustFlow,
        matching: find.text(route.key),
      );
      await tester.ensureVisible(step);
      await tester.pumpAndSettle();
      await tester.tap(step);
      await tester.pumpAndSettle();

      final destination = find.text(route.value);
      expect(destination, findsWidgets);

      Navigator.of(tester.element(destination.first)).pop();
      await tester.pumpAndSettle();
    }
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

    final copyRect = tester.getRect(find.text('匹配合适师傅'));
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

    final cardWidth = tester
        .getSize(find.byKey(const Key('home-hero-card')))
        .width;
    final actionWidth = tester
        .getSize(find.byKey(const Key('home-match-action')))
        .width;

    expect(actionWidth / cardWidth, inInclusiveRange(0.44, 0.49));
  });
}
