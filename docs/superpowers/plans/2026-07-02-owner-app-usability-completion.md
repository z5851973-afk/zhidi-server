# Owner App Usability Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the Flutter owner app into a locally persistent, fully navigable MVP with no visible dead interactions.

**Architecture:** Add a single app-scoped `OwnerAppState` backed by a replaceable key-value store, then expose focused feature pages that mutate state through explicit methods. Existing large pages retain their visual structure but delegate navigation and state to the new app layer.

**Tech Stack:** Flutter, Dart, `ChangeNotifier`, `shared_preferences`, `flutter_test`

---

### Task 1: Repair the Test Baseline and App State Bootstrap

**Files:**
- Modify: `zhidi_app/pubspec.yaml`
- Create: `zhidi_app/lib/app/owner_app_state.dart`
- Create: `zhidi_app/lib/app/owner_app_scope.dart`
- Modify: `zhidi_app/lib/main.dart`
- Replace: `zhidi_app/test/widget_test.dart`

- [ ] **Step 1: Write a failing app-shell test**

Replace the obsolete counter test with a test that pumps `ZhidiApp(state: OwnerAppState.memory())`, verifies the four tab labels, taps “我的”, and expects the profile name “王先生”.

- [ ] **Step 2: Verify the test fails**

Run: `../flutter/bin/flutter test test/widget_test.dart`
Expected: FAIL because `OwnerAppState.memory` and the injected `state` constructor do not exist.

- [ ] **Step 3: Add persistence dependency and app state boundary**

Add `shared_preferences: ^2.5.3`. Implement `OwnerAppState extends ChangeNotifier` with `memory()` and async `load()` constructors, a `ready` flag, and focused mutation methods. Implement `OwnerAppScope extends InheritedNotifier<OwnerAppState>` with `of(context)`.

- [ ] **Step 4: Bootstrap state before rendering feature pages**

Update `main()` to load state, pass it into `ZhidiApp`, and wrap `MaterialApp` with `OwnerAppScope`. Add a compact loading scaffold while state is unavailable.

- [ ] **Step 5: Run the baseline test**

Run: `../flutter/bin/flutter test test/widget_test.dart`
Expected: PASS.

### Task 2: Define Persistent Owner, Address, Project, Message, Favorite, and Settings Data

**Files:**
- Create: `zhidi_app/lib/app/owner_models.dart`
- Modify: `zhidi_app/lib/app/owner_app_state.dart`
- Test: `zhidi_app/test/owner_app_state_test.dart`

- [ ] **Step 1: Write failing state tests**

Cover default profile/city, add-edit-delete address, mark-one/mark-all message read, toggle favorite, complete reminder, submit feedback, update settings, JSON round-trip, and preservation after creating a second state instance over the same memory store.

- [ ] **Step 2: Verify state tests fail**

Run: `../flutter/bin/flutter test test/owner_app_state_test.dart`
Expected: FAIL because models and mutation methods are missing.

- [ ] **Step 3: Implement immutable serializable models**

Define `OwnerProfile`, `OwnerAddress`, `OwnerProject`, `OwnerReminder`, `OwnerMessage`, `FavoriteWorker`, `OwnerSettings`, `AfterSalesRequest`, and `FeedbackEntry`, each with `toJson`, `fromJson`, and the required `copyWith` methods.

- [ ] **Step 4: Implement default data and mutations**

Seed Chengdu-consistent demo data dated relative to 2026, persist one JSON document after every mutation, and call `notifyListeners()` only after state changes.

- [ ] **Step 5: Run state tests**

Run: `../flutter/bin/flutter test test/owner_app_state_test.dart`
Expected: PASS.

### Task 3: Build the Complete “我的” Hub

**Files:**
- Create: `zhidi_app/lib/pages/profile/profile_page.dart`
- Create: `zhidi_app/lib/pages/profile/edit_profile_page.dart`
- Create: `zhidi_app/lib/pages/profile/profile_components.dart`
- Modify: `zhidi_app/lib/pages/home/home_page.dart`
- Test: `zhidi_app/test/profile_page_test.dart`

- [ ] **Step 1: Write failing profile navigation tests**

Verify the A-layout profile header, “我的预约 / 在线咨询 / 我的收藏 / 平台客服”, and “地址管理 / 保障与售后 / 帮助与反馈 / 设置”. Verify tapping each item pushes a route instead of remaining on the hub.

