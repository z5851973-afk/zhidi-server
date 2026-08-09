import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/pages/price/price_transparency_page.dart';
import 'package:zhidi_app/pages/renovation/trade_select_page.dart';

void main() {
  testWidgets('labels local reference prices and opens trade selection', (
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
    expect(find.text('参考工价说明'), findsOneWidget);
    expect(find.text('页面仅说明本地参考口径，最终以服务器报价清单和现场工程量为准'), findsOneWidget);
    expect(find.textContaining('不代表当前服务端目录'), findsOneWidget);
    expect(find.textContaining('固定工价目录'), findsNothing);
    expect(find.textContaining('银行监管'), findsNothing);
    expect(find.textContaining('师傅认证'), findsNothing);
    expect(find.textContaining('线上签约托管'), findsNothing);

    await tester.tap(find.text('立即找师傅'));
    await tester.pumpAndSettle();

    expect(find.byType(TradeSelectPage), findsOneWidget);
    expect(find.text('拆除师傅'), findsOneWidget);
  });
}
