# P0 Real-User Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development task-by-task. Every behavior change follows RED → GREEN → focused regression. This repository is an externally managed detached worktree with extensive user-owned uncommitted changes, so do not commit, stage, reset, clean, or overwrite unrelated edits.

**Goal:** Remove cross-order state leakage, old local-success paths, and unsupported trust/payment claims so a new owner request can be tested without being confused with an older project.

**Architecture:** The backend remains the source of truth for request, booking, quote, inspection, and payment identity. Flutter must render one explicitly selected `serviceRequestId`/`bookingId` at a time, reject mismatched API payloads, and never substitute an unrelated local object when the requested object disappears. Until server-backed favorites, customer service, presence, and online payment exist, production UI uses honest unavailable states instead of local simulations.

**Tech Stack:** Flutter/Dart, Spring Boot 3.5, Java 21, Spring Data JPA, MySQL/Flyway, JUnit 5, Flutter Widget tests.

## Global Constraints

- Preserve all user-owned uncommitted changes; inspect the current diff before touching a file.
- Do not initialize or delete production data and do not deploy this plan until local full suites pass and deployment is separately requested.
- Do not commit, stage, push, or create a PR.
- Direct owner-to-worker selection remains the core product model; do not introduce platform dispatch.
- No UI may claim real-time presence, third-party certification, bank escrow, automatic refund, or online payment until the corresponding server capability exists.
- Every request/quote/inspection/payment lookup must match the complete UUID `bookingId`; trade, city, list position, or “latest item” is never an identity.
- Multi-candidate work uses `POST /owners/me/service-requests` plus `/{requestId}/candidates`; legacy `POST /bookings` creates an independent request and must not guess which earlier project to reuse.
- Existing `READY_TO_START`, `HIRED`, and `COMPLETED` bookings remain visible as selected/archived projects but are not active candidates for reopening a request.

---

### Task 1: Backend Request and Candidate Lifecycle Isolation

**Files:**
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingStatus.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequest.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestService.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/booking/BookingServiceIntegrationTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/servicerequest/ServiceRequestServiceTest.java`

**Interfaces:**
- `BookingService.create(ownerUserId, request)` produces a new `ServiceRequest` for the legacy direct-booking call.
- `ServiceRequestService.addCandidate(...)` accepts only `OPEN` or `COMPARING` requests.
- `BookingStatus.CANDIDATE_TERMINAL_STATUSES` is the single set used when counting active candidates and contains `REJECTED`, `CANCELLED`, `NOT_SELECTED`, `HIRED`, and `COMPLETED`.

- [ ] **Step 1: Add failing direct-booking isolation test**

Create two complete workers of the same trade/city. Call `BookingService.create` twice with different addresses, then assert literal behavior:

```java
assertThat(second.serviceRequestId()).isNotEqualTo(first.serviceRequestId());
assertThat(second.serviceAddress()).isEqualTo("武侯区新项目 2 号");
```

- [ ] **Step 2: Run the isolation test and verify RED**

Run:

```bash
./mvnw -Dtest=BookingServiceIntegrationTest#directBookingsForDifferentProjectsNeverReuseAServiceRequest test
```

Expected: FAIL because the current implementation reuses `owner + trade + city + OPEN` and copies the first address.

- [ ] **Step 3: Add failing terminal-request guard test**

Create a request, add a candidate, move the request to `ASSIGNED`, then call `addCandidate` again and assert:

```java
assertThat(error).isInstanceOfSatisfying(BusinessException.class, ex -> {
    assertThat(ex.status()).isEqualTo(HttpStatus.CONFLICT);
    assertThat(ex.code()).isEqualTo("SERVICE_REQUEST_NOT_OPEN");
});
assertThat(bookings.findByServiceRequestIdOrderByCreatedAtAsc(requestId)).hasSize(1);
assertThat(requests.findById(requestId).orElseThrow().getStatus())
    .isEqualTo(ServiceRequestStatus.ASSIGNED);
