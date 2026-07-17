# Service Request Candidates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build phase A of the approved design: one owner service request can contain at most three private candidate-worker bookings, and either participant can cancel a booking before on-site with an audited reason.

**Architecture:** Add a `servicerequest` Spring package as the owner-visible aggregate and link every booking to it through V10. Preserve `POST /api/v1/bookings` as the first-candidate compatibility path, add owner-only candidate APIs, and keep worker responses limited to the worker's own booking. Flutter gains a focused service-request client and renders real candidate groups in “我的家”; existing local state remains only as a presentation cache for data returned by the server.

**Tech Stack:** Java 21, Spring Boot 3.5, Spring Data JPA, Spring Security, Flyway, MySQL 8, Flutter/Dart, `package:http`, Flutter widget tests.

## Global Constraints

- Android is the current delivery target.
- ECS REST API and MySQL are the source of truth.
- One service request permits at most 3 active candidate bookings.
- Only the owner sees all candidates; a worker sees only their own booking.
- Owner and worker cancellation requires a non-blank reason and is allowed only before `ON_SITE`.
- Existing production bookings must be backfilled without deletion.
- Existing unrelated user changes are preserved and no Git commit is created automatically.
- Every server mutation must succeed before Flutter shows a success state.

---

### Task 1: V10 service-request persistence and production-safe backfill

**Files:**
- Create: `zhidi_server/src/main/resources/db/migration/V10__service_requests_and_candidate_bookings.sql`
- Create: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestStatus.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestRepository.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/Booking.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingStatus.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingRepository.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/servicerequest/ServiceRequestPersistenceTest.java`

**Interfaces:**
- Produces: `ServiceRequest.create(UUID ownerUserId, String trade, String city, String address, String remark)`.
- Produces: `Booking.createCandidate(ServiceRequest request, UUID ownerUserId, String ownerName, String ownerPhone, UUID workerUserId, String workerName)`.
- Produces: `BookingRepository.countActiveCandidates(UUID serviceRequestId, Collection<BookingStatus> terminalStatuses)` through an explicit JPQL query.

- [ ] **Step 1: Write the failing persistence test**

Create a MySQL/Testcontainers test that persists one service request with two candidate bookings and verifies both bookings share the same request ID, then verifies the V10 schema columns exist.

```java
@Test
void persistsMultipleCandidateBookingsUnderOneRequest() {
    ServiceRequest request = requests.saveAndFlush(ServiceRequest.create(
        owner.getId(), "plumbing", "成都", "高新区 1 号", "旧房水电改造"));
    bookings.saveAndFlush(Booking.createCandidate(request, owner.getId(),
        "林业主", owner.getPhone(), firstWorker.getId(), "张师傅"));
    bookings.saveAndFlush(Booking.createCandidate(request, owner.getId(),
        "林业主", owner.getPhone(), secondWorker.getId(), "王师傅"));

    assertThat(bookings.findByServiceRequestIdOrderByCreatedAtAsc(request.getId()))
        .extracting(Booking::getWorkerUserId)
        .containsExactly(firstWorker.getId(), secondWorker.getId());
}
```

- [ ] **Step 2: Run the test and confirm the missing schema/types fail**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw \
  -Dtest=ServiceRequestPersistenceTest test \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

Expected: compilation fails because `ServiceRequest` and V10 do not exist.

- [ ] **Step 3: Add the V10 migration**

The migration must create and backfill in this order so `service_request_id` is never orphaned:

```sql
CREATE TABLE service_requests (
  id BINARY(16) PRIMARY KEY,
  owner_user_id BINARY(16) NOT NULL,
  trade VARCHAR(40) NOT NULL,
  service_city VARCHAR(80) NOT NULL,
  service_address VARCHAR(200) NULL,
  remark VARCHAR(500) NULL,
  status VARCHAR(32) NOT NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  INDEX idx_service_requests_owner_created (owner_user_id, created_at),
  CONSTRAINT fk_service_requests_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
  CONSTRAINT ck_service_requests_status
    CHECK (status IN ('OPEN', 'COMPARING', 'WORKER_SELECTED', 'CANCELLED'))
);

