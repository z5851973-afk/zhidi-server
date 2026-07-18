# Android Production Roadmap Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Correct the production-blocking schema, multi-candidate, authorization, and Flutter regressions found in the 2026-07-18 audit without pretending external integrations are complete.

**Architecture:** Preserve the existing V9 production service and repair the unshipped V10-V16 work through forward-only migrations and participant-scoped service methods. Treat `ServiceRequest` as the owner aggregate, keep each `Booking` private to its owner and assigned worker, and make Flutter call the aggregate APIs instead of manufacturing independent legacy bookings. External SMS, storage, push, and payment remain explicitly disabled until configured and verified.

**Tech Stack:** Java 21, Spring Boot 3.5, Spring Data JPA, Flyway, MySQL 8, Flutter/Dart, JUnit 5, Testcontainers, Flutter widget tests.

## Global Constraints

- Android is the only current client delivery target.
- ECS Spring Boot API and native MySQL remain the source of truth.
- Do not modify deployed Flyway V1-V9; V10-V16 may be corrected only because production is verified at V9, and an additional V17 validates/fixes the final schema.
- One service request contains at most three active same-trade candidate bookings.
- A worker accepting a candidate booking never closes sibling candidates.
- Only final owner quote selection closes sibling bookings and quotes.
- Object lookup is scoped from the JWT user; unauthorized object reads return 404.
- Payment callbacks, real SMS, object storage, and push must not report success until their providers are configured and verified.
- Preserve all unrelated staged and unstaged user changes; do not commit, push, or deploy automatically.

---

### Task 1: Restore a buildable backend and valid V14 schema

