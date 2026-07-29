# Candidate Worker Profile Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let owners inspect each real worker profile and cases before adding up to three candidates, then finish selection and return to the owner project flow with a refresh result.

**Architecture:** Extend `CandidatePickerPage` with a typed completion result and real-detail navigation. Reuse the existing production `WorkerDetailPage`, adding an optional candidate-selection mode so normal direct booking remains unchanged. Keep server responses authoritative and propagate completion to `TradeSelectPage`/the owner shell instead of creating local bookings.

**Tech Stack:** Flutter, Dart, Spring Boot REST clients already in the repository, `flutter_test` Widget tests.

## Global Constraints

- Android is the only client acceptance target.
- Candidate list, worker profile, cases, and candidate mutation must use Spring Boot APIs; no Mock, Picsum, Firestore, or local fake success in production routes.
- A service request accepts at most three distinct workers.
- Existing direct worker-detail booking behavior outside candidate mode must remain unchanged.
- Do not commit, push, or deploy without explicit user authorization.

---

### Task 1: Candidate card opens the real worker profile

**Files:**
- Modify: `zhidi_app/lib/pages/home/worker/candidate_picker_page.dart`
- Modify: `zhidi_app/lib/pages/renovation/worker_detail_page.dart`
- Test: `zhidi_app/test/candidate_picker_page_test.dart`

**Interfaces:**
- Consumes: `RemoteWorkerDirectoryProfile`, `WorkerCaseApi`, existing `WorkerDetailPage.remoteProfile`.
- Produces: optional `WorkerDetailPage.candidateSelected` and `WorkerDetailPage.onAddCandidate` inputs used only by the candidate flow.

- [ ] **Step 1: Write the failing Widget test**

Add a test that taps `张师傅`, expects `WorkerDetailPage` content including `十年水电经验`, and verifies the detail was constructed with the same remote `userId`.

- [ ] **Step 2: Run the focused test and verify it fails**

Run: `flutter test test/candidate_picker_page_test.dart`

Expected: FAIL because the candidate card has no detail navigation.

- [ ] **Step 3: Add detail navigation and candidate-mode inputs**

Make `_CandidateItem` accept `VoidCallback onView`, wrap only the card's information surface in an accessible tap target, and push:

```dart
WorkerDetailPage(
  workerName: worker.name,
  remoteProfile: worker,
  candidateSelected: _isCandidate(worker.userId),
  onAddCandidate: () => _addCandidate(worker),
)
```

In `WorkerDetailPage`, when `onAddCandidate != null`, replace “立即预约师傅” with “添加为候选” or “已添加候选”; keep profile and public-case loading unchanged.

- [ ] **Step 4: Run focused tests**

Run: `flutter test test/candidate_picker_page_test.dart test/owner_worker_cases_test.dart`

Expected: PASS.

### Task 2: Enforce three candidates and synchronize detail/list state

**Files:**
- Modify: `zhidi_app/lib/pages/home/worker/candidate_picker_page.dart`
- Modify: `zhidi_app/lib/pages/renovation/worker_detail_page.dart`
- Test: `zhidi_app/test/candidate_picker_page_test.dart`

**Interfaces:**
- Consumes: `Future<bool> Function()` candidate callback from Task 1.
- Produces: `_candidateIds` as the single UI selection source and `bool` callback result indicating server-confirmed addition.

- [ ] **Step 1: Write failing tests**

Cover: adding from detail updates the list badge/header after pop; a selected worker is not posted twice; after three successful candidates, remaining add buttons are disabled while cards remain viewable.

- [ ] **Step 2: Verify tests fail**

Run: `flutter test test/candidate_picker_page_test.dart`

Expected: FAIL on callback synchronization and three-worker limit.

- [ ] **Step 3: Implement server-authoritative selection**

Change `_addCandidate` to `Future<bool>`. Return `true` only after `addCandidate` succeeds, return `false` on failure, and guard:

```dart
if (_candidateIds.contains(uid)) return true;
if (_candidateIds.length >= 3) {
  _showError('最多选择 3 位候选师傅');
  return false;
}
```

Await the detail callback, set its local selected state only on `true`, and refresh the parent card state when returning.

- [ ] **Step 4: Run focused tests**

Run: `flutter test test/candidate_picker_page_test.dart`

Expected: PASS.

### Task 3: Complete selection and refresh My Home

**Files:**
- Modify: `zhidi_app/lib/pages/home/worker/candidate_picker_page.dart`
- Modify: `zhidi_app/lib/pages/renovation/trade_select_page.dart`
- Modify: `zhidi_app/lib/pages/home/home_page.dart`
- Test: `zhidi_app/test/candidate_picker_page_test.dart`
- Test: `zhidi_app/test/home_requirement_hub_test.dart`
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- Produces: `CandidatePickerResult({required String requestId, required Set<String> candidateIds})`.
- Consumes: owner-shell tab selection/refresh callback already used when returning from requirement creation.

- [ ] **Step 1: Write failing completion tests**

Verify the fixed bottom action reads `完成选择（已选 1/3）`, is disabled at zero, and pops a `CandidatePickerResult` containing `request-1` after one server-confirmed add.

- [ ] **Step 2: Verify tests fail**

Run: `flutter test test/candidate_picker_page_test.dart test/home_requirement_hub_test.dart`

Expected: FAIL because no completion action/result exists.

- [ ] **Step 3: Implement typed completion and navigation propagation**

Add:

```dart
class CandidatePickerResult {
  const CandidatePickerResult({required this.requestId, required this.candidateIds});
  final String requestId;
  final Set<String> candidateIds;
}
```

Render the action above the system safe area. Pop the typed result, propagate it through `TradeSelectPage`, switch the owner shell to “我的家”, and trigger its existing server refresh path. Do not create local appointments.

- [ ] **Step 4: Run focused and regression verification**

Run:

```bash
flutter test test/candidate_picker_page_test.dart test/home_requirement_hub_test.dart test/owner_worker_cases_test.dart
flutter analyze
git diff --check
```

Expected: all tests PASS, analysis reports no issues, diff check is clean.

- [ ] **Step 5: Build and visually verify Android owner APK**

Run:

```bash
flutter build apk --debug --flavor owner \
  --dart-define=ZHIDI_APP_FLAVOR=owner \
  --dart-define=API_BASE_URL=http://47.109.0.191:8080
```

Install with `adb install -r`, then verify: card opens correct real profile/cases, detail add synchronizes, fourth worker cannot be added, and completion reaches “我的家” with the same request.

- [ ] **Step 6: Update project status**

Record only the tests and Android flow actually verified in `PROJECT_STATUS.md`; do not mark true-device validation complete unless it was performed.