ALTER TABLE bookings
  ADD COLUMN service_request_id BINARY(16) NULL AFTER id,
  ADD COLUMN cancelled_by VARCHAR(16) NULL,
  ADD COLUMN cancel_reason VARCHAR(300) NULL,
  ADD COLUMN cancelled_at DATETIME(6) NULL;

INSERT INTO service_requests
  (id, owner_user_id, trade, service_city, service_address, remark,
   status, version, created_at, updated_at)
SELECT id, owner_user_id, trade, service_city, service_address, remark,
       'OPEN', 0, created_at, updated_at
FROM bookings;

UPDATE bookings SET service_request_id = id WHERE service_request_id IS NULL;

ALTER TABLE bookings
  MODIFY service_request_id BINARY(16) NOT NULL,
  ADD CONSTRAINT fk_bookings_service_request
    FOREIGN KEY (service_request_id) REFERENCES service_requests(id),
  ADD CONSTRAINT uq_bookings_request_worker
    UNIQUE (service_request_id, worker_user_id);

ALTER TABLE bookings DROP CHECK ck_bookings_status;
ALTER TABLE bookings ADD CONSTRAINT ck_bookings_status CHECK (status IN (
  'PENDING', 'ACCEPTED', 'VISIT_PROPOSED', 'VISIT_SCHEDULED',
  'ARRIVAL_PENDING', 'ON_SITE', 'QUOTE_PENDING', 'READY_TO_START',
  'REJECTED', 'CANCELLED', 'NOT_SELECTED'
));
```

- [ ] **Step 4: Implement the entities and repository queries**

Use `BaseEntity` for UUID, timestamps, and optimistic locking. `ServiceRequest` owns request-level details; `Booking` stores `serviceRequestId` rather than exposing the whole aggregate to JSON.

```java
public enum ServiceRequestStatus {
    OPEN, COMPARING, WORKER_SELECTED, CANCELLED
}
```

```java
@Query("""
    select count(b) from Booking b
    where b.serviceRequestId = :requestId
      and b.status not in :terminalStatuses
    """)
long countActiveCandidates(UUID requestId,
    Collection<BookingStatus> terminalStatuses);

List<Booking> findByServiceRequestIdOrderByCreatedAtAsc(UUID requestId);
boolean existsByServiceRequestIdAndWorkerUserId(UUID requestId, UUID workerUserId);
```

- [ ] **Step 5: Run persistence tests and package compilation**

Run the focused test command from Step 2, then:

```bash
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw -DskipTests package \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

Expected: focused test passes and the Spring Boot jar is produced.

### Task 2: Owner aggregate API and maximum-three candidate rules

**Files:**
- Create: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestCreateRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/CandidateCreateRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestResponse.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestController.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingResponse.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/servicerequest/ServiceRequestServiceTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/servicerequest/ServiceRequestControllerTest.java`

**Interfaces:**
- Produces: `POST /api/v1/owners/me/service-requests`.
- Produces: `GET /api/v1/owners/me/service-requests`.
- Produces: `POST /api/v1/owners/me/service-requests/{requestId}/candidates`.
- Produces: `ServiceRequestResponse` with owner-only `List<BookingResponse> candidates`.
- Preserves: `POST /api/v1/bookings` by creating one service request and its first candidate atomically.

- [ ] **Step 1: Write failing candidate rule tests**

Cover these exact outcomes:

```java
@Test
void ownerCanAddThreeDistinctSameTradeCandidates() { }

@Test
void fourthActiveCandidateReturnsCandidateLimitReached() { }

@Test
void duplicateWorkerReturnsCandidateAlreadyExists() { }

@Test
void crossTradeWorkerReturnsWorkerTradeMismatch() { }

@Test
void anotherOwnerReceivesServiceRequestNotFound() { }
```

Assert 409 codes `CANDIDATE_LIMIT_REACHED`, `CANDIDATE_ALREADY_EXISTS`, and `WORKER_TRADE_MISMATCH`; assert cross-owner access is 404 `SERVICE_REQUEST_NOT_FOUND`.

- [ ] **Step 2: Run the focused tests and confirm they fail**

```bash
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw \
  -Dtest=ServiceRequestServiceTest,ServiceRequestControllerTest test \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

Expected: missing service/controller types or missing behavior failures.

- [ ] **Step 3: Implement transactional creation and candidate addition**

