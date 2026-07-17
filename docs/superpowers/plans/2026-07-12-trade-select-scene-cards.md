# Trade Select Scene Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the TradeSelectPage cards so each trade reads as a construction scene card without the current overlapping custom cue layer.

**Architecture:** Keep the existing TradeSelectPage structure, grid, card layout, navigation, and worker count logic. Update the card data to point at clearer scene-oriented assets where available, remove the custom painter overlay, and keep only the clipped photo, bottom readability gradient, text, and small top-right icon badge.

**Tech Stack:** Flutter, Dart, flutter_test, existing local image assets.

## Global Constraints

- Only modify the find-master trade card visual implementation and its focused test.
- Do not modify homepage, worker list page, price pages, budget logic, order logic, or navigation behavior.
- Preserve current card dimensions, grid layout, search bar, copy, rounded card style, and Zhidi visual language.
- All decoration must remain clipped inside each card.

---

### Task 1: Lock The Regression Test

**Files:**
- Modify: `zhidi_app/test/trade_select_page_visual_test.dart`
- Test: `zhidi_app/test/trade_select_page_visual_test.dart`

**Interfaces:**
- Consumes: `TradeSelectPage`
- Produces: a widget test that fails while `trade-scene-cue-*` widgets still exist and passes after they are removed.

- [ ] **Step 1: Write the failing test**

Replace the existing test with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhidi_app/models/renovation.dart';
import 'package:zhidi_app/pages/renovation/trade_select_page.dart';

void main() {
  testWidgets('trade cards render as clipped scene photo cards without overlay cues', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: TradeSelectPage()));
    await tester.pumpAndSettle();

    expect(find.text('拆除工'), findsOneWidget);
    expect(find.text('水电工'), findsOneWidget);
    expect(find.text('泥瓦工'), findsOneWidget);
    expect(find.text('防水工'), findsOneWidget);

    for (final trade in Trade.values) {
      expect(find.byKey(Key('trade-scene-cue-${trade.name}')), findsNothing);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd zhidi_app && flutter test test/trade_select_page_visual_test.dart`

Expected: FAIL because existing cards still include at least one `trade-scene-cue-*` widget.

### Task 2: Remove The Overlapping Cue Layer

**Files:**
- Modify: `zhidi_app/lib/pages/renovation/trade_select_page.dart`
- Test: `zhidi_app/test/trade_select_page_visual_test.dart`

**Interfaces:**
- Consumes: `_TradeCardData`, `_TradeCard`
- Produces: clipped scene photo cards that no longer build `_TradeSceneCue` or `_TradeSceneCuePainter`.

- [ ] **Step 1: Write minimal implementation**

In `_TradeCardData`, remove `sceneColor` and keep `imageAlignment`. Update data rows so `photoAsset` can use existing scene-oriented `*_banner.jpg` assets where they better match the trade.

In `_TradeCard.build`, delete the `Positioned.fill(child: _TradeSceneCue(...))` block.

Delete `_TradeSceneCue` and `_TradeSceneCuePainter`.

Keep `_TradeCueBadge`, but change it to derive a local icon color from the trade instead of reading `data.sceneColor`.

- [ ] **Step 2: Run focused test**

Run: `cd zhidi_app && flutter test test/trade_select_page_visual_test.dart`

Expected: PASS.

- [ ] **Step 3: Run analysis**

Run: `cd zhidi_app && flutter analyze lib/pages/renovation/trade_select_page.dart test/trade_select_page_visual_test.dart`

Expected: exit code 0.

### Task 3: Format And Review Diff

**Files:**
- Modify: `zhidi_app/lib/pages/renovation/trade_select_page.dart`
- Modify: `zhidi_app/test/trade_select_page_visual_test.dart`

**Interfaces:**
- Consumes: changed Dart files from Tasks 1 and 2
- Produces: formatted Dart and a scoped diff.

- [ ] **Step 1: Format**

Run: `cd zhidi_app && dart format lib/pages/renovation/trade_select_page.dart test/trade_select_page_visual_test.dart`

Expected: formatter completes successfully.

- [ ] **Step 2: Review scoped diff**

Run: `git diff -- zhidi_app/lib/pages/renovation/trade_select_page.dart zhidi_app/test/trade_select_page_visual_test.dart`

Expected: diff only removes the overlapping cue layer, updates image asset choices, updates the badge color source, and updates the focused test.
