# Strict Worker Selection Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a real-evidence “师傅严选” page and open it from the home page’s “工人严选” trust entry.

**Architecture:** Create one focused Flutter page that owns the trust explanation and a typed featured-worker record. Reuse the existing worker detail and worker list pages for navigation, and make the existing home trust tile accept an optional tap callback.

**Tech Stack:** Flutter, Dart, Material widgets, flutter_test.

---

### Task 1: Add navigation coverage

**Files:**
- Create: `zhidi_app/test/worker_selection_page_test.dart`
- Modify: `zhidi_app/lib/pages/home/home_page.dart`

- [ ] **Step 1: Write the failing home-entry test**

Pump `HomePage` with `OwnerAppScope`, scroll until `工人严选` is visible, tap the keyed entry, and assert that `WorkerSelectionPage` and the title `每一位师傅，都有证据可查` appear.

- [ ] **Step 2: Run the focused test to verify it fails**

Run: `flutter test test/worker_selection_page_test.dart`

Expected: FAIL because `WorkerSelectionPage` and the tappable entry do not exist.

- [ ] **Step 3: Make the trust tile tappable**

Import `worker/worker_selection_page.dart`, pass `onTap` only to the `工人严选` tile, add key `home-worker-selection-entry`, and push `const WorkerSelectionPage()`.

- [ ] **Step 4: Keep noninteractive trust tiles unchanged**

Extend `_TrustIndicator` with nullable `VoidCallback onTap`; use `InkWell` only when it is supplied so the other three indicators retain their current behavior.

### Task 2: Build the evidence page

**Files:**
- Create: `zhidi_app/lib/pages/home/worker/worker_selection_page.dart`
- Modify: `zhidi_app/test/worker_selection_page_test.dart`

- [ ] **Step 1: Add failing page-content tests**

Assert the page renders the hero, summary facts, one featured worker, five audit rows, platform promise, and bottom action without overflow at 320 px and 390 px widths.

- [ ] **Step 2: Add a typed featured-worker record**

Define an immutable private record containing the existing catalog worker identity: `worker-li-electrician`, `李师傅`, `水电师傅`, `18`, `326`, and `4.9`. Use those values everywhere in the page instead of duplicating strings across widgets.

- [ ] **Step 3: Implement the visual hierarchy**

Build a warm gradient hero, three-item evidence summary, featured worker card with verified chips, five compact audit rows, a dark platform-promise card, and safe-area-aware bottom action.

- [ ] **Step 4: Connect the featured worker**

Tap the worker card to push `WorkerDetailPage(workerId: 'worker-li-electrician', name: '李师傅', workerJob: '水电师傅')`.

- [ ] **Step 5: Connect the list action**

Tap `查看本地严选师傅` to push `const WorkerListPage()`.

### Task 3: Verify and finish

**Files:**
- Test: `zhidi_app/test/worker_selection_page_test.dart`
- Test: `zhidi_app/test/home_requirement_hub_test.dart`

- [ ] **Step 1: Format changed Dart files**

Run: `dart format lib/pages/home/home_page.dart lib/pages/home/worker/worker_selection_page.dart test/worker_selection_page_test.dart`

- [ ] **Step 2: Run focused tests**

Run: `flutter test test/worker_selection_page_test.dart test/home_requirement_hub_test.dart`

Expected: all tests pass with no overflow exceptions.

- [ ] **Step 3: Run static analysis**

Run: `flutter analyze lib/pages/home/home_page.dart lib/pages/home/worker/worker_selection_page.dart test/worker_selection_page_test.dart`

Expected: no errors.