```

- [ ] **Step 4: Run the guard test and verify RED**

Run:

```bash
./mvnw -Dtest=ServiceRequestServiceTest#assignedRequestCannotAcceptAnotherCandidate test
```

Expected: FAIL because a candidate is currently added and the request can be demoted.

- [ ] **Step 5: Implement minimal lifecycle isolation**

- Replace the direct-booking `find...OPEN` reuse block with unconditional `ServiceRequest.create(...)` + `saveAndFlush`.
- Move the candidate terminal statuses to `BookingStatus` and reuse the same immutable set in both services.
- Before worker lookup in `addCandidate`, reject every request status except `OPEN` and `COMPARING` with `409 SERVICE_REQUEST_NOT_OPEN` and a Chinese owner-facing message.
- Make `ServiceRequest.syncActiveCandidateCount` preserve `ASSIGNED`, `WORKER_SELECTED`, and `CANCELLED`.

- [ ] **Step 6: Verify focused GREEN and adjacent regressions**

Run:

```bash
./mvnw -Dtest=BookingServiceIntegrationTest,ServiceRequestServiceTest,QuoteFlowIntegrationTest test
```

Expected: all selected tests pass; update any obsolete test that intentionally expected implicit direct-booking reuse so it now uses the explicit service-request candidate API.

### Task 2: Owner Workbench Identity and Quote Refresh

**Files:**
- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`
- Modify: `zhidi_app/lib/services/worker_quote_api_client.dart`
- Test: `zhidi_app/test/my_home_minimal_page_test.dart`
- Test: `zhidi_app/test/worker_quote_api_client_test.dart`

**Interfaces:**
- The featured workbench returns one `(serviceRequestId, bookingId)` pair; title, status, quote, payment, inspection, and next action all consume that pair.
- A newer `OPEN/COMPARING` request is not visually replaced by an older same-trade `COMPLETED` request.
- `refreshEpoch` invalidates booking-scoped quote data and reloads it.
- `WorkerQuoteApiClient` rejects a quote whose response `bookingId` differs from the requested UUID.

- [ ] **Step 1: Add failing mixed-history workbench test**

Fixture: an older carpentry request has a `COMPLETED` candidate and `PAID` payment; a newer carpentry request is `OPEN` with no candidates. Assert that the current workbench does not show the older worker or paid CTA as the newer request, and that the request list still shows the new request as waiting for candidates.

- [ ] **Step 2: Verify RED**

Run:

```bash
flutter test test/my_home_minimal_page_test.dart --plain-name "new open request is not replaced by an older completed same-trade project"
```

Expected: FAIL because the featured workbench currently treats `COMPLETED` as active while the request list independently chooses the newer item.

- [ ] **Step 3: Add failing quote-refresh test**

Return quote total `12860` on the first load and `8240` after `refreshEpoch` changes. Assert two API calls and final visible `¥8240`.

- [ ] **Step 4: Verify RED**

Expected: FAIL because `_quotes.containsKey(bookingId)` currently keeps stale data forever.

- [ ] **Step 5: Add failing API identity test**

Request `booking-new` but return JSON containing `booking-old`; assert `AuthApiException` with code `INVALID_RESPONSE` rather than accepting the quote.

- [ ] **Step 6: Implement minimal owner isolation**

- Centralize actionable/terminal candidate predicates.
- Choose the latest actionable request first; only show an archived completed project when no actionable request exists.
- Pass the selected booking explicitly through workbench, quote, payment, and action builders.
- On each refresh epoch, replace quote maps with the new response instead of `addAll`-only caching; choose the accepted quote, otherwise the latest server quote, never `quotes.first` without ordering.
- Validate every quote response `bookingId` at the API boundary.

- [ ] **Step 7: Verify focused GREEN**

Run:

```bash
flutter test test/my_home_minimal_page_test.dart test/worker_quote_api_client_test.dart
```

Expected: all tests pass.

### Task 3: Worker Order, Quote Form, and Session Isolation

**Files:**
- Modify: `zhidi_app/lib/pages/worker/order_detail_page.dart`
- Modify: `zhidi_app/lib/pages/worker/quotation_form_page.dart`
- Modify: `zhidi_app/lib/app/worker_app_state.dart`
- Modify: `zhidi_app/lib/app/owner_app_state.dart`
- Test: `zhidi_app/test/worker_order_detail_refresh_test.dart`
- Test: `zhidi_app/test/worker_quotation_form_page_test.dart`
- Test: `zhidi_app/test/worker_session_state_test.dart`
- Test: `zhidi_app/test/owner_session_state_test.dart`

**Interfaces:**
- `OrderDetailPage(orderId)` renders only that order; if it disappears after refresh, it shows an explicit unavailable state and never substitutes `orders.first`.
- `QuotationFormPage` resets selections and reloads the catalog when `order.id` or `order.trade` changes.
- Logout removes the authenticated user's orders, quotes, appointments, payment summaries, and messages from persisted state before another account can render.

