# Owner Completed Request Label Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show “已完成” on an owner service-request card when its selected worker booking is `COMPLETED`.

**Architecture:** Derive one display status from the request and its candidate bookings inside `my_home_page.dart`. Reuse that derived status for both the card label and color without mutating remote models or backend state.

**Tech Stack:** Flutter, Dart, `flutter_test`

## Global Constraints

- Do not modify or deploy the backend.
- Preserve all unrelated dirty-worktree changes.
- Do not commit unless the user explicitly requests it.

---

### Task 1: Derive the completed status for the service-request card

**Files:**
- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`
- Test: `zhidi_app/test/my_home_minimal_page_test.dart`
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- Consumes: `RemoteServiceRequest.status` and `RemoteServiceRequest.candidates[*].status`
- Produces: `String _serviceRequestCardStatus(RemoteServiceRequest request)`

- [ ] **Step 1: Write the failing Widget test**

Add a service request fixture whose request status is `WORKER_SELECTED` and candidate status is `COMPLETED`. Assert that “已完成” is present and “已选定” is absent inside the rendered requirements section.

- [ ] **Step 2: Run the focused test and verify RED**

Run: `flutter test test/my_home_minimal_page_test.dart --plain-name 'completed candidate marks its decoration requirement completed'`

Expected: FAIL because the card currently reads only `request.status` and renders “已选定”.

- [ ] **Step 3: Implement the minimal display-status helper**

Add `_serviceRequestCardStatus` returning `COMPLETED` when any non-cancelled candidate is `COMPLETED`, otherwise returning `request.status`. Use the result for `_ServiceRequestCard` label and color.

- [ ] **Step 4: Verify GREEN and regression safety**

Run:

```text
flutter test test/my_home_minimal_page_test.dart
flutter analyze
```

Expected: all tests pass and analyzer reports no issues.

- [ ] **Step 5: Build and visually verify**

Build the owner debug APK with `API_BASE_URL=http://47.109.0.191:8080`, preserve app data during installation on `Zhidi_API35`, and verify the completed woodworking requirement card displays “已完成”.

- [ ] **Step 6: Update project status**

Record the verified behavior, test result, APK installation and evidence path in `PROJECT_STATUS.md`. Do not commit.
