# Owner Home Visual Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refresh the owner-side `我的家` page so it feels like a warm, modern home-renovation project dashboard while preserving existing interactions and data semantics.

**Architecture:** Keep the current `MyHomePage` data flow and navigation intact, but refactor its presentation into a clearer visual system: a modern wood-toned Hero, lighter quick-action and progress components, and differentiated reminder/plan cards. Reuse `tokens.dart` where possible and add only the minimal new color/shadow/text tokens needed for this page so the refresh stays local and testable.

**Tech Stack:** Flutter, Material 3 widgets, `flutter_test`, existing `OwnerAppScope` / `OwnerAppState`, local design tokens in `zhidi_app/lib/design/tokens.dart`

## Global Constraints

- 不改变“我的家”页面核心信息架构和主要功能入口。
- 不新增后端能力，不改动页面承载的数据语义。
- 不重排主要功能顺序到影响既有测试路径的程度。
- 保留深色 Hero，并采用“现代木质感”家居氛围。
- Hero 不引入抢眼的明确家具主体，不依赖大型图片素材集。
- 橙色使用显著收敛，但关键动作仍然清晰。
- 不新增业务功能，不改变现有页面入口语义。
- 页面在手机宽度下无溢出，且关键交互路径保持可用。

---

## File Structure

- Modify: `zhidi_app/lib/design/tokens.dart`
  - Add page-safe neutral surfaces, warm Hero support colors, softer success/warning tints, and one lighter card shadow token so the refreshed page can stop hard-coding new values inline.
- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`
  - Keep state lookup, navigation, and section order.
  - Refactor visual constants and widgets for Hero, quick actions, progress, reminder, next-step, and shared card styling.
- Create: `zhidi_app/test/my_home_page_visual_test.dart`
  - Add regression tests for the refreshed Hero, visual hierarchy anchors, and no-overflow behavior on narrow widths.

## Task 1: Establish Visual Tokens And Test Harness

**Files:**
- Modify: `zhidi_app/lib/design/tokens.dart`
- Create: `zhidi_app/test/my_home_page_visual_test.dart`

**Interfaces:**
- Consumes: `OwnerAppState.memory({OwnerKeyValueStore? store})`, `OwnerAppScope`, `MyHomePage`
- Produces: `ZdColors.heroWoodDark`, `ZdColors.heroWoodMid`, `ZdColors.heroMist`, `ZdColors.surfaceWarm`, `ZdColors.surfaceMuted`, `ZdColors.successSoft`, `ZdColors.warningSoft`, `ZdShadow.cardSoft`

- [ ] **Step 1: Write the failing visual regression test harness**

```dart
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
}
```

- [ ] **Step 2: Run the new test to verify it fails**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter test test/my_home_page_visual_test.dart
```

Expected: FAIL with missing widget keys and/or missing `my-home-*` widgets.

- [ ] **Step 3: Add reusable warm-surface tokens**

```dart
abstract final class ZdColors {
  static const primary = Color(0xFFFF7A2F);
  static const primaryDark = Color(0xFFFF5A1F);

  static const background = Color(0xFFF7F4F0);
  static const surfaceWhite = Colors.white;
  static const surfaceWarm = Color(0xFFFFFCF8);
  static const surfaceMuted = Color(0xFFF4EFE8);
  static const cardBg = surfaceWarm;

  static const heroWoodDark = Color(0xFF2E241D);
  static const heroWoodMid = Color(0xFF4A3A30);
  static const heroMist = Color(0xFF6B7280);

  static const textPrimary = Color(0xFF1F1A17);
  static const textSecondary = Color(0xFF766B63);
  static const textHint = Color(0xFFB4AAA3);

  static const success = Color(0xFF34C759);
  static const successSoft = Color(0xFFE5F4EA);
  static const error = Color(0xFFFF3B30);
  static const warning = Color(0xFFFFCC00);
  static const warningSoft = Color(0xFFFFF1E3);
}

abstract final class ZdShadow {
  static const card = [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.06),
      blurRadius: 12,
      offset: Offset(0, 2),
    ),
  ];

  static const cardSoft = [
    BoxShadow(
      color: Color.fromRGBO(44, 30, 18, 0.08),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}
```

- [ ] **Step 4: Run analyzer on the touched files**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter analyze lib/design/tokens.dart test/my_home_page_visual_test.dart
```

Expected: PASS with `No issues found!`

- [ ] **Step 5: Commit the token and harness scaffolding**

```bash
git -C /Users/liupei/Documents/zhidi add zhidi_app/lib/design/tokens.dart zhidi_app/test/my_home_page_visual_test.dart
git -C /Users/liupei/Documents/zhidi commit -m "test(owner): add my home visual harness"
```

## Task 2: Rebuild The Hero And Quick Actions Hierarchy

**Files:**
- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`
- Test: `zhidi_app/test/my_home_page_visual_test.dart`