Candidate addition must lock the service request before counting to prevent concurrent fourth candidates:

```java
@Lock(LockModeType.PESSIMISTIC_WRITE)
@Query("select r from ServiceRequest r where r.id = :id and r.ownerUserId = :ownerId")
Optional<ServiceRequest> findOwnedForUpdate(UUID id, UUID ownerId);
```

```java
private static final Set<BookingStatus> TERMINAL = Set.of(
    BookingStatus.REJECTED,
    BookingStatus.CANCELLED,
    BookingStatus.NOT_SELECTED);

if (bookings.countActiveCandidates(requestId, TERMINAL) >= 3) {
    throw new BusinessException(HttpStatus.CONFLICT,
        "CANDIDATE_LIMIT_REACHED", "同一装修需求最多选择 3 位候选师傅");
}
```

The server derives worker name/trade/city from a complete `WorkerProfile`; it rejects a worker whose normalized trade differs from the service request trade.

Keep the aggregate status synchronized in the same transaction: one active candidate is `OPEN`, two or three active candidates is `COMPARING`. When a pre-on-site cancellation or rejection reduces the active count below two, return the request to `OPEN`; do not rewrite future terminal states `WORKER_SELECTED` or `CANCELLED`.

- [ ] **Step 4: Preserve the old first-booking API**

Refactor `BookingService.create` to delegate to one transaction that creates a request and first candidate. Add `serviceRequestId` to every `BookingResponse`, including worker responses, but never add sibling candidates to worker responses.

```java
public record BookingResponse(
    UUID id,
    UUID serviceRequestId,
    UUID ownerUserId,
    String ownerName,
    String ownerPhone,
    UUID workerUserId,
    String workerName,
    String trade,
    String serviceCity,
    String serviceAddress,
    String remark,
    BookingStatus status,
    String cancelledBy,
    String cancelReason,
    Instant cancelledAt,
    Instant createdAt,
    Instant updatedAt
) { }
```

- [ ] **Step 5: Run service/controller tests and booking regressions**

```bash
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw \
  -Dtest=ServiceRequestServiceTest,ServiceRequestControllerTest,BookingServiceIntegrationTest,BookingControllerTest test \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

Expected: all selected tests pass; worker booking JSON contains `serviceRequestId` but no `candidates` field.

### Task 3: Role-aware cancellation with reason and audit fields

**Files:**
- Create: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingCancellationRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingCancellationActor.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/Booking.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingController.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/booking/BookingCancellationTest.java`

**Interfaces:**
- Produces: `POST /api/v1/owners/me/bookings/{id}/cancel` with `{"reason":"预算调整"}`.
- Produces: `POST /api/v1/workers/me/bookings/{id}/cancel` with `{"reason":"时间冲突"}`.
- Preserves temporarily: legacy owner route `POST /api/v1/bookings/{id}/cancel`; after the Flutter client is upgraded it uses the same required JSON reason body. This preserves only the URL, not compatibility with older APKs that omit the body.

- [ ] **Step 1: Write failing cancellation tests**

```java
@Test
void ownerCancelsOwnPendingCandidateWithReason() { }

@Test
void workerCancelsOwnAcceptedCandidateWithReason() { }

@Test
void blankReasonReturnsValidationError() { }

@Test
void unrelatedParticipantReceivesBookingNotFound() { }

@Test
void onSiteBookingReturnsBookingCannotBeCancelled() { }
```

Verify `cancelledBy`, `cancelReason`, and `cancelledAt` are persisted, and that terminal candidates no longer count toward the limit of three.

- [ ] **Step 2: Run the test and confirm behavior is absent**

```bash
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw \
  -Dtest=BookingCancellationTest test \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

Expected: missing request/actor types or assertion failures.

- [ ] **Step 3: Implement the cancellation state guard**

```java
public boolean canCancelBeforeOnSite() {
    return switch (status) {
        case PENDING, ACCEPTED, VISIT_PROPOSED,
             VISIT_SCHEDULED, ARRIVAL_PENDING -> true;
        case ON_SITE, QUOTE_PENDING, READY_TO_START,
             REJECTED, CANCELLED, NOT_SELECTED -> false;
    };
}

