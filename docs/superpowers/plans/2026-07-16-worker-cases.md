# Worker Cases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store real worker cases and images on the ECS and show the same cases in the owner worker-detail screen.

**Architecture:** A dedicated Spring `workercase` package owns case records and authorization; a focused file storage component owns validated image uploads and static serving. Flutter uses one API client from the worker case-management UI and the owner public detail UI.

**Tech Stack:** Java 21, Spring Boot 3.5, JPA, Flyway, MySQL JSON, Flutter/Dart, `image_picker`, HTTP multipart.

## Global Constraints

- Android is the current delivery target.
- ECS REST API and MySQL are the source of truth.
- Images are JPG, PNG, or WebP, at most 10MB each and 1–6 per case.
- Production files live under `/opt/zhidi/uploads/cases`.
- Existing unrelated user changes are preserved and no Git commit is created automatically.

---

### Task 1: Worker case persistence and ownership API

**Files:**
- Create: `zhidi_server/src/main/resources/db/migration/V9__worker_cases.sql`
- Create: `zhidi_server/src/main/java/com/zhidi/server/workercase/WorkerCase.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/workercase/WorkerCaseRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/workercase/WorkerCaseRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/workercase/WorkerCaseResponse.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/workercase/WorkerCaseService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/workercase/WorkerCaseController.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/workercase/WorkerCaseServiceTest.java`

**Interfaces:**
- Produces: CRUD `/api/v1/workers/me/cases` and public `GET /api/v1/workers/{workerUserId}/cases`.

- [x] Write failing service tests for create/list/update/delete ownership and validation.
- [x] Run the focused test and confirm missing types fail compilation.
- [x] Add migration, entity, repository, DTOs, service, and controller.
- [x] Run focused tests and backend package compilation.

### Task 2: Validated ECS image storage

**Files:**
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/ImageStorageService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/ImageUploadController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/ImageUploadResponse.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/UploadWebConfiguration.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/storage/ImageStorageServiceTest.java`
- Modify: `zhidi_server/src/main/resources/application.yml`
- Modify: `zhidi_server/src/main/resources/application-prod.yml`

**Interfaces:**
- Produces: `POST /api/v1/workers/me/case-images` and public `/uploads/cases/{generatedName}`.

- [x] Write failing tests for MIME rejection, empty files, generated filenames, and size limits.
- [x] Run the focused test and confirm the storage service is absent.
- [x] Implement storage, upload controller, resource mapping, and multipart limits.
- [x] Run focused tests and backend package compilation.

### Task 3: Flutter case API client

**Files:**
- Create: `zhidi_app/lib/services/worker_case_api_client.dart`
- Create: `zhidi_app/test/worker_case_api_client_test.dart`

**Interfaces:**
- Produces: `RemoteWorkerCase`, `WorkerCaseApi`, public list, authenticated CRUD, and image upload.

- [x] Write failing client tests for public GET, authenticated POST, multipart upload, and error envelopes.
- [x] Run the test and confirm the client is missing.
- [x] Implement the client with the existing API envelope/error conventions.
- [x] Run the focused client test.

### Task 4: Worker case-management UI

**Files:**
- Create: `zhidi_app/lib/pages/worker/worker_case_edit_page.dart`
- Modify: `zhidi_app/lib/pages/worker/worker_profile_page.dart`
- Create: `zhidi_app/test/worker_case_management_test.dart`

**Interfaces:**
- Consumes: `WorkerCaseApi`, worker access token, `image_picker`.
- Produces: profile case list, add/edit/delete case form, upload progress, and validated save.

- [x] Write failing widget tests for the profile entry and a successful case save.
- [x] Run tests and confirm the UI is absent.
- [x] Implement case list and editor with injectable API/image selection.
- [x] Run focused widget tests.

### Task 5: Owner real case display

**Files:**
- Modify: `zhidi_app/lib/pages/renovation/worker_detail_page.dart`
- Modify: `zhidi_app/lib/pages/home/worker/worker_list_page.dart`
- Create: `zhidi_app/test/owner_worker_cases_test.dart`

**Interfaces:**
- Consumes: public `WorkerCaseApi.listPublicCases(workerUserId)`.
- Produces: remote case cards and explicit loading/empty/error states without Picsum fallback.

- [x] Write a failing widget test asserting a server case title and image URL render for a remote worker.
- [x] Run the test and confirm the current page still renders six Picsum images.
- [x] Inject/load the API and replace remote-worker mock cases with server cases.
- [x] Run owner case, remote profile, and booking regression tests.

### Task 6: Verify, publish, and dual-emulator evidence

**Files:**
- Modify: `PROJECT_STATUS.md`
- Create: production APKs under `output/apks/`
- Create: screenshots under `output/evidence/`

**Interfaces:**
- Consumes: completed backend and Flutter implementation.
- Produces: deployed V9 backend, real production case, owner/worker APKs, and evidence.

- [x] Run focused backend tests and package compilation.
- [x] Run focused Flutter tests and `flutter analyze`.
- [x] Back up ECS database and jar, create `/opt/zhidi/uploads/cases`, deploy, and verify health/Flyway V9.
- [x] Create a production test case with a real uploaded image and verify the public API.
- [x] Build/install both normal APKs and capture worker/owner screenshots.
- [x] Update `PROJECT_STATUS.md` with only verified facts.
