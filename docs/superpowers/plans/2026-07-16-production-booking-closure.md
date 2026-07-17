# Production Booking Closure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the owner Android app, worker Android app, and Alibaba Cloud Spring Boot/MySQL deployment complete one truthful, recoverable booking-and-acceptance flow.

**Architecture:** Spring Boot/MySQL becomes the single source of truth for remote bookings. Booking rows carry owner/worker display snapshots, both Flutter roles persist authenticated sessions, and remote failures remain visible instead of falling back to fake success. Production is upgraded with additive Flyway migration, database/jar backups, atomic jar replacement, health gates, and rollback.

**Tech Stack:** Java 21, Spring Boot 3.5, Spring Data JPA, Spring Security, Flyway, MySQL 8, Flutter/Dart, `flutter_secure_storage`, Android flavors, systemd.

## Global Constraints

- Existing user changes in the dirty worktree must not be reset or deleted unless they directly conflict with the production booking flow.
- Remote booking state comes only from Spring Boot/MySQL; authenticated production views may not present Mock orders as server orders.
- Production remains `http://47.109.0.191:8080` for this iteration; document but do not conceal the plaintext HTTP risk.
- Production schema changes use Flyway only; Hibernate uses `ddl-auto=validate`.
- Never print JWTs, database passwords, SMS secrets, or private keys into logs or documentation.
- Every behavior change follows red-green-refactor and must have a failing test before production code changes.
- Do not commit, push, or create a PR unless the user explicitly requests it.

---

### Task 1: Booking owner snapshot and Flyway migration

**Files:**
- Create: `zhidi_server/src/main/resources/db/migration/V7__booking_owner_snapshot.sql`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/Booking.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingResponse.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingService.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/booking/BookingServiceIntegrationTest.java`

**Interfaces:**
- Consumes: authenticated `ownerUserId`, `UserRepository.findById(UUID)`, `OwnerProfileRepository.findByUserId(UUID)`.
- Produces: `Booking.create(UUID ownerUserId, String ownerName, String ownerPhone, UUID workerUserId, String workerName, ...)` and `BookingResponse.ownerName()/ownerPhone()`.

- [ ] **Step 1: Write a failing integration test for snapshot creation**

Add a test that creates an owner account/profile and complete worker profile, calls `BookingService.create`, and asserts `ownerName` equals the profile name and `ownerPhone` equals the account phone.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
cd zhidi_server
MAVEN_USER_HOME=../.m2 ./mvnw -Dtest=BookingServiceIntegrationTest test -Dmaven.repo.local=../.m2/repository -s ../.m2/settings.xml
```

Expected: compilation or assertion failure because `BookingResponse` does not expose owner snapshot fields.

- [ ] **Step 3: Add the additive schema migration**

Create nullable `owner_name VARCHAR(80)` and `owner_phone VARCHAR(32)` columns, backfill `owner_phone` from `users.phone`, backfill `owner_name` from `owner_profiles.name` with `'业主'` fallback, then make both columns non-null.

- [ ] **Step 4: Implement snapshot persistence and response mapping**

Inject `UserRepository` and `OwnerProfileRepository` into `BookingService`; resolve the owner account/profile at booking creation; store immutable snapshot fields on `Booking`; include them in `BookingResponse`.

- [ ] **Step 5: Run the focused test and verify GREEN**

Run the command from Step 2. Expected: all `BookingServiceIntegrationTest` tests pass.

### Task 2: Repair backend controller and migration test baseline

**Files:**
- Modify: `zhidi_server/src/test/java/com/zhidi/server/booking/BookingControllerTest.java`
- Modify: backend controller tests that exclude JPA but fail on new repository-backed services
- Modify: `zhidi_server/src/main/resources/application-prod.yml`
- Test: `zhidi_server/src/test/java/com/zhidi/server/ZhidiServerApplicationTests.java`

**Interfaces:**
- Consumes: expanded `BookingResponse` constructor.
- Produces: isolated web tests that supply all repository/service dependencies and production configuration with Flyway enabled and Hibernate validation.

- [ ] **Step 1: Update expected controller contract before production changes**

Change controller fixtures/assertions to require `$.data.ownerName` and `$.data.ownerPhone`; add the missing mocked repository bean that currently prevents ApplicationContext startup.

- [ ] **Step 2: Run controller tests and verify RED for the expanded contract**

```bash
cd zhidi_server
MAVEN_USER_HOME=../.m2 ./mvnw -Dtest=BookingControllerTest test -Dmaven.repo.local=../.m2/repository -s ../.m2/settings.xml
```

Expected: failure until all response fixtures and dependencies use the new contract.

- [ ] **Step 3: Complete fixtures and production schema settings**

Set production Flyway enabled and JPA `ddl-auto: validate`; update all `BookingResponse` construction sites with owner snapshot fields; mock newly discovered repository beans in isolated tests instead of disabling unrelated application services.

