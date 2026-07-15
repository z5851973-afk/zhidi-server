import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/pages/price/price_transparency_page.dart';

void main() {
  testWidgets('opens a trade price standard page from transparent pricing', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PriceTransparencyPage()));

    expect(find.text('工价透明'), findsOneWidget);
    expect(find.text('平台统一人工参考价'), findsOneWidget);
    expect(find.text('拆除'), findsOneWidget);
    expect(find.text('水电'), findsOneWidget);

    await tester.tap(find.text('拆除'));
    await tester.pumpAndSettle();

    expect(find.text('拆除工价标准'), findsOneWidget);
    expect(find.text('墙体拆除'), findsOneWidget);
    expect(find.text('12墙拆除'), findsOneWidget);
    expect(find.text('¥45/㎡'), findsOneWidget);
  });
}