- [ ] **Step 2: Verify the tests fail**

Run: `../flutter/bin/flutter test test/profile_page_test.dart`
Expected: FAIL because `ProfilePage` does not exist.

- [ ] **Step 3: Implement the profile hub and editable header**

Build the confirmed orange profile card and two white sections. Edit profile must validate a non-empty display name and city and save through `OwnerAppState`.

- [ ] **Step 4: Replace the placeholder fourth tab**

Replace `Text('我的')` in `HomePage` with `const ProfilePage()` and preserve tab state through the existing `IndexedStack`.

- [ ] **Step 5: Run profile tests**

Run: `../flutter/bin/flutter test test/profile_page_test.dart`
Expected: PASS.

### Task 4: Build Address, Support, Feedback, and Settings Pages

**Files:**
- Create: `zhidi_app/lib/pages/profile/address_page.dart`
- Create: `zhidi_app/lib/pages/profile/support_page.dart`
- Create: `zhidi_app/lib/pages/profile/feedback_page.dart`
- Create: `zhidi_app/lib/pages/profile/settings_page.dart`
- Test: `zhidi_app/test/profile_management_test.dart`

- [ ] **Step 1: Write failing management-flow tests**

Test adding/editing/deleting an address, submitting an after-sales request, submitting feedback with validation, and toggling notification/privacy settings.

- [ ] **Step 2: Verify the tests fail**

Run: `../flutter/bin/flutter test test/profile_management_test.dart`
Expected: FAIL because the pages are missing.

- [ ] **Step 3: Implement address management**

Provide list, empty state, create/edit form, default-address selection, phone validation with `^1\d{10}$`, and delete confirmation.

- [ ] **Step 4: Implement support and feedback**

Show platform guarantees as explanatory content, list submitted after-sales items, validate issue type/description, and save requests locally. Feedback must accept category and description and show a success result.

- [ ] **Step 5: Implement settings**

Provide notification and privacy switches, clear demo cache confirmation, About/Privacy detail sheets, and persist switch state.

- [ ] **Step 6: Run management tests**

Run: `../flutter/bin/flutter test test/profile_management_test.dart`
Expected: PASS.

### Task 5: Make Appointments and Favorites Rediscoverable

**Files:**
- Modify: `zhidi_app/lib/pages/order/order_store.dart`
- Modify: `zhidi_app/lib/pages/order/create_order_page.dart`
- Modify: `zhidi_app/lib/pages/order/my_orders_page.dart`
- Modify: `zhidi_app/lib/pages/home/worker/worker_detail_page.dart`
- Create: `zhidi_app/lib/pages/profile/favorites_page.dart`
- Test: `zhidi_app/test/order_and_favorite_test.dart`

- [ ] **Step 1: Write failing order and favorite tests**

Create an appointment, return to the profile hub, open “我的预约”, and verify it remains visible. Toggle favorite on worker detail and verify the worker appears/disappears in “我的收藏”.

- [ ] **Step 2: Verify the tests fail**

Run: `../flutter/bin/flutter test test/order_and_favorite_test.dart`
Expected: FAIL because orders use process-only static storage and worker favorite state is absent.

- [ ] **Step 3: Move appointments into app state**

Replace direct `OrderStore.orders` access with state-backed appointment methods while keeping `OrderItem` serialization. Add status presentation and a useful empty-state button that returns owners to worker discovery.

- [ ] **Step 4: Add worker favorite action**

Add a bookmark action to `WorkerDetailPage`, save the worker name/job/city, and update its selected state through `OwnerAppState`.

- [ ] **Step 5: Implement favorites page**

Show saved workers with open-detail and remove actions plus an empty state that navigates to worker discovery.

- [ ] **Step 6: Run order and favorite tests**

Run: `../flutter/bin/flutter test test/order_and_favorite_test.dart`
Expected: PASS.

### Task 6: Complete Message Search, Read State, Categories, and Detail Routing

**Files:**
- Modify: `zhidi_app/lib/pages/message/message_page.dart`
- Create: `zhidi_app/lib/pages/message/notification_detail_page.dart`
- Test: `zhidi_app/test/message_page_test.dart`

- [ ] **Step 1: Write failing message tests**

Verify keyword search, unread filter, category filter, single-row read state, “全部已读”, worker-to-chat navigation, and system-to-detail navigation.

