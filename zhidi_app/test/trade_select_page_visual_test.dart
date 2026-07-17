import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/pages/renovation/trade_select_page.dart';

void main() {
  testWidgets('trade cards show renovation sequence badges in process order', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: TradeSelectPage()));
    await tester.pumpAndSettle();

    expect(find.text('拆除师傅'), findsOneWidget);
    expect(find.text('水电师傅'), findsOneWidget);
    expect(find.text('防水师傅'), findsOneWidget);
    expect(find.text('泥瓦师傅'), findsOneWidget);
    expect(find.text('第一步'), findsOneWidget);
    expect(find.text('第二步'), findsOneWidget);
    expect(find.text('第三步'), findsOneWidget);
    expect(find.text('第四步'), findsOneWidget);
    expect(find.text('报价'), findsOneWidget);
    expect(find.text('第五步'), findsOneWidget);
    expect(find.text('第六步'), findsOneWidget);
    expect(find.text('第七步'), findsOneWidget);
    expect(find.text('第八步'), findsOneWidget);
  });
}
