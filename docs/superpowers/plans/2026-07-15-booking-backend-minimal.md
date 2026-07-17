# Booking Backend Minimal Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the smallest Spring Boot booking backend so an owner can create a booking for a real worker and the worker can accept or reject it.

**Architecture:** Add a `booking` package with entity, repository, service, controllers, DTOs, and Flyway migration. Keep booking lifecycle intentionally small: `PENDING` created by an owner, then `ACCEPTED` or `REJECTED` by the booked worker.

**Tech Stack:** Java 21, Spring Boot 3.5, Spring MVC, Spring Security method authorization, Spring Data JPA, Flyway, MySQL, Maven tests.

## Global Constraints

- Android owner app is the current delivery target; iOS is not a completion target.
- Do not implement payment, quote, chat, files, or complex address book in this slice.
- A booking must reference an existing owner user and an existing complete/visible worker profile.
- Worker accept/reject is only allowed for the booked worker.
- Keep response JSON wrapped by the existing `ApiResponse`.

---

### Task 1: Booking persistence and service

**Files:**
- Create: `zhidi_server/src/main/resources/db/migration/V5__bookings.sql`
- Create: `zhidi_server/src/main/java/com/zhidi/server/booking/Booking.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingStatus.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingService.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/booking/BookingServiceIntegrationTest.java`

**Interfaces:**
- Produces: `BookingService.create(ownerUserId, request)`, `listForOwner(ownerUserId)`, `listForWorker(workerUserId)`, `accept(workerUserId, bookingId)`, `reject(workerUserId, bookingId)`.

- [ ] Write failing integration tests for create/list/accept/reject and unauthorized worker rejection.
- [ ] Run booking service tests and confirm missing classes fail.
- [ ] Implement migration, entity, repository, service, and response mapping.
- [ ] Run booking service tests and confirm pass.

### Task 2: Booking HTTP API

**Files:**
- Create: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingResponse.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/booking/BookingControllerTest.java`

**Interfaces:**
- Owner:
  - `POST /api/v1/bookings`
  - `GET /api/v1/owners/me/bookings`
- Worker:
  - `GET /api/v1/workers/me/bookings`
  - `POST /api/v1/workers/me/bookings/{id}/accept`
  - `POST /api/v1/workers/me/bookings/{id}/reject`

- [ ] Write failing controller tests for owner token required, worker token forbidden for owner create, owner create returns booking, worker accept returns accepted.
- [ ] Implement controller and DTO validation.
- [ ] Run controller tests and confirm pass.

### Task 3: Verification and status

**Files:**
- Modify: `PROJECT_STATUS.md`

- [ ] Run backend full tests.
- [ ] Update project status after tests prove the booking backend.
- [ ] Do not commit unless user asks.
