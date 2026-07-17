# 业主资料后端持久化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为业主端新增受登录 token 保护的个人/房屋资料后端接口，让 App 填写的姓名、城市、装修类型、地址和面积能存入 MySQL 并再次读取。

**Architecture:** 继续沿用 Spring Boot 3.5 + JPA + Flyway + MockMvc/Testcontainers。新增 `owner` 领域包承载资料实体、仓储、服务和控制器；新增轻量 JWT 请求过滤器，只保护 `/api/v1/owner/**`，认证接口和 Swagger 保持公开。

**Tech Stack:** Java 21, Spring Boot 3.5.16, Spring Security, Spring Data JPA, Flyway MySQL, JJWT, JUnit 5, MockMvc, Testcontainers MySQL。

## Global Constraints

- 接口文档和用户可见说明使用中文。
- 不接真实短信；开发环境验证码继续返回 `simulatedCode`。
- 后端测试需要允许访问 Docker。
- 只实现业主资料基础持久化，不在本任务接 Flutter UI。
- 受保护接口必须从 `Authorization: Bearer <token>` 识别当前用户，不能让客户端传任意 `userId` 冒充他人。

---

## File Structure

- Create: `zhidi_server/src/main/resources/db/migration/V3__owner_profiles.sql`
  - 新增 `owner_profiles` 表，使用独立 `id` 主键和唯一 `user_id` 外键。
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/security/AuthenticatedUser.java`
  - 表示 token 中解析出的当前用户身份。
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/security/JwtAuthenticationFilter.java`
  - 解析 Bearer token，填充 Spring Security 上下文。
- Modify: `zhidi_server/src/main/java/com/zhidi/server/auth/JwtTokenService.java`
  - 暴露 token 解析方法给过滤器使用。
- Modify: `zhidi_server/src/main/java/com/zhidi/server/common/security/SecurityConfig.java`
  - `/api/v1/owner/**` 需要认证，其它现有公开路径保持公开。
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfile.java`
  - 业主资料 JPA 实体。
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileRepository.java`
  - 按 `userId` 查资料。
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileRequest.java`
  - 保存资料请求 DTO。
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileResponse.java`
  - 返回资料响应 DTO。
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileService.java`
  - 读取和 upsert 当前用户资料。
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileController.java`
  - 暴露 `GET /api/v1/owner/profile` 和 `PUT /api/v1/owner/profile`。
- Create: `zhidi_server/src/test/java/com/zhidi/server/owner/OwnerProfileControllerTest.java`
  - MockMvc 测试鉴权、读取、保存、中文 OpenAPI 摘要。
- Create: `zhidi_server/src/test/java/com/zhidi/server/owner/OwnerProfileServiceIntegrationTest.java`
  - Testcontainers 验证资料表和 upsert 行为。

---

### Task 1: 受保护 Owner 接口必须要求 Bearer token

**Files:**
- Create: `zhidi_server/src/test/java/com/zhidi/server/owner/OwnerProfileControllerTest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/security/AuthenticatedUser.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/security/JwtAuthenticationFilter.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/auth/JwtTokenService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/common/security/SecurityConfig.java`

**Interfaces:**
- Consumes: `JwtTokenService.parse(String token)`
- Produces: Spring Security `Authentication` principal of type `AuthenticatedUser`

- [ ] **Step 1: Write the failing security/controller test**

Create `zhidi_server/src/test/java/com/zhidi/server/owner/OwnerProfileControllerTest.java` with a test that calls `GET /api/v1/owner/profile` without token and expects 401.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test -Dtest=OwnerProfileControllerTest -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository
```

Expected: FAIL because `OwnerProfileControllerTest` or `/api/v1/owner/profile` does not exist yet.

- [ ] **Step 3: Add minimal controller placeholder and JWT filter**

Add enough code so `/api/v1/owner/profile` exists and unauthenticated requests return 401.

- [ ] **Step 4: Run test to verify it passes**

Run the same Maven command. Expected: PASS for the unauthenticated request test.

---

### Task 2: GET profile returns current owner profile

**Files:**
- Modify: `zhidi_server/src/test/java/com/zhidi/server/owner/OwnerProfileControllerTest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileResponse.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileController.java`

**Interfaces:**
- Consumes: `AuthenticatedUser.userId()`
- Produces: `OwnerProfileResponse(UUID userId, String phone, String name, String city, String decorationType, String address, BigDecimal area, boolean profileComplete)`

- [ ] **Step 1: Write failing GET test**

Add a test using a real JWT token for user `16600000002` and expect `$.data.phone`, `$.data.city`, and `$.data.profileComplete`.

- [ ] **Step 2: Run test to verify it fails**

Run `OwnerProfileControllerTest`. Expected: FAIL because service/response is not implemented.

- [ ] **Step 3: Implement minimal GET response**

Return token phone, default city `成都`, blank profile fields, and `profileComplete=false` when no profile exists.

- [ ] **Step 4: Run test to verify it passes**

Run `OwnerProfileControllerTest`. Expected: PASS.

---

### Task 3: PUT profile persists owner profile in MySQL

**Files:**
- Create: `zhidi_server/src/main/resources/db/migration/V3__owner_profiles.sql`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfile.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileRequest.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileController.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/owner/OwnerProfileServiceIntegrationTest.java`
- Modify: `zhidi_server/src/test/java/com/zhidi/server/owner/OwnerProfileControllerTest.java`

**Interfaces:**
- Consumes: `OwnerProfileRequest(String name, String city, String decorationType, String address, BigDecimal area)`
- Produces: upserted `OwnerProfileResponse`

- [ ] **Step 1: Write failing integration test**

Test: saving profile for an existing user creates exactly one row; saving again updates the same row.

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test -Dtest=OwnerProfileServiceIntegrationTest -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository
```

Expected: FAIL because migration/entity/service do not exist yet.

- [ ] **Step 3: Implement Flyway migration, entity, repository, request validation, and service upsert**

Validation:

- `name`: optional, max 80
- `city`: optional, max 80, default `成都`
- `decorationType`: optional, max 40
- `address`: optional, max 255
- `area`: optional, min 1, max 99999.99

- [ ] **Step 4: Run integration test to verify it passes**

Run `OwnerProfileServiceIntegrationTest`. Expected: PASS.

- [ ] **Step 5: Add controller PUT test and OpenAPI Chinese summary check**

Test `PUT /api/v1/owner/profile` with Bearer token and JSON body returns saved data and marks `profileComplete=true` when decoration type, address, and area are present.

- [ ] **Step 6: Run controller test to verify it passes**

Run `OwnerProfileControllerTest`. Expected: PASS.

---

### Task 4: Full backend verification

**Files:**
- Modify only if tests reveal required fixes.

**Interfaces:**
- Consumes: all previous tasks
- Produces: backend test evidence

- [ ] **Step 1: Run focused owner tests**

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test -Dtest=OwnerProfileControllerTest,OwnerProfileServiceIntegrationTest -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository
```

- [ ] **Step 2: Run full backend tests**

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository
```

- [ ] **Step 3: Report exact result**

Report test commands and result counts. Do not claim completion without fresh passing output.

---

## Self-Review

- Spec coverage: database persistence, JWT protection, GET/PUT profile APIs, validation, Chinese docs, and backend verification are covered.
- Placeholder scan: no `TBD`, `TODO`, or “implement later” placeholders remain.
- Type consistency: `AuthenticatedUser`, `OwnerProfileRequest`, and `OwnerProfileResponse` names are used consistently across tasks.