public void cancel(BookingCancellationActor actor, String reason, Instant now) {
    if (!canCancelBeforeOnSite()) {
        throw new BusinessException(HttpStatus.CONFLICT,
            "BOOKING_CANNOT_BE_CANCELLED", "工人确认上门后不能普通取消");
    }
    status = BookingStatus.CANCELLED;
    cancelledBy = actor.name();
    cancelReason = reason.trim();
    cancelledAt = now;
}
```

Controller methods use the JWT principal and role-specific repository lookup; they never accept an actor ID from JSON.

- [ ] **Step 4: Run cancellation and booking regression tests**

Run Task 2 Step 5 plus `BookingCancellationTest`.

Expected: all selected tests pass and cancellation errors use unified API envelopes.

### Task 4: Flutter service-request and cancellation API client

**Files:**
- Create: `zhidi_app/lib/services/service_request_api_client.dart`
- Create: `zhidi_app/test/service_request_api_client_test.dart`
- Modify: `zhidi_app/lib/services/owner_booking_api_client.dart`
- Modify: `zhidi_app/lib/services/worker_booking_api_client.dart`
- Modify: `zhidi_app/test/owner_booking_api_client_test.dart`
- Modify: `zhidi_app/test/worker_booking_api_client_test.dart`

**Interfaces:**
- Produces: `RemoteServiceRequest`, `RemoteCandidateBooking`, `ServiceRequestApi`.
- Produces: `createRequest`, `listOwnerRequests`, `addCandidate`, `cancelAsOwner`, and `cancelAsWorker`.
- Consumes: backend APIs from Tasks 2 and 3.

- [ ] **Step 1: Write failing HTTP contract tests**

Test exact paths, bearer headers, UTF-8 parsing, candidate lists, and cancellation reason bodies:

```dart
expect(captured.url.path,
    '/api/v1/owners/me/service-requests/request-1/candidates');
expect(jsonDecode(captured.body), {'workerUserId': 'worker-2'});
expect(captured.headers['authorization'], 'Bearer owner-jwt');
```

```dart
expect(jsonDecode(cancelRequest.body), {'reason': '预算调整'});
```

- [ ] **Step 2: Run the client tests and confirm the client is missing**

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
FLUTTER_SUPPRESS_ANALYTICS=true \
HOME=/Users/liupei/Documents/zhidi/zhidi_app/.codex-flutter-home \
../flutter/bin/flutter test \
  test/service_request_api_client_test.dart \
  test/owner_booking_api_client_test.dart \
  test/worker_booking_api_client_test.dart
```

Expected: compilation fails for the missing service-request client.

- [ ] **Step 3: Implement immutable remote models and API methods**

```dart
abstract interface class ServiceRequestApi {
  Future<RemoteServiceRequest> createRequest(
    String accessToken,
    ServiceRequestDraft draft,
  );
  Future<List<RemoteServiceRequest>> listOwnerRequests(String accessToken);
  Future<RemoteServiceRequest> addCandidate(
    String accessToken,
    String requestId,
    String workerUserId,
  );
  Future<RemoteCandidateBooking> cancelAsOwner(
    String accessToken,
    String bookingId,
    String reason,
  );
  Future<RemoteCandidateBooking> cancelAsWorker(
    String accessToken,
    String bookingId,
    String reason,
  );
}
```

Use the existing `AuthApiException` envelope convention. No method catches and suppresses backend failures.

- [ ] **Step 4: Run client tests and `flutter analyze`**

Run Step 2, then:

```bash
FLUTTER_SUPPRESS_ANALYTICS=true \
HOME=/Users/liupei/Documents/zhidi/zhidi_app/.codex-flutter-home \
../flutter/bin/flutter analyze
```

Expected: all focused tests pass and analysis reports no issues.

### Task 5: Owner candidate selection and real “我的家” grouping