**Files:**
- Modify: `zhidi_server/pom.xml`
- Modify: `zhidi_server/src/main/resources/db/migration/V14__daily_reports_and_inspections.sql`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/inspection/InspectionRecord.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/migration/PhaseMigrationValidationTest.java`

**Interfaces:**
- Produces: Hibernate-compatible `daily_reports`, `inspection_nodes`, and `inspection_records` tables.
- Preserves: one business revision number for inspection history under a non-JPA-lock column name.

- [ ] Add a failing context/persistence test that starts MySQL migrations through V16 and persists one `DailyReport`, `InspectionNode`, and `InspectionRecord`.
- [ ] Run `./mvnw -Dtest=PhaseMigrationValidationTest test` and confirm the schema/mapping failure.
- [ ] Add missing BaseEntity columns to V14 and rename the business inspection revision to `inspection_version` in both SQL and Java.
- [ ] Correct or remove the unresolved Tencent SMS dependency using an artifact/version available to the configured repository; do not change SMS behavior in this task.
- [ ] Re-run the focused test and `./mvnw -DskipTests package` and require exit code 0.

### Task 2: Preserve all candidates until final owner selection

**Files:**
- Modify: `zhidi_server/src/test/java/com/zhidi/server/booking/BookingServiceIntegrationTest.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/Booking.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestService.java`

**Interfaces:**
- Produces: `BookingService.accept(workerUserId, bookingId)` changes only the selected worker booking from `PENDING` to `ACCEPTED`.
- Produces: request status `OPEN` for one active candidate and `COMPARING` for two or three active candidates.
- Preserves: `QuoteService.acceptQuote(ownerUserId, quoteId)` as the sole final-selection transaction.

- [ ] Replace the existing wrong integration assertion with a failing test proving two workers may independently accept the same request and neither becomes `NOT_SELECTED`.
- [ ] Run the focused booking test and confirm it fails because the first acceptance closes siblings.
- [ ] Remove sibling closure and premature `selectWorker()` from booking acceptance; add legal-state guards to accept/reject.
- [ ] Add failing cancellation tests for every pre-`ON_SITE` state and service-request status resynchronization.
- [ ] Implement cancellation/status synchronization and re-run booking/service-request tests.

### Task 3: Enforce participant ownership on private data

**Files:**
- Modify: `zhidi_server/src/main/java/com/zhidi/server/quote/QuoteController.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/quote/QuoteService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/dailyreport/DailyReportController.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/dailyreport/DailyReportService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/inspection/InspectionController.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/inspection/InspectionService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentController.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentOrderService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/AfterSaleController.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/AfterSaleService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/chat/ChatRoomService.java`
- Test: matching integration tests under `zhidi_server/src/test/java/com/zhidi/server/`.

**Interfaces:**
- Every private read consumes `CurrentUserPrincipal.userId()`.
- Booking-scoped data permits only `booking.ownerUserId` or `booking.workerUserId`.
- Service-request quote comparison permits only `serviceRequest.ownerUserId`.
- Unauthorized and missing resources both return 404 with the resource-specific not-found code.

- [ ] Add one failing cross-owner and one failing unrelated-worker test for each affected resource family.
- [ ] Run each focused test and confirm current data leakage.
- [ ] Pass principal IDs from controllers into services and centralize participant checks around `BookingRepository` and owned service-request lookup.
- [ ] Fix existing-room chat lookup so participant validation runs whether the room is new or pre-existing.
- [ ] Re-run all affected integration tests.

### Task 4: Make quote and payment boundaries safe

**Files:**
- Modify: `zhidi_server/src/main/java/com/zhidi/server/quote/QuoteItemRequest.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/quote/QuoteService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentController.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentOrderService.java`
- Modify: `zhidi_app/lib/pages/home/owner_payment_page.dart`
- Modify: `zhidi_app/lib/pages/home/owner_quote_compare_page.dart`
- Test: `QuoteFlowIntegrationTest` plus focused Flutter widget tests.

**Interfaces:**
- Quote quantity must be greater than zero and bounded by the catalog rule; the server remains the only price calculator.
- UUID request fields use `@NotNull`, never `@NotBlank`.
- Payment callback is disabled with a service-unavailable response unless a verified provider adapter is enabled.
- Owner quote selection requires summary, explicit acknowledgement, and a two-second hold before submission.

- [ ] Add failing validation tests for zero/negative quantity and invalid payment request DTOs.
- [ ] Implement validation and confirm the focused backend tests pass.
- [ ] Add a failing controller test proving an unconfigured payment callback cannot mark an order paid.
- [ ] Disable the placeholder callback and remove any client-side appearance of successful real payment.
- [ ] Add a widget test for acknowledgement plus two-second hold and implement the guarded quote confirmation UI.

### Task 5: Restore the real Flutter service-request path and current app regressions

**Files:**
- Modify: `zhidi_app/lib/services/service_request_api_client.dart`
- Modify: `zhidi_app/lib/pages/home/worker/candidate_picker_page.dart`
- Modify: `zhidi_app/lib/pages/renovation/trade_select_page.dart`
- Modify: `zhidi_app/lib/pages/home/home_page.dart`
- Modify: `zhidi_app/test/candidate_picker_page_test.dart`
- Modify: `zhidi_app/test/home_requirement_hub_test.dart`
- Modify: `zhidi_app/test/owner_app_startup_test.dart`

**Interfaces:**
- `createRequest` calls `POST /api/v1/owners/me/service-requests` once.
- `addCandidate` calls `POST /api/v1/owners/me/service-requests/{requestId}/candidates` for the second and third workers.
- Candidate picker retains one server `requestId` and never creates independent legacy bookings for sibling candidates.
- Protected owner tabs retain login gating and message-tab server refresh.

- [ ] Update the candidate widget/API tests first to require one create call followed by aggregate candidate calls.
- [ ] Run focused Flutter tests and confirm they fail against the current legacy endpoint behavior.
- [ ] Restore aggregate endpoints and request-ID state in the client/page.
- [ ] Restore `HomeRequirementHub`, protected-tab login gating, and remote message refresh without discarding unrelated visual changes.
- [ ] Remove unimplemented production promises such as funds custody and advance compensation from visible copy.
- [ ] Run focused tests, full `flutter analyze`, and full `flutter test`.

### Task 6: Full verification and truthful project status

**Files:**
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- Produces: verified local status only; no production deployment claim.

- [ ] Run `git diff --check`.
- [ ] Run full Maven tests and record pass/fail counts.
- [ ] Run full Flutter analyze and tests and record exact results.
- [ ] Build owner and worker debug APKs against the selected test API and record paths, sizes, and hashes.
- [ ] Update `PROJECT_STATUS.md` with only verified capabilities and remaining external-integration gaps.
- [ ] Review `git diff` to confirm no unrelated user work was overwritten.