**Interfaces:**
- Consumes: `ZdColors.heroWoodDark`, `ZdColors.heroWoodMid`, `ZdColors.surfaceWarm`, `ZdShadow.cardSoft`
- Produces: `_HeroHeader` with `Key('my-home-hero')`, `_QuickActionsRow` with `Key('my-home-quick-actions')`, `_HeroAmbientPainter`

- [ ] **Step 1: Extend the test with Hero hierarchy checks**

```dart
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
```

- [ ] **Step 2: Run the targeted tests to verify they fail**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter test test/my_home_page_visual_test.dart --plain-name "hero"
```

Expected: FAIL because the keys, sizes, and hierarchy assertions are not implemented yet.

- [ ] **Step 3: Replace the current Hero with a warm layered version**

```dart
class _HeroHeader extends StatelessWidget {
  const _HeroHeader({
    required this.address,
    required this.projectName,
    required this.workerCount,
    required this.notificationCount,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('my-home-hero'),
      height: 228,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ZdColors.heroWoodDark,
            ZdColors.heroWoodMid,
            Color(0xFF5B5149),
            Color(0xFF3D4653),
          ],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _HeroAmbientPainter())),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.02),
                    Colors.black.withValues(alpha: 0.28),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '我的家',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    GestureDetector(
                      key: const Key('my-home-hero-bell'),
                      onTap: onNotificationTap,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(21),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(Icons.notifications_none, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  address,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      projectName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$workerCount位师傅',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Lighten the quick-actions card without changing its entry semantics**

```dart
class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.onPush});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Container(
        key: const Key('my-home-quick-actions'),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          color: ZdColors.surfaceWarm,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0E7DE)),
          boxShadow: ZdShadow.cardSoft,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _QuickItem(icon: Icons.house_siding_rounded, label: '施工进度', bgColor: const Color(0xFFFFF2E8), iconColor: ZdColors.primary),
            _QuickItem(icon: Icons.person_rounded, label: '我的工人', bgColor: const Color(0xFFFFF7EF), iconColor: const Color(0xFF9A6337)),
            _QuickItem(icon: Icons.notifications_none_rounded, label: '待处理', bgColor: const Color(0xFFFFF8F1), iconColor: ZdColors.primary, badge: '2'),
            _QuickItem(icon: Icons.receipt_long_rounded, label: '材料清单', bgColor: const Color(0xFFF8F2EA), iconColor: const Color(0xFF8A6B56)),
            _QuickItem(icon: Icons.shield_outlined, label: '平台保障', bgColor: const Color(0xFFF7F4EE), iconColor: const Color(0xFF7A6B5A)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the full visual test file and commit**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter test test/my_home_page_visual_test.dart
git -C /Users/liupei/Documents/zhidi add zhidi_app/lib/pages/home/my_home_page.dart zhidi_app/test/my_home_page_visual_test.dart
git -C /Users/liupei/Documents/zhidi commit -m "feat(owner): refresh my home hero hierarchy"
```

Expected: tests PASS, then commit succeeds.

## Task 3: Redesign Progress, Reminder, And Next-Step Cards

**Files:**
- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`
- Test: `zhidi_app/test/my_home_page_visual_test.dart`

**Interfaces:**
- Consumes: `_Phase`, `_PhaseStatus`, `ZdColors.successSoft`, `ZdColors.warningSoft`, `ZdShadow.cardSoft`
- Produces: `_ProgressBar` with `Key('my-home-progress-card')`, `_TodayReminderCard` with `Key('my-home-reminder-card')`, `_NextStepCard` with `Key('my-home-next-step-card')`

- [ ] **Step 1: Add layout and color differentiation tests for the three core cards**

```dart
testWidgets('core status cards stay ordered and vertically separated', (tester) async {
  await _pumpMyHome(tester, width: 390);

  final progress = tester.getTopLeft(find.byKey(const Key('my-home-progress-card')));
  final reminder = tester.getTopLeft(find.byKey(const Key('my-home-reminder-card')));
  final nextStep = tester.getTopLeft(find.byKey(const Key('my-home-next-step-card')));

  expect(progress.dy, lessThan(reminder.dy));
  expect(reminder.dy, lessThan(nextStep.dy));
});

testWidgets('narrow layout keeps refreshed cards overflow-free', (tester) async {
  await _pumpMyHome(tester, width: 320, textScale: 1.2);

  expect(find.byKey(const Key('my-home-progress-card')), findsOneWidget);
  expect(tester.takeException(), isNull);
});
```

- [ ] **Step 2: Run the targeted tests to verify they fail or expose current layout issues**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter test test/my_home_page_visual_test.dart --plain-name "core status"
```

Expected: FAIL because the keys do not exist yet and/or narrow layout still reflects the old styling.

- [ ] **Step 3: Rework the progress card into a lighter journey card**

```dart
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.phases});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Container(
        key: const Key('my-home-progress-card'),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        decoration: BoxDecoration(
          color: ZdColors.surfaceWarm,
          borderRadius: BorderRadius.circular(22),
          boxShadow: ZdShadow.cardSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '装修进度',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _textDark),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (int i = 0; i < phases.take(6).length; i++) ...[
                  _PhaseNode(phase: phases[i]),
                  if (i != phases.take(6).length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        color: phases[i].status == _PhaseStatus.done
                            ? const Color(0xFF9FD8AF)
                            : const Color(0xFFE9DED2),
                      ),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Re-style reminder and next-step as the emotional focus cards**

```dart
Widget _buildFocusCard({
  required Key key,
  required Color background,
  required Color iconTint,
  required Widget child,
}) {
  return Container(
    key: key,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(24),
      boxShadow: ZdShadow.cardSoft,
    ),
    child: child,
  );
}

// Inside _TodayReminderCard.build:
return Padding(
  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
  child: _buildFocusCard(
    key: const Key('my-home-reminder-card'),
    background: const Color(0xFFFFF6EA),
    iconTint: ZdColors.primary,
    child: ...
  ),
);

// Inside _NextStepCard.build:
return Padding(
  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
  child: _buildFocusCard(
    key: const Key('my-home-next-step-card'),
    background: const Color(0xFFF1F8F1),
    iconTint: const Color(0xFF2F8F57),
    child: ...
  ),
);
```

- [ ] **Step 5: Run focused tests, then commit**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter test test/my_home_page_visual_test.dart
git -C /Users/liupei/Documents/zhidi add zhidi_app/lib/pages/home/my_home_page.dart zhidi_app/test/my_home_page_visual_test.dart
git -C /Users/liupei/Documents/zhidi commit -m "feat(owner): soften my home status cards"
```

Expected: tests PASS, then commit succeeds.

## Task 4: Normalize The Remaining Cards And Run Final Verification

**Files:**
- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`
- Test: `zhidi_app/test/my_home_page_visual_test.dart`

**Interfaces:**
- Consumes: `ZdColors.surfaceWarm`, `ZdColors.surfaceMuted`, `ZdShadow.cardSoft`
- Produces: `_MaterialEstimatePanel`, `_WorkerCard`, `_ArchiveCard`, `_InspectionBanner` restyled to match the new page language without changing their callbacks

- [ ] **Step 1: Add one final regression test that guards the upper-screen hierarchy**

```dart
testWidgets('upper viewport shows home mood before extension content', (tester) async {
  await _pumpMyHome(tester, width: 390);

  final reminder = tester.getTopLeft(find.byKey(const Key('my-home-reminder-card')));
  final archiveText = tester.getTopLeft(find.text('装修档案'));

  expect(reminder.dy, lessThan(archiveText.dy));
});
```

- [ ] **Step 2: Run the single regression test to verify current layout before polishing**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter test test/my_home_page_visual_test.dart --plain-name "upper viewport"
```

Expected: PASS or FAIL is acceptable here; this is a guardrail test before the final polish pass.

- [ ] **Step 3: Unify lower cards with lighter surfaces and softer edges**

```dart
BoxDecoration _softCardDecoration() {
  return BoxDecoration(
    color: ZdColors.surfaceWarm,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFF1E8DE)),
    boxShadow: ZdShadow.cardSoft,
  );
}

// Apply _softCardDecoration() to:
// - _MaterialEstimatePanel outer container
// - _WorkerCard outer container
// - _ArchiveCard outer container
// - _InspectionBanner outer container
//
// Keep all current onTap / onPressed handlers unchanged.
```

- [ ] **Step 4: Run analyze and the full test suite that covers touched home UI**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter analyze lib/pages/home/my_home_page.dart lib/design/tokens.dart test/my_home_page_visual_test.dart
cd /Users/liupei/Documents/zhidi/zhidi_app && flutter test test/my_home_page_visual_test.dart test/home_requirement_hub_test.dart
```

Expected:

```text
No issues found!
All tests passed.
```

- [ ] **Step 5: Commit the final page polish**

```bash
git -C /Users/liupei/Documents/zhidi add zhidi_app/lib/pages/home/my_home_page.dart zhidi_app/lib/design/tokens.dart zhidi_app/test/my_home_page_visual_test.dart
git -C /Users/liupei/Documents/zhidi commit -m "feat(owner): complete my home visual refresh"
```

## Self-Review

- Spec coverage check:
  - Warm modern-wood Hero: covered by Task 2.
  - Reduced orange usage and softer surfaces: covered by Tasks 1, 2, and 4.
  - Distinct reminder / next-step emotional cards: covered by Task 3.
  - Lighter extension content and preserved interaction semantics: covered by Task 4.
- Placeholder scan:
  - No `TBD`, `TODO`, “implement later”, or undefined “add tests” language remains.
- Type consistency:
  - Tokens introduced in Task 1 are the same names consumed in Tasks 2 to 4.
  - Widget keys used in tests are the same keys produced in the implementation tasks.