**Files:**
- Modify: `zhidi_app/lib/app/owner_app_state.dart`
- Modify: `zhidi_app/lib/main.dart`
- Modify: `zhidi_app/lib/pages/renovation/worker_detail_page.dart`
- Create: `zhidi_app/lib/pages/renovation/candidate_request_picker_sheet.dart`
- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`
- Create: `zhidi_app/test/owner_candidate_booking_flow_test.dart`
- Create: `zhidi_app/test/my_home_remote_candidates_test.dart`

**Interfaces:**
- Consumes: `ServiceRequestApi` from Task 4 and owner JWT from `OwnerAppState`.
- Produces: server-backed `remoteServiceRequests`, `addWorkerCandidate`, `createRequestWithFirstCandidate`, and `cancelCandidate` state methods.
- Produces: owner-only UI listing up to three candidates per service request.

- [ ] **Step 1: Write failing state and widget tests**

Cover these behaviors:

```dart
testWidgets('owner adds a second worker to an existing service request',
    (tester) async { });

testWidgets('candidate picker disables adding a fourth active worker',
    (tester) async { });

testWidgets('my home groups server candidates under one request',
    (tester) async { });

testWidgets('failed add candidate does not show local success',
    (tester) async { });
```

Use an injected fake `ServiceRequestApi`; assert server method completion precedes the success snackbar.

- [ ] **Step 2: Run tests and confirm current UI has no candidate aggregate**

```bash
FLUTTER_SUPPRESS_ANALYTICS=true \
HOME=/Users/liupei/Documents/zhidi/zhidi_app/.codex-flutter-home \
../flutter/bin/flutter test \
  test/owner_candidate_booking_flow_test.dart \
  test/my_home_remote_candidates_test.dart
```

Expected: compilation or finder failures for missing candidate UI/state.

- [ ] **Step 3: Add server-backed owner state**

State mutation order must be remote first:

```dart
Future<void> addWorkerCandidate({
  required String requestId,
  required String workerUserId,
}) async {
  final session = await requireOwnerSession();
  final updated = await _serviceRequestApi.addCandidate(
    session.accessToken,
    requestId,
    workerUserId,
  );
  _replaceRemoteServiceRequest(updated);
  notifyListeners();
}
```

Remove remote booking grouping by worker name/address when `serviceRequestId` is available; the server ID is the grouping key.

- [ ] **Step 4: Implement the candidate picker and My Home cards**

The picker shows matching open requests and “新建装修需求”. It excludes requests whose trade differs and disables requests with three active candidates. The My Home request card shows request address/remark and one private row per candidate with status and cancellation entry.

Required copy:

```text
加入候选师傅
同一装修需求最多选择 3 位师傅
候选 2/3
取消该候选预约
```

- [ ] **Step 5: Run owner candidate, existing booking, and My Home regressions**

```bash
FLUTTER_SUPPRESS_ANALYTICS=true \
HOME=/Users/liupei/Documents/zhidi/zhidi_app/.codex-flutter-home \
../flutter/bin/flutter test \
  test/owner_candidate_booking_flow_test.dart \
  test/my_home_remote_candidates_test.dart \
  test/owner_booking_state_sync_test.dart \
  test/worker_detail_remote_booking_test.dart \
  test/my_home_minimal_page_test.dart
```

Expected: all selected tests pass.

### Task 6: Worker cancellation UI and candidate privacy regression

**Files:**
- Modify: `zhidi_app/lib/app/worker_app_state.dart`
- Modify: `zhidi_app/lib/pages/worker/order_detail_page.dart`
- Modify: `zhidi_app/lib/pages/worker/worker_home_page.dart`
- Create: `zhidi_app/test/worker_booking_cancel_test.dart`
- Test: `zhidi_server/src/test/java/com/zhidi/server/servicerequest/CandidatePrivacyTest.java`

**Interfaces:**
- Consumes: worker cancellation API from Task 4.
- Produces: `WorkerAppState.cancelRemoteBooking(String bookingId, String reason)`.
- Guarantees: worker booking payloads and screens never expose sibling candidate names, IDs, count, or status.

- [ ] **Step 1: Write failing worker cancellation and privacy tests**

Flutter assertions:

```dart
expect(find.text('取消预约'), findsOneWidget);
expect(find.text('请输入取消原因'), findsOneWidget);
expect(fakeApi.lastCancelReason, '时间冲突');
expect(find.text('已取消'), findsOneWidget);
```

Backend assertion:

```java
assertThat(json).doesNotContain("candidates", "candidateCount", otherWorkerName);
```

- [ ] **Step 2: Run tests and confirm the feature is absent**

Run the new Flutter test and `CandidatePrivacyTest`; expect finder or missing method failures.

- [ ] **Step 3: Implement remote-first worker cancellation**

Only show “取消预约” for cancellable statuses. Keep “拒绝订单” for `PENDING`; cancellation after acceptance requires a non-empty reason. On server failure keep the original order state and show the mapped Chinese error.

- [ ] **Step 4: Run worker booking and privacy regressions**

```bash
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw \
  -Dtest=CandidatePrivacyTest,BookingCancellationTest,BookingControllerTest test \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml

