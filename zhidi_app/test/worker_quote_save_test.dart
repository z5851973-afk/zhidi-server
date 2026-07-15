import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/data/price_standards.dart';
import 'package:zhidi_app/pages/price/worker_quote_page.dart';
import 'package:zhidi_app/pages/profile/favorites_page.dart';

void main() {
  testWidgets('worker quote page saves a quote into favorites', (tester) async {
    final state = await OwnerAppState.memory();

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: MaterialApp(
          home: WorkerQuotePage(workerName: '李师傅', trade: demolitionTrade),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('价高再考虑'));
    await tester.pumpAndSettle();

    expect(state.savedQuotes, hasLength(1));
    expect(state.savedQuotes.single.workerName, '李师傅');
    expect(state.savedQuotes.single.tradeName, '拆除');
    expect(state.savedQuotes.single.items.first.name, '12墙拆除');
    expect(state.savedQuotes.single.grandTotal, greaterThan(0));
    expect(find.text('已收藏，可在"我的收藏"页面查看'), findsOneWidget);

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(home: FavoritesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('报价收藏（1）'), findsOneWidget);
    expect(find.text('李师傅  ·  拆除'), findsOneWidget);
    expect(find.text('12墙拆除'), findsOneWidget);
  });
}