- [ ] **Step 2: Verify the tests fail**

Run: `../flutter/bin/flutter test test/message_page_test.dart`
Expected: FAIL because search/category/row/mark-all handlers are empty.

- [ ] **Step 3: Bind the message page to app state**

Replace mock lists with `OwnerMessage` values, implement a real search field, combine text/category/unread filters, and expose a “暂无匹配消息” empty state.

- [ ] **Step 4: Implement message routing and read mutations**

Mark a row read before navigation. Route human conversations to `ChatPage`; route system/order/work-order notices to `NotificationDetailPage` with time, content, and related action summary.

- [ ] **Step 5: Run message tests**

Run: `../flutter/bin/flutter test test/message_page_test.dart`
Expected: PASS.

### Task 7: Complete “我的家” Project Operations

**Files:**
- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`
- Create: `zhidi_app/lib/pages/project/project_pages.dart`
- Test: `zhidi_app/test/my_home_page_test.dart`

- [ ] **Step 1: Write failing project-operation tests**

Verify project switch/edit, member list, group chat, project settings, reminder completion, next-plan detail, all-workers, inspection history, archive, escrow explanation, sharing feedback, and after-sales navigation.

- [ ] **Step 2: Verify the tests fail**

Run: `../flutter/bin/flutter test test/my_home_page_test.dart`
Expected: FAIL because the visible handlers are empty.

- [ ] **Step 3: Implement focused project pages**

Create reusable scaffold-based pages for project selection, edit form, members, next plan, workers, inspections, archives, escrow explanation, and settings. Reuse `ChatPage` for project group chat and `SupportPage` for after-sales.

- [ ] **Step 4: Bind the dashboard to state**

Replace hard-coded project/date/reminder values with selected-project state. Complete reminders through state and remove them from the pending count. Wire every visible handler to a route, mutation, share action, or SnackBar.

- [ ] **Step 5: Run project-operation tests**

Run: `../flutter/bin/flutter test test/my_home_page_test.dart`
Expected: PASS.

### Task 8: Remove Remaining Dead Interactions and Data Contradictions

**Files:**
- Modify: `zhidi_app/lib/pages/home/home_page.dart`
- Modify: `zhidi_app/lib/pages/home/worker/worker_detail_page.dart`
- Modify: `zhidi_app/lib/pages/renovation/team_summary_page.dart`
- Modify: any `zhidi_app/lib/**.dart` file reported by the dead-handler scan
- Test: `zhidi_app/test/navigation_smoke_test.dart`

- [ ] **Step 1: Add navigation smoke coverage**

Exercise all top-level service cards and primary CTAs and assert each produces a route, dialog, state change, or feedback surface.

- [ ] **Step 2: Scan for dead handlers**

Run: `rg -n "onTap: \(\) \{\}|onPressed: \(\) \{\}" lib`
Expected: Matches identify every remaining empty handler.

- [ ] **Step 3: Implement or remove every visible dead control**

Wire valid controls to their intended routes/actions. Remove controls whose promised capability is outside scope. Replace hard-coded Shenzhen service text and stale dates with the selected city and current project data.

- [ ] **Step 4: Re-run the scan and smoke test**

Run: `rg -n "onTap: \(\) \{\}|onPressed: \(\) \{\}" lib || true`
Expected: No matches.

Run: `../flutter/bin/flutter test test/navigation_smoke_test.dart`
Expected: PASS.

### Task 9: Full Verification and Mobile Walkthrough

**Files:**
- Modify only files required by verification findings

- [ ] **Step 1: Format and analyze**

Run: `../flutter/bin/dart format lib test`

Run: `../flutter/bin/flutter analyze`
Expected: No errors.

- [ ] **Step 2: Run the complete suite**

Run: `../flutter/bin/flutter test`
Expected: All tests pass.

- [ ] **Step 3: Run at a 390×844 mobile viewport**

Start Flutter Web, open the app in the in-app browser, and walk through home → worker → appointment → profile orders; messages search/read/detail; project reminders/inspection; address/support/feedback/settings.

- [ ] **Step 4: Check rendering and logs**

Verify no overflow stripes, obscured primary buttons, stale city/date content, or browser console errors. Fix any findings and repeat Steps 1–3.

- [ ] **Step 5: Record completion evidence**

Capture the exact analyze/test results and list the verified owner journeys in the final handoff.