- [ ] **Step 4: Run backend booking tests and then the full backend suite**

```bash
cd zhidi_server
MAVEN_USER_HOME=../.m2 ./mvnw test -Dmaven.repo.local=../.m2/repository -s ../.m2/settings.xml
```

Expected: zero failures/errors.

### Task 3: Worker API model and truthful remote-order mapping

**Files:**
- Modify: `zhidi_app/lib/services/worker_booking_api_client.dart`
- Modify: `zhidi_app/lib/app/worker_app_state.dart`
- Test: `zhidi_app/test/worker_booking_api_client_test.dart`
- Test: `zhidi_app/test/worker_booking_flow_test.dart`

**Interfaces:**
- Consumes: response JSON fields `ownerName`, `ownerPhone`, `traceId`.
- Produces: `RemoteWorkerBooking.ownerName`, `ownerPhone`; remote `WorkerOrder` populated with real owner identity; explicit fetch/action error state.

- [ ] **Step 1: Write failing parsing and state tests**

Require worker booking JSON parsing to reject missing `ownerName`/`ownerPhone`; require remote order mapping to display the supplied name/phone; require failed accept/reject to leave status unchanged and expose an error message.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd zhidi_app
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/worker_booking_api_client_test.dart test/worker_booking_flow_test.dart
```

Expected: failures because current mapping hardcodes `'业主'` and an empty phone and does not expose errors.

- [ ] **Step 3: Implement new fields and explicit remote operation state**

Parse owner identity; map it into `WorkerOrder`; retain remote order status on failure; add state fields/getters for loading and last error; clear error only on a subsequent successful operation.

- [ ] **Step 4: Keep authenticated production orders separate from Mock data**

When a valid remote session exists, construct the online orders view from remote bookings and do not mix local demo orders into it. Retain demo data only for unauthenticated/offline demonstration mode.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run Step 2 command. Expected: all focused tests pass.

### Task 4: Persist and restore the worker session

**Files:**
- Create: `zhidi_app/lib/services/worker_auth_session_store.dart`
- Modify: `zhidi_app/lib/main.dart`
- Modify: `zhidi_app/lib/pages/worker/worker_login_page.dart`
- Modify: `zhidi_app/lib/app/worker_app_state.dart`
- Test: `zhidi_app/test/worker_auth_session_store_test.dart`
- Test: `zhidi_app/test/worker_app_startup_test.dart`

**Interfaces:**
- Consumes: `WorkerLoginResponse` access token, expiry, user ID, phone, roles.
- Produces: `WorkerAuthSessionStore.read/save/clear`, startup routing based on valid unexpired session, and logout/session-invalid clearing.

- [ ] **Step 1: Write failing storage and startup tests**

Test JSON round-trip, corrupt/expired session rejection, successful cold-start API initialization, and 401 session clearing.

- [ ] **Step 2: Run tests and verify RED**

```bash
cd zhidi_app
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/worker_auth_session_store_test.dart test/worker_app_startup_test.dart
```

Expected: files/types do not exist or startup returns to login.

- [ ] **Step 3: Implement secure session persistence**

Use a worker-specific secure-storage key, save only after server login succeeds, restore before `runApp`, initialize booking/report clients with the restored token, and clear invalid sessions.

- [ ] **Step 4: Remove fake-success worker login behavior**

Do not navigate to the worker home when server authentication/profile publication fails. Surface the `AuthApiException.message`, preserve form input, and allow retry.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run Step 2 command. Expected: all tests pass.

### Task 5: Owner booking synchronization and visible errors

**Files:**
- Modify: `zhidi_app/lib/services/owner_booking_api_client.dart`
- Modify: `zhidi_app/lib/app/owner_app_state.dart`
- Modify: `zhidi_app/lib/pages/order/my_orders_page.dart`
- Modify: remote booking entry pages under `zhidi_app/lib/pages/home/worker/`
- Test: `zhidi_app/test/owner_booking_api_client_test.dart`
- Test: `zhidi_app/test/owner_booking_state_sync_test.dart`
- Test: `zhidi_app/test/worker_detail_remote_booking_test.dart`
- Test: `zhidi_app/test/worker_list_booking_flow_test.dart`

**Interfaces:**
- Consumes: owner booking statuses and API trace IDs.
- Produces: stable server-ID merge, exhaustive status mapping, explicit loading/error/retry UI, and success navigation only after server success.

- [ ] **Step 1: Write/repair failing behavior tests**

Require one logical session lookup per booking operation, no local mutation on failed remote create, correct mapping for all four statuses, stable deduplication, visible fetch failure, and current UI copy rather than obsolete `'找拆除师傅'` text.

- [ ] **Step 2: Run focused tests and verify RED**

```bash
cd zhidi_app
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/owner_booking_api_client_test.dart test/owner_booking_state_sync_test.dart test/worker_detail_remote_booking_test.dart test/worker_list_booking_flow_test.dart
```

Expected: current JWT-read assertion/status/UI failures reproduce.

- [ ] **Step 3: Implement deterministic owner synchronization**

Read the valid session once per operation; use `rm-<server-id>` consistently; replace remote rows by server ID; map unknown status to an explicit unsupported/error state rather than pending; retain current data when refresh fails.

- [ ] **Step 4: Add loading, error, and retry presentation**

Render progress during refresh, a retry action with the backend message on failure, and do not show booking success until remote create returns `OK`.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run Step 2 command. Expected: all focused tests pass.

### Task 6: Full local verification and Android artifacts

**Files:**
- Modify only files implicated by failing tests/analyzer findings in the booking closure scope
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- Consumes: completed backend and Flutter changes.
- Produces: green full suites, owner/worker debug or release APKs configured for production API, and an updated factual project status.

- [ ] **Step 1: Run backend full suite**

```bash
cd zhidi_server
MAVEN_USER_HOME=../.m2 ./mvnw test -Dmaven.repo.local=../.m2/repository -s ../.m2/settings.xml
```

- [ ] **Step 2: Run Flutter analyzer and full suite**

```bash
cd zhidi_app
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter analyze
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test
```

- [ ] **Step 3: Build both Android flavors for production endpoint**

```bash
cd zhidi_app
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter build apk --debug --flavor owner --dart-define=ZHIDI_APP_FLAVOR=owner --dart-define=API_BASE_URL=http://47.109.0.191:8080
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter build apk --debug --flavor worker --dart-define=ZHIDI_APP_FLAVOR=worker --dart-define=API_BASE_URL=http://47.109.0.191:8080
```

- [ ] **Step 4: Update project status with verified facts only**

Record the new response fields, session behavior, test results, remaining HTTP/security risks, and whether Android visual E2E is complete.

### Task 7: Back up and deploy the backend to ECS

**Files:**
- Build: `zhidi_server/target/zhidi-server-0.0.1-SNAPSHOT.jar`
- Remote backup: `/opt/zhidi/backups/<timestamp>/`
- Remote deploy: `/opt/zhidi/zhidi-server.jar`

**Interfaces:**
- Consumes: green local build and existing `/opt/zhidi/.env` without printing secrets.
- Produces: upgraded `zhidi.service`, applied V7 migration, rollback artifacts, and healthy production API.

- [ ] **Step 1: Inspect production database name and migration history without exposing credentials**

Source `/opt/zhidi/.env` inside the SSH shell, derive the DB name from `DB_URL`, and query only migration version/description/success.

- [ ] **Step 2: Create database, jar, env, and unit backups**

Use `umask 077`, `mysqldump --single-transaction --routines --triggers`, and timestamped copies. Verify files are non-empty before deployment.

- [ ] **Step 3: Build and upload the jar to a temporary path**

```bash
cd zhidi_server
MAVEN_USER_HOME=../.m2 ./mvnw clean package -Dmaven.repo.local=../.m2/repository -s ../.m2/settings.xml
```

Compare local and remote SHA-256.

- [ ] **Step 4: Atomically replace and restart**

Move the verified temporary jar into place, restart `zhidi.service`, and poll `/actuator/health` for at most 60 seconds while inspecting journal errors.

- [ ] **Step 5: Verify migration and API contract or roll back**

Confirm V7 success and owner fields in booking responses. If startup/health/schema validation fails, restore the previous jar and restart immediately; retain the additive columns.

### Task 8: Android production end-to-end closure

**Files:**
- Install artifacts from `zhidi_app/build/app/outputs/flutter-apk/`
- No source changes unless a newly reproduced defect first receives a failing automated test

**Interfaces:**
- Consumes: healthy production API and both production-configured APKs.
- Produces: evidence that both Android apps share the same online booking and session after force-stop/restart.

- [ ] **Step 1: Stabilize ADB and install both distinct application IDs**

Verify `adb devices`, restart only the ADB server if necessary, then install owner and worker APKs. If the emulator transport remains broken, restart the emulator without wiping its data.

- [ ] **Step 2: Create dedicated production test accounts through the apps**

Complete worker profile and owner profile with identifiable test values; do not reuse ordinary user accounts.

- [ ] **Step 3: Execute the visual booking flow**

Owner finds the worker, creates a booking, worker refreshes and sees owner name/phone/address, worker accepts, owner refreshes and sees confirmed.

- [ ] **Step 4: Force-stop and restart both apps**

Verify worker and owner sessions restore and both apps read the same accepted booking from production.

- [ ] **Step 5: Cross-check MySQL and collect non-secret evidence**

Query only booking ID, participant IDs, display names, status, and timestamps. Capture screenshots without tokens or passwords.

- [ ] **Step 6: Run final health and regression checks**

Re-run production health, focused smoke requests, backend full suite, Flutter full suite, and `git status --short`; report all remaining gaps without claiming completion for anything not directly observed.
