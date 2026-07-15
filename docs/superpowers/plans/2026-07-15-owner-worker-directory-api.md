# Owner Worker Directory API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the Android owner-side worker list/detail chain prefer Spring Boot worker directory data while keeping local Mock data as a safe fallback.

**Architecture:** Add a focused Flutter API client for `GET /api/v1/workers` and `GET /api/v1/workers/{userId}`. Convert remote workers into the existing `Worker`/`WorkerDetail` presentation models so current UI and booking behavior stay intact.

**Tech Stack:** Flutter, Dart, `package:http`, existing Spring Boot API envelope, existing `WorkerListPage` and renovation `WorkerDetailPage`.

## Global Constraints

- Android owner app is the current delivery target; do not treat iOS as a completion target.
- Keep the change narrow: no address work, no booking backend, no Firestore migration, no unrelated UI cleanup.
- Backend data is preferred, but network failure or empty backend data must not blank the page.
- Do not expose worker phone numbers.

---

### Task 1: Worker directory API client

**Files:**
- Create: `zhidi_app/lib/services/worker_directory_api_client.dart`
- Test: `zhidi_app/test/worker_directory_api_client_test.dart`

**Interfaces:**
- Produces: `WorkerDirectoryApi.listWorkers()`, `WorkerDirectoryApi.getWorker(String userId)`, `RemoteWorkerDirectoryProfile`.

- [ ] Write failing tests for parsing list/detail envelopes, backend errors, malformed data, timeout, and connection failure.
- [ ] Run `HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/worker_directory_api_client_test.dart` and confirm the new file is missing.
- [ ] Implement the API client with the same error model as `OwnerProfileApiClient`.
- [ ] Run the same test and confirm it passes.

### Task 2: Worker list uses backend data first

**Files:**
- Modify: `zhidi_app/lib/pages/home/worker/worker_list_page.dart`
- Test: add coverage in `zhidi_app/test/worker_directory_api_client_test.dart` only if pure mapping is extracted; otherwise run existing worker list/widget tests after implementation.

**Interfaces:**
- Consumes: `RemoteWorkerDirectoryProfile.toWorker(...)`.
- Produces: list page merges Mock + Firestore + Spring Boot workers by ID, with remote workers overriding matching IDs.

- [ ] Add minimal conversion from remote profile to existing `Worker`.
- [ ] Load remote workers in `initState` and when trade changes.
- [ ] Filter by selected `Trade`.
- [ ] Preserve current fallback behavior when remote call fails or returns no matching workers.

### Task 3: Worker detail can display remote profile fields

**Files:**
- Modify: `zhidi_app/lib/pages/renovation/worker_detail_page.dart`
- Modify: `zhidi_app/lib/pages/home/worker/worker_list_page.dart`

**Interfaces:**
- Consumes: optional remote worker fields passed from list page.
- Produces: detail page shows remote name, trade, experience, city, bio/daily rate when present.

- [ ] Pass selected remote-backed worker data into detail navigation.
- [ ] Resolve detail from passed worker data before falling back to local `_allWorkers`/`mockWorkers`.
- [ ] Keep existing favorite, booking, quote, and share behavior working.

### Task 4: Verification and status

**Files:**
- Modify: `PROJECT_STATUS.md`

- [ ] Update project status only after tests prove the integration.
- [ ] Run focused Flutter tests for the new API client and affected worker flow.
- [ ] Run `git status --short` and stage only relevant files.
