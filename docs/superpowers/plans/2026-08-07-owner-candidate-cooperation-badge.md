# Owner Candidate Cooperation Badge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a green “已合作” trust label only when the current owner has a prior finalized booking with the listed worker, while preserving repeat invitations.

**Architecture:** Reuse `ServiceRequestApi.listOwnerRequests(accessToken)` inside the candidate picker, derive a set of prior partner `workerUserId` values from non-current requests, and pass a boolean into each candidate card. History loading is an optional enhancement: directory loading and candidate actions remain usable if history loading fails.

**Tech Stack:** Flutter, Dart, Widget tests, existing REST API clients.

## Global Constraints

- Do not infer owner-specific cooperation from the public directory `hiredCount`.
- A prior candidate counts as cooperation only for `READY_TO_START`, `HIRED`, or `COMPLETED`.
- Exclude candidates belonging to the current `serviceRequestId`.
- Preserve the “加入候选” action for prior partners.
- Do not modify or deploy the backend.
- Preserve all unrelated uncommitted workspace changes and do not create a Git commit.

---

### Task 1: Lock the relationship rule with Widget regressions

**Files:**
- Modify: `zhidi_app/test/candidate_picker_page_test.dart`

**Interfaces:**
- Consumes: `CandidatePickerPage.serviceRequestApi`, `ServiceRequestApi.listOwnerRequests(String)`.
- Produces: test fixtures that return owner service-request history and observable card assertions keyed by worker ID.

- [ ] **Step 1: Extend the service-request HTTP fake**

Make `mockServiceRequestApi` accept `ownerRequests` and return the full envelope for `GET /api/v1/owners/me/service-requests`:

```dart
if (request.method == 'GET' &&
    url.contains('/api/v1/owners/me/service-requests')) {
  return http.Response(
    jsonEncode({'code': 'OK', 'message': 'success', 'data': ownerRequests}),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}
```

Pass the fixture through `buildPage(ownerRequests: ...)`.

- [ ] **Step 2: Write the failing prior-partner test**

Create a historical request whose candidate is `worker-a`, whose request ID differs from `request-1`, and whose status is `COMPLETED`. Locate `Key('candidate-worker-worker-a')` and assert that its descendants contain “已合作”, do not contain “3次被选中”, and still contain an enabled “加入候选”. Tap that button and assert it becomes “已加入”.

- [ ] **Step 3: Write the failing boundary tests**

Use literal fixtures to verify:

```text
READY_TO_START -> 已合作
HIRED          -> 已合作
COMPLETED      -> 已合作
PENDING        -> not 已合作
REJECTED       -> not 已合作
current request COMPLETED -> not 已合作
```

The existing `hiredCount: 3` assertion remains and proves a platform-wide count alone does not create the owner-specific badge.

- [ ] **Step 4: Run the focused test and verify RED**

Run:

```bash
cd zhidi_app
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/candidate_picker_page_test.dart
```

Expected: failure because candidate cards do not expose the stable worker key and do not render “已合作”.

---

### Task 2: Derive and render prior cooperation

**Files:**
- Modify: `zhidi_app/lib/pages/home/worker/candidate_picker_page.dart`
- Test: `zhidi_app/test/candidate_picker_page_test.dart`

**Interfaces:**
- Consumes: `RemoteServiceRequest.id`, `RemoteServiceRequest.candidates`, `RemoteCandidateBooking.workerUserId`, and `RemoteCandidateBooking.status`.
- Produces: `_cooperatedWorkerIds: Set<String>` and `_CandidateItem.hasCooperated`.

- [ ] **Step 1: Add isolated history loading**

Start `_loadCooperationHistory()` from `initState` alongside `_loadWorkers()`. Fetch owner requests, skip `request.id == widget.requestId`, normalize status with `toUpperCase()`, and add the candidate ID only when it is in:

```dart
const {'READY_TO_START', 'HIRED', 'COMPLETED'}
```

Catch history errors without changing `_loadingWorkers` or `_error`, so the directory still works.

- [ ] **Step 2: Pass the relationship into the card**

Add:

```dart
hasCooperated: _cooperatedWorkerIds.contains(worker.userId),
```

Give the card root `Key('candidate-worker-${worker.userId}')` for stable behavior-level assertions.

- [ ] **Step 3: Render the relationship label**

Add `hasCooperated` to `_CandidateItem`. When true, replace the global count pill with a green “已合作” pill; otherwise retain `_hiredPillLabel`. Extend `_TrustPill` with a boolean success style while leaving all button state logic unchanged.

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the same focused Flutter test. Expected: all candidate-picker tests pass without warnings or pending timers.

---

### Task 3: Verify integration and record the capability

**Files:**
- Modify: `PROJECT_STATUS.md`
- Verify: `zhidi_app/lib/pages/home/worker/candidate_picker_page.dart`
- Verify: `zhidi_app/test/candidate_picker_page_test.dart`

**Interfaces:**
- Consumes: completed Task 1 and Task 2 behavior.
- Produces: current project status and an installable owner debug APK.

- [ ] **Step 1: Run focused and adjacent checks**

```bash
cd zhidi_app
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/candidate_picker_page_test.dart test/worker_directory_api_client_test.dart
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter analyze
```

- [ ] **Step 2: Update project status**

Record only verified facts: current-owner history drives “已合作”, current request is excluded, repeat invitation remains available, history failure degrades safely, and no backend deployment was required.

- [ ] **Step 3: Build the owner APK**

```bash
cd zhidi_app
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter build apk --debug --flavor owner --dart-define=API_BASE_URL=http://47.109.0.191:8080
```

- [ ] **Step 4: Install and visually verify**

Install the generated owner APK with `adb install -r`, preserve app data, reopen the candidate picker, and confirm the known historical worker displays “已合作” while “加入候选” remains available. Capture a screenshot under `zhidi_app/output/evidence/` and check runtime logs for Flutter exceptions or layout overflow.
