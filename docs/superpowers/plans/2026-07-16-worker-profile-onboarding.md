# Worker Profile Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Require workers with incomplete server profiles to save full real profiles before entering the worker home screen.

**Architecture:** Extend the shared worker profile model with the fields already supported by the backend, save through the authenticated REST API before mutating local state, and route from login to a reusable profile form until the server completeness contract is satisfied.

**Tech Stack:** Flutter/Dart, Spring Boot 3.5, JPA, JUnit/MockMvc, Flutter widget tests.

## Global Constraints

- Android is the delivery target.
- ECS REST API and MySQL are the source of truth.
- Phone is read-only and comes from the authenticated account.
- No existing user changes are discarded or committed automatically.

---

### Task 1: Align backend profile completeness

**Files:**
- Modify: `zhidi_server/src/main/java/com/zhidi/server/worker/WorkerProfileService.java`
- Modify: `zhidi_server/src/test/java/com/zhidi/server/worker/WorkerProfileControllerTest.java`

**Interfaces:**
- Consumes: `PUT /api/v1/workers/me` and `WorkerProfileRequest`.
- Produces: `WorkerProfileResponse.profileComplete()` that is true only when name, city, trade, years, daily rate, and bio are present.

- [x] Write a service unit test showing an otherwise complete profile without `bio` remains incomplete.
- [x] Run the focused test and confirm it fails because `profileComplete` is true.
- [x] Add city and bio to `WorkerProfileService.toResponse` completeness validation.
- [x] Run the focused backend tests and confirm they pass.

### Task 2: Save the complete profile through REST

**Files:**
- Modify: `zhidi_app/lib/app/worker_models.dart`
- Modify: `zhidi_app/lib/app/worker_app_state.dart`
- Modify: `zhidi_app/lib/services/auth_api_client.dart`
- Modify: `zhidi_app/test/worker_session_state_test.dart`

**Interfaces:**
- Consumes: `OwnerAuthApi.updateWorkerProfile(token, body)` and `RemoteWorkerProfile`.
- Produces: `WorkerProfile.serviceCity`, `dailyRate`, `isProfileComplete`, and `WorkerAppState.updateProfile(value, api:)`.

- [x] Write a state test asserting the REST body contains all six fields and local state updates only after success.
- [x] Run the test and confirm it fails for missing model fields/API behavior.
- [x] Extend remote/local profile mapping and make authenticated save precede local mutation.
- [x] Run worker state and login tests and confirm they pass.

### Task 3: Gate first login with the reusable profile page

**Files:**
- Modify: `zhidi_app/lib/main.dart`
- Modify: `zhidi_app/lib/pages/worker/worker_profile_page.dart`
- Create: `zhidi_app/test/worker_profile_onboarding_test.dart`

**Interfaces:**
- Consumes: `WorkerProfile.isProfileComplete` and `WorkerAppState.updateProfile`.
- Produces: worker route selection and a validated profile form with `onCompleted`.

- [x] Write widget tests for incomplete-profile routing and successful completion.
- [x] Run the widget test and confirm it fails because the current app opens the home page.
- [x] Add form fields, validation, read-only phone, online save, and routing.
- [x] Run the focused widget tests and confirm they pass.

### Task 4: Verify and document

**Files:**
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- Consumes: completed implementation and test evidence.
- Produces: accurate current project status.

- [x] Run the Docker-free focused Spring service test; record that the existing controller suite is blocked by its missing `DailyReportRepository` test mock and MySQL integration tests require Docker Desktop.
- [x] Run focused Flutter tests.
- [x] Run `flutter analyze`.
- [x] Update `PROJECT_STATUS.md` only with verified facts.
