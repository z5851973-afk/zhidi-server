import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/app/owner_app_scope.dart';
import 'package:zhidi_app/app/owner_app_state.dart';
import 'package:zhidi_app/pages/profile/favorites_page.dart';

void main() {
  test(
    'saved quotes persist and latest quote replaces same worker trade',
    () async {
      final store = MemoryOwnerStore();
      final state = await OwnerAppState.memory(store: store);

      await state.addSavedQuote(_quote(id: 'quote-old', total: 1200));
      await state.addSavedQuote(_quote(id: 'quote-new', total: 1680));

      expect(state.savedQuotes, hasLength(1));
      expect(state.savedQuotes.single.id, 'quote-new');
      expect(state.savedQuotes.single.grandTotal, 1680);

      final restored = await OwnerAppState.memory(store: store);
      expect(restored.savedQuotes, hasLength(1));
      expect(
        restored.savedQuotes.single.toJson(),
        state.savedQuotes.single.toJson(),
      );
    },
  );

  testWidgets('favorites page shows and removes saved quotes', (tester) async {
    final state = await OwnerAppState.memory();
    await state.addSavedQuote(
      _quote(
        id: 'quote-ui',
        total: 1980,
        items: const [
          QuoteLineItem(
            name: '墙面找平',
            categoryName: '泥工',
            unitPrice: 60,
            unit: '/㎡',
            quantity: 18,
          ),
          QuoteLineItem(
            name: '瓷砖铺贴',
            categoryName: '泥工',
            unitPrice: 90,
            unit: '/㎡',
            quantity: 10,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      OwnerAppScope(
        state: state,
        child: const MaterialApp(home: FavoritesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('报价收藏（1）'), findsOneWidget);
    expect(find.text('李师傅  ·  泥工'), findsOneWidget);
    expect(find.text('墙面找平'), findsOneWidget);
    expect(find.text('¥1980'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(state.savedQuotes, isEmpty);
    expect(find.text('暂无收藏'), findsOneWidget);
  });
}

SavedQuote _quote({
  required String id,
  required double total,
  List<QuoteLineItem> items = const [
    QuoteLineItem(
      name: '水电开槽',
      categoryName: '水电',
      unitPrice: 40,
      unit: '/米',
      quantity: 30,
    ),
  ],
}) => SavedQuote(
  id: id,
  workerName: '李师傅',
  tradeName: '泥工',
  items: items,
  grandTotal: total,
  savedAt: DateTime(2026, 7, 15, 10, 30),
);
