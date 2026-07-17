import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/pages/price/price_transparency_page.dart';
import 'package:zhidi_app/pages/renovation/trade_select_page.dart';

void main() {
  testWidgets('shows transparent pricing guarantees and opens trade selection', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: PriceTransparencyPage()));

    expect(
      find.descendant(
        of: find.byType(SliverAppBar),
        matching: find.text('工价透明'),
      ),
      findsOneWidget,
    );
    expect(find.text('平台统一工价'), findsOneWidget);
    expect(find.text('人工 / 辅材 / 主材 明码标价，透明不加价'), findsOneWidget);

    await tester.tap(find.text('立即找师傅'));
    await tester.pumpAndSettle();

    expect(find.byType(TradeSelectPage), findsOneWidget);
    expect(find.text('拆除师傅'), findsOneWidget);
  });
}