- [ ] **Step 1: Add target-order disappearance test and verify RED**

Open order B while A is completed; refresh leaves only A. Assert no `完工档案` or A owner name appears and an explicit `该订单已更新或不再可用` state is shown.

- [ ] **Step 2: Add quote-widget identity test and verify RED**

Enter quantity `50` for booking A, update the same widget element to booking B, and assert total `¥0`, no selected item, and a second catalog call for B's trade.

- [ ] **Step 3: Add logout privacy tests and verify RED**

After logout and state restoration, assert no prior-account order, quotation, remote booking, appointment, chat preview, payment order, or settlement is exposed.

- [ ] **Step 4: Implement minimal identity handling**

- Remove `state.orders.first` fallback from order detail; render a safe unavailable state.
- Add `didUpdateWidget`, clear `_selectedItems/_quantities/_catalog`, reset load flags, and reload catalog when order identity changes.
- Clear and persist user-scoped collections during both owner and worker logout while retaining only non-user app preferences.

- [ ] **Step 5: Verify focused GREEN**

Run:

```bash
flutter test test/worker_order_detail_refresh_test.dart test/worker_quotation_form_page_test.dart test/worker_session_state_test.dart test/owner_session_state_test.dart
```

Expected: all tests pass.

### Task 4: One Real Worker Detail and No Local Success Path

**Files:**
- Modify: `zhidi_app/lib/pages/renovation/worker_detail_page.dart`
- Modify: `zhidi_app/lib/pages/profile/favorites_page.dart`
- Modify: `zhidi_app/lib/pages/renovation/booking_success_page.dart`
- Modify: `zhidi_app/lib/pages/message/message_page.dart`
- Modify: production callers of `home/worker/worker_detail_page.dart`, `order/create_order_page.dart`, `renovation/worker_chat_page.dart`, and `chat/chat_page.dart`
- Test: `zhidi_app/test/worker_detail_remote_profile_test.dart`
- Test: `zhidi_app/test/worker_detail_remote_booking_test.dart`
- Test: `zhidi_app/test/booking_success_page_status_test.dart`
- Test: `zhidi_app/test/message_page_chat_rooms_test.dart`
- Replace or remove obsolete positive tests for local booking/chat.

**Interfaces:**
- Every reachable worker detail requires a server `workerUserId` and uses the remote profile/case page.
- Before a booking exists, the UI does not claim the worker is online and does not open a fake worker conversation.
- After a booking exists, contact uses the real booking chat room only.
- Until favorites are server-backed, the production favorite entry is hidden or explicitly marked unavailable; it never opens legacy hard-coded data.

- [ ] **Step 1: Write failing navigation and negative-truth tests**

Assert production routes cannot reach a local booking form, fake worker chat, hard-coded ratings, or legacy worker detail. Assert booking success says `预约已提交` and `上门时间待双方确认`.

- [ ] **Step 2: Verify RED**

Run the four focused files and confirm failures come from currently reachable local simulations.

- [ ] **Step 3: Implement the minimal route consolidation**

- Make remote profile identity mandatory at all production detail entry points.
- Remove/hide the local-only favorite and booking paths.
- Replace pre-cooperation chat buttons with an honest `平台咨询暂未开放` state.
- Change WebSocket connection copy from `在线` to `已连接` unless real presence is added.

- [ ] **Step 4: Verify GREEN and route regressions**

Run all worker detail, candidate picker, favorites, booking success, and chat tests.

### Task 5: Honest Trust, Pricing, and Payment Copy

**Files:**
- Modify: `zhidi_app/lib/pages/home/owner_quote_compare_page.dart`
- Modify: `zhidi_app/lib/pages/renovation/fund_bank_escrow_page.dart`
- Modify: `zhidi_app/lib/pages/renovation/construction_guarantee_page.dart`
- Modify: `zhidi_app/lib/pages/home/home_page.dart`
- Modify: `zhidi_app/lib/pages/price/price_list_page.dart`
- Modify: `zhidi_app/lib/pages/price/price_transparency_page.dart`
- Modify: `zhidi_app/lib/pages/price/price_detail_page.dart`
- Modify: `zhidi_app/lib/pages/price/construction_project_detail_page.dart`
- Modify: `zhidi_app/lib/pages/home/owner_payment_page.dart`
- Modify: `zhidi_app/lib/pages/renovation/trade_select_page.dart`
- Test: adjacent quote, payment, home, trade, and price page Widget tests.