cd /Users/liupei/Documents/zhidi/zhidi_app
FLUTTER_SUPPRESS_ANALYTICS=true \
HOME=/Users/liupei/Documents/zhidi/zhidi_app/.codex-flutter-home \
../flutter/bin/flutter test \
  test/worker_booking_cancel_test.dart \
  test/worker_booking_api_client_test.dart \
  test/worker_booking_flow_test.dart
```

Expected: all selected tests pass.

### Task 7: Phase A verification, production deployment, and dual-emulator evidence

**Files:**
- Modify: `PROJECT_STATUS.md`
- Create: `output/apks/app-owner-debug-20260717-candidates.apk`
- Create: `output/apks/app-worker-debug-20260717-candidates.apk`
- Create: evidence screenshots under `output/evidence/`

**Interfaces:**
- Consumes: Tasks 1–6.
- Produces: production V10, real multi-candidate request, cancellation proof, and two installable APKs.

- [ ] **Step 1: Run fresh focused backend and Flutter verification**

Run all tests named in Tasks 1–6, backend package compilation, and `flutter analyze`. Record exact test totals and do not claim phase completion if any command is non-zero.

- [ ] **Step 2: Back up and deploy safely**

Before replacing the jar:

```bash
ssh root@47.109.0.191 '
  set -eu
  TS=$(date +%Y%m%d%H%M%S)
  BACKUP=/opt/zhidi/backups/$TS
  mkdir -p "$BACKUP"
  cp /opt/zhidi/zhidi-server.jar "$BACKUP/zhidi-server.jar"
  cp /etc/systemd/system/zhidi.service "$BACKUP/zhidi.service"
  cp /opt/zhidi/.env "$BACKUP/.env"
  set -a; . /opt/zhidi/.env; set +a
  mysqldump --no-tablespaces -u"$DB_USER" -p"$DB_PASSWORD" zhidi > "$BACKUP/zhidi.sql"
  test -s "$BACKUP/zhidi.sql"
'
```

Upload the freshly packaged jar, restart `zhidi.service`, poll `/actuator/health`, and verify `flyway_schema_history` reports `10` with `success=1`.

- [ ] **Step 3: Exercise production APIs with real accounts**

Using one owner JWT and three distinct complete worker profiles:

- Create one service request and add three candidates.
- Assert a fourth candidate returns 409 `CANDIDATE_LIMIT_REACHED`.
- Assert a worker's booking API returns only that worker's booking and no sibling candidates.
- Cancel one candidate as owner with a reason.
- Add a replacement candidate and verify the active count returns to three.
- Cancel one accepted candidate as worker and verify owner sees actor and reason.

- [ ] **Step 4: Build and install normal public-server APKs**

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
../flutter/bin/flutter build apk --debug --flavor owner \
  --dart-define=ZHIDI_APP_FLAVOR=owner \
  --dart-define=API_BASE_URL=http://47.109.0.191:8080
../flutter/bin/flutter build apk --debug --flavor worker \
  --dart-define=ZHIDI_APP_FLAVOR=worker \
  --dart-define=API_BASE_URL=http://47.109.0.191:8080
```

Copy each flavor output immediately to the named `output/apks/` path, install owner on `emulator-5554` and worker on `emulator-5570`, and preserve app data with `adb install -r`.

- [ ] **Step 5: Capture UI evidence and update project status**

Capture:

- Owner My Home showing one request with at least two candidate rows and `候选 2/3` or `候选 3/3`.
- Worker order detail showing only the worker's own owner/order data.
- Owner cancellation reason and cancelled state.
- Worker cancellation result reflected in owner My Home after refresh.

Update `PROJECT_STATUS.md` with verified V10/API/APK/evidence facts and remove only the completed phase-A gaps. Leave visit confirmation and quote comparison listed as unfinished phases B and C.