**Interfaces:**
- Quote confirmation says `确认选择该师傅`; the page states that selection does not itself move money.
- Current payment explanation says `线下付款与人工确认`; it never claims bank escrow or automatic release/refund.
- Paid orders offer real order-bound after-sale entry for manual handling.
- Server-backed counts remain; fabricated ratings, online counts, response times, insurance, and certification claims are removed.
- Mock-only renovation services are labeled `暂未开放` and cannot present a fake completion CTA.

- [ ] **Step 1: Write failing negative-claim tests**

Add assertions that reachable pages contain none of: `银行监管`, `平台不碰钱`, `银行放款`, fabricated ratings/order counts, `在线师傅`, or a snackbar-only `立即获取报价` success.

- [ ] **Step 2: Verify RED**

Run focused quote/payment/home/price tests and confirm exact unsupported claims are still reachable.

- [ ] **Step 3: Implement honest copy and actions**

- Replace escrow confirmation with worker-selection confirmation.
- Keep real bank account fields only where they are actual offline transfer instructions.
- Route quote CTAs to the real worker directory, or disable them with `暂未开放`.
- Route refund concerns to the real order-bound after-sale page and state that processing is manual.
- Replace `已认证` with `资料已完善`; replace `可预约` counts with `资料完整师傅` unless availability is server-backed.

- [ ] **Step 4: Verify GREEN**

Run all affected Widget tests and a repository text scan scoped to production Dart files.

### Task 6: In-App Business Notifications and Deep Links

**Files:**
- Modify: `zhidi_app/lib/app/owner_models.dart`
- Modify: `zhidi_app/lib/app/owner_app_state.dart`
- Modify: `zhidi_app/lib/app/worker_models.dart`
- Modify: `zhidi_app/lib/app/worker_app_state.dart`
- Modify: `zhidi_app/lib/pages/message/message_page.dart`
- Modify: `zhidi_app/lib/pages/worker/worker_home_page.dart`
- Test: `zhidi_app/test/owner_booking_state_sync_test.dart`
- Test: `zhidi_app/test/worker_bottom_navigation_test.dart`
- Test: `zhidi_app/test/message_page_chat_rooms_test.dart`

**Interfaces:**
- A notification stores `eventType`, `bookingId`, optional `serviceRequestId`, read state, title, body, and target action.
- Booking transition sync creates one idempotent item per event and booking.
- Tapping opens the exact booking/request step; a stale target shows an explicit unavailable state.

- [ ] **Step 1: Add failing transition matrix tests**

Cover accept, visit proposal/confirmation, arrival pending, quote submitted, selected/not selected, inspection requested/pass/rectification, payment reported, receipt confirmation, and after-sale state changes.

- [ ] **Step 2: Add failing deep-link tests**

Tap a `QUOTE_SUBMITTED` event and assert the quote comparison for its `serviceRequestId`; tap `ARRIVAL_PENDING` and assert the exact candidate details; tap a stale target and assert a safe message.

- [ ] **Step 3: Implement idempotent event mapping and routing**

Do not claim system push; label this capability as in-app notifications until a push provider exists.

- [ ] **Step 4: Verify focused GREEN**

Run the three notification/message suites and full Flutter analyze.

### Task 7: Correct the Audit Record and Verify the P0 Batch

**Files:**
- Modify: `docs/product-audit-owner-closed-loop-20260808.md`
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- The audit distinguishes confirmed defects from the actions actually performed during the audit.
- It records that booking `58da1b1d-4a83-4055-9892-385d3d81e423` had a quote accepted at `15:23:01`, inspection passed at `15:24:39`, and payment confirmed at `15:25:55`; the completed/paid state was not caused by merely opening or submitting the quote.

- [ ] **Step 1: Correct the evidence narrative**

Remove the false statement that the quotation form initialized with old quantities and the unsupported conclusion that quote submission itself jumped to completion/payment. Retain the confirmed request-reuse and UI mixed-request findings.

- [ ] **Step 2: Run fresh full verification**

Run:

```bash
cd zhidi_server && ./mvnw test
cd ../zhidi_app && flutter analyze && flutter test --reporter compact
git diff --check
```

- [ ] **Step 3: Update project status with verified facts only**

Record exact test totals and keep undeployed work explicitly marked local-only.
