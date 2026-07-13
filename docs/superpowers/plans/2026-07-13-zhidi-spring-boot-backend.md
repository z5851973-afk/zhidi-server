# 知底 Spring Boot 后端 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在现有 Flutter 项目旁构建可部署到 Ubuntu 22.04 的知底服务端，打通业主与工人的认证、找师傅、预约、报价、施工、验收和分阶段支付闭环。

**Architecture:** 在 `zhidi_server/` 中创建模块化单体 Spring Boot 应用，各业务包独立持有实体、仓储、服务和控制器，通过应用服务和 ID 协作。MySQL 是唯一业务数据源；短信、文件、微信支付和支付宝均通过端口接口与环境适配器解耦。

**Tech Stack:** Java 21、Spring Boot 3.5.16、Maven Wrapper、Spring MVC、Spring Security、Spring Data JPA、Flyway、MySQL 8.4、JJWT、springdoc OpenAPI、JUnit 5、Testcontainers、Docker Compose、Nginx。

## Global Constraints

- 后端目录固定为仓库根目录下的 `zhidi_server/`，不改动现有 Flutter 页面和本地状态逻辑。
- REST API 前缀固定为 `/api/v1`，响应字段为 `code`、`message`、`data`、`traceId`。
- 数据库金额一律使用人民币“分”的 `BIGINT`/Java `long`，禁止使用浮点数。
- 数据库结构只允许通过 Flyway 迁移修改，生产环境 Hibernate 使用 `ddl-auto: validate`。
- 生产环境只允许 HTTPS；密钥来自环境变量或 Docker Secret，不得提交到 Git。
- 所有资源接口同时校验角色和数据归属，禁止只依靠 Flutter 隐藏入口。
- 外部短信、对象存储和支付渠道必须通过端口接口接入，测试使用确定性假实现。
- 每个任务先写失败测试，再做最小实现；每个任务结束必须运行该任务测试及全量 `./mvnw test`。

---

## File Structure

```text
zhidi_server/
  pom.xml
  mvnw
  mvnw.cmd
  .mvn/wrapper/
  .env.example
  Dockerfile
  compose.yaml
  deploy/nginx/zhidi.conf
  deploy/scripts/backup-mysql.sh
  src/main/java/com/zhidi/server/
    ZhidiServerApplication.java
    common/api/
    common/error/
    common/security/
    common/persistence/
    auth/
    owner/
    worker/
    appointment/
    quotation/
    project/
    storage/
    payment/
  src/main/resources/
    application.yml
    application-dev.yml
    application-prod.yml
    db/migration/
  src/test/java/com/zhidi/server/
```

Package responsibility rules:

- `common` 只存放跨领域的 API、错误、安全和持久化基础，不保存业务状态机。
- 每个业务包包含自己的 entity、repository、service、controller 和 dto 子包。
- 跨模块只能调用公开 service 或只读 projection，不直接修改其他模块实体。
- 第三方 SDK 代码只能出现在 `adapter` 子包，领域服务依赖 Java 接口。

---

### Task 1: 创建可启动的 Spring Boot 工程与统一 API 契约

**Files:**

- Create: `zhidi_server/pom.xml`
- Create: `zhidi_server/mvnw`
- Create: `zhidi_server/mvnw.cmd`
- Create: `zhidi_server/.mvn/wrapper/maven-wrapper.properties`
- Create: `zhidi_server/src/main/java/com/zhidi/server/ZhidiServerApplication.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/api/ApiResponse.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/api/TraceIdFilter.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/error/BusinessException.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/error/GlobalExceptionHandler.java`
- Create: `zhidi_server/src/main/resources/application.yml`
- Test: `zhidi_server/src/test/java/com/zhidi/server/SmokeApiTest.java`

**Interfaces:**

- Produces: `ApiResponse<T>(String code, String message, T data, String traceId)` used by every controller.
- Produces: `BusinessException(HttpStatus status, String code, String message)` used by every service.
- Produces: request/response header `X-Trace-Id`; server generates a UUID when absent.

- [ ] **Step 1: Generate the Maven wrapper and create the dependency manifest**

Run from the repository root:

```bash
mkdir -p zhidi_server
cd zhidi_server
mvn -N wrapper:wrapper -Dmaven=3.9.11
```

Create `pom.xml` with parent `org.springframework.boot:spring-boot-starter-parent:3.5.16`, Java 21 and these dependencies:

```xml
<dependencies>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-validation</artifactId></dependency>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-security</artifactId></dependency>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-data-jpa</artifactId></dependency>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-actuator</artifactId></dependency>
  <dependency><groupId>org.flywaydb</groupId><artifactId>flyway-mysql</artifactId></dependency>
  <dependency><groupId>com.mysql</groupId><artifactId>mysql-connector-j</artifactId><scope>runtime</scope></dependency>
  <dependency><groupId>org.springdoc</groupId><artifactId>springdoc-openapi-starter-webmvc-ui</artifactId><version>2.8.16</version></dependency>
  <dependency><groupId>io.jsonwebtoken</groupId><artifactId>jjwt-api</artifactId><version>0.12.7</version></dependency>
  <dependency><groupId>io.jsonwebtoken</groupId><artifactId>jjwt-impl</artifactId><version>0.12.7</version><scope>runtime</scope></dependency>
  <dependency><groupId>io.jsonwebtoken</groupId><artifactId>jjwt-jackson</artifactId><version>0.12.7</version><scope>runtime</scope></dependency>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId><scope>test</scope></dependency>
  <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-testcontainers</artifactId><scope>test</scope></dependency>
  <dependency><groupId>org.testcontainers</groupId><artifactId>mysql</artifactId><scope>test</scope></dependency>
</dependencies>
```

Expected: `./mvnw -version` reports Maven 3.9.11 and Java 21.

- [ ] **Step 2: Write the failing smoke API test**

Create `SmokeApiTest.java`:

```java
@SpringBootTest
@AutoConfigureMockMvc
class SmokeApiTest {
  @Autowired MockMvc mvc;

  @Test
  void healthResponseCarriesTraceId() throws Exception {
    mvc.perform(get("/actuator/health").header("X-Trace-Id", "test-trace"))
        .andExpect(status().isOk())
        .andExpect(header().string("X-Trace-Id", "test-trace"));
  }

  @Test
  void validationErrorsUseTheSharedEnvelope() throws Exception {
    mvc.perform(post("/api/v1/test/validation")
            .contentType(APPLICATION_JSON).content("{}"))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"))
        .andExpect(jsonPath("$.traceId").isNotEmpty());
  }
}
```

- [ ] **Step 3: Run the test and confirm the project is not implemented**

Run: `cd zhidi_server && ./mvnw -Dtest=SmokeApiTest test`

Expected: FAIL because the application, filter and shared exception envelope do not exist.

- [ ] **Step 4: Implement the application and shared response types**

Implement the response record:

```java
public record ApiResponse<T>(String code, String message, T data, String traceId) {
  public static <T> ApiResponse<T> ok(T data, String traceId) {
    return new ApiResponse<>("OK", "success", data, traceId);
  }
  public static ApiResponse<Void> error(String code, String message, String traceId) {
    return new ApiResponse<>(code, message, null, traceId);
  }
}
```

Implement `TraceIdFilter` as a `OncePerRequestFilter`: read `X-Trace-Id`, generate `UUID.randomUUID().toString()` when blank, put it into MDC, attach it to the response, execute the chain, then clear MDC in `finally`.

Implement `GlobalExceptionHandler` with explicit handlers for `BusinessException`, `MethodArgumentNotValidException`, malformed JSON and fallback exceptions. Validation failures return HTTP 400 and `VALIDATION_ERROR`; unhandled failures return HTTP 500 and `INTERNAL_ERROR` without a stack trace in the body.

Configure `application.yml`:

```yaml
spring:
  application:
    name: zhidi-server
  profiles:
    default: dev
  jpa:
    open-in-view: false
    hibernate:
      ddl-auto: validate
  servlet:
    multipart:
      max-file-size: 10MB
      max-request-size: 40MB
management:
  endpoints:
    web:
      exposure:
        include: health,info
  endpoint:
    health:
      probes:
        enabled: true
springdoc:
  swagger-ui:
    path: /swagger-ui.html
```

- [ ] **Step 5: Run smoke tests and commit**

Run: `cd zhidi_server && ./mvnw -Dtest=SmokeApiTest test`

Expected: PASS, actuator health returns HTTP 200 and echoes the trace ID.

Commit:

```bash
git add zhidi_server
git commit -m "feat(server): scaffold Spring Boot API"
```

---

### Task 2: 建立 MySQL 基础模型、Flyway 迁移和容器化测试

**Files:**

- Create: `zhidi_server/src/main/resources/application-dev.yml`
- Create: `zhidi_server/src/main/resources/application-test.yml`
- Create: `zhidi_server/src/main/resources/db/migration/V1__accounts_and_audit.sql`
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/persistence/BaseEntity.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/account/User.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/account/UserRole.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/account/UserRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/audit/OperationLog.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/audit/OperationLogRepository.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/support/MySqlContainerSupport.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/account/UserRepositoryTest.java`

**Interfaces:**

- Produces: `UserRepository.findByPhone(String phone): Optional<User>`.
- Produces: `User.grantRole(Role role)` and `User.hasRole(Role role)`.
- Produces: base columns `id BINARY(16)`, `version BIGINT`, `created_at`, `updated_at` for mutable aggregates.

- [ ] **Step 1: Write the failing MySQL repository test**

Create a reusable Testcontainers base with `@ServiceConnection`:

```java
@Testcontainers
public abstract class MySqlContainerSupport {
  @Container
  @ServiceConnection
  static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4")
      .withDatabaseName("zhidi_test")
      .withUsername("zhidi")
      .withPassword("zhidi_test");
}
```

Create `UserRepositoryTest` extending that base:

```java
@DataJpaTest
@ImportAutoConfiguration(ServiceConnectionAutoConfiguration.class)
class UserRepositoryTest extends MySqlContainerSupport {
  @Autowired UserRepository repository;

  @Test
  void storesOneAccountWithOwnerAndWorkerRoles() {
    User user = User.create("13800138000");
    user.grantRole(Role.OWNER);
    user.grantRole(Role.WORKER);
    repository.saveAndFlush(user);

    User loaded = repository.findByPhone("13800138000").orElseThrow();
    assertThat(loaded.hasRole(Role.OWNER)).isTrue();
    assertThat(loaded.hasRole(Role.WORKER)).isTrue();
  }
}
```

- [ ] **Step 2: Run the test and verify the missing schema failure**

Run: `cd zhidi_server && ./mvnw -Dtest=UserRepositoryTest test`

Expected: FAIL because `users`, `user_roles` and the entity classes do not exist.

- [ ] **Step 3: Add the first Flyway migration**

Create `V1__accounts_and_audit.sql` with these exact constraints:

```sql
CREATE TABLE users (
  id BINARY(16) PRIMARY KEY,
  phone VARCHAR(20) NOT NULL,
  status VARCHAR(32) NOT NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT uk_users_phone UNIQUE (phone)
);

CREATE TABLE user_roles (
  user_id BINARY(16) NOT NULL,
  role VARCHAR(32) NOT NULL,
  PRIMARY KEY (user_id, role),
  CONSTRAINT fk_user_roles_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE operation_logs (
  id BINARY(16) PRIMARY KEY,
  actor_user_id BINARY(16) NULL,
  action VARCHAR(100) NOT NULL,
  target_type VARCHAR(80) NULL,
  target_id VARCHAR(80) NULL,
  result VARCHAR(32) NOT NULL,
  trace_id VARCHAR(64) NOT NULL,
  detail_json JSON NULL,
  created_at DATETIME(6) NOT NULL,
  INDEX idx_operation_actor_time (actor_user_id, created_at),
  INDEX idx_operation_target (target_type, target_id)
);
```

Use Hibernate UUID binary mapping for `BINARY(16)`. `User.status` values are `ACTIVE` and `DISABLED`; `Role` values are `OWNER`, `WORKER`, `ADMIN`.

- [ ] **Step 4: Implement entities and repositories**

`BaseEntity` defines UUID ID, optimistic-lock `@Version long version`, `createdAt`, `updatedAt`, with `@PrePersist` and `@PreUpdate` timestamps. `User.create(phone)` normalizes whitespace, starts as `ACTIVE`, and refuses blank or non-11-digit mainland mobile numbers. Map roles with `@ElementCollection(fetch = EAGER)` to `user_roles`.

Configure development MySQL explicitly:

```yaml
spring:
  datasource:
    url: ${DB_URL:jdbc:mysql://localhost:3306/zhidi?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai}
    username: ${DB_USER:zhidi}
    password: ${DB_PASSWORD:zhidi_dev}
  flyway:
    enabled: true
  jpa:
    properties:
      hibernate:
        type:
          preferred_uuid_jdbc_type: BINARY
```

- [ ] **Step 5: Run migration/repository tests and commit**

Run:

```bash
cd zhidi_server
./mvnw -Dtest=UserRepositoryTest test
./mvnw test
```

Expected: both commands PASS; Flyway applies V1 to the MySQL 8.4 test container and Hibernate schema validation succeeds.

Commit:

```bash
git add zhidi_server
git commit -m "feat(server): add MySQL account foundation"
```

---

### Task 3: 实现手机验证码登录、JWT 会话和角色授权

**Files:**

- Create: `zhidi_server/src/main/resources/db/migration/V2__authentication.sql`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/AuthController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/AuthService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/SmsCode.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/SmsCodeRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/RefreshToken.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/RefreshTokenRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/dto/SendSmsRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/dto/SmsLoginRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/dto/RefreshRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/dto/LogoutRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/dto/TokenResponse.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/sms/SmsSender.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/sms/FixedCodeSmsSender.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/auth/sms/AliyunSmsSender.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/security/JwtService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/security/JwtAuthenticationFilter.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/security/SecurityConfig.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/security/CurrentUser.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/security/CurrentUserArgumentResolver.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/auth/AuthApiTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/auth/RefreshTokenRotationTest.java`

**Interfaces:**

- Produces: `SmsSender.sendLoginCode(String phone, String code, LoginClient client): void`.
- Produces: `JwtService.createAccessToken(UUID userId, Set<Role> roles, UUID sessionId): String`.
- Produces: `JwtService.parseAndValidate(String token): AuthPrincipal`.
- Produces: `TokenResponse(accessToken, refreshToken, expiresInSeconds, userId, roles, workerReviewStatus)`.
- Consumes: `UserRepository.findByPhone(String phone)` from Task 2.

- [ ] **Step 1: Add authentication tables with replay-safe constraints**

Create `V2__authentication.sql`:

```sql
CREATE TABLE sms_codes (
  id BINARY(16) PRIMARY KEY,
  phone VARCHAR(20) NOT NULL,
  purpose VARCHAR(32) NOT NULL,
  client VARCHAR(32) NOT NULL,
  code_hash CHAR(64) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  consumed_at DATETIME(6) NULL,
  failed_attempts INT NOT NULL DEFAULT 0,
  request_ip VARCHAR(64) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  INDEX idx_sms_phone_created (phone, created_at),
  INDEX idx_sms_ip_created (request_ip, created_at)
);

CREATE TABLE refresh_tokens (
  id BINARY(16) PRIMARY KEY,
  user_id BINARY(16) NOT NULL,
  session_id BINARY(16) NOT NULL,
  token_hash CHAR(64) NOT NULL,
  device_id VARCHAR(128) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  revoked_at DATETIME(6) NULL,
  replaced_by BINARY(16) NULL,
  created_at DATETIME(6) NOT NULL,
  CONSTRAINT uk_refresh_hash UNIQUE (token_hash),
  CONSTRAINT fk_refresh_user FOREIGN KEY (user_id) REFERENCES users(id),
  INDEX idx_refresh_session (session_id)
);
```

Hash verification codes and refresh tokens with HMAC-SHA-256 using `AUTH_HASH_SECRET`; never persist their plaintext values.

- [ ] **Step 2: Write failing login and authorization tests**

Create `AuthApiTest` as a MySQL-backed `@SpringBootTest` test:

```java
@Test
void ownerCanLoginWithFixedCodeAndWorkerRoleIsNotGranted() throws Exception {
  mvc.perform(post("/api/v1/auth/sms/send")
      .contentType(APPLICATION_JSON)
      .content(json.writeValueAsString(Map.of(
          "phone", "13800138000", "client", "OWNER_APP"))))
      .andExpect(status().isAccepted());

  String body = mvc.perform(post("/api/v1/auth/sms/login")
      .contentType(APPLICATION_JSON)
      .content(json.writeValueAsString(Map.of(
          "phone", "13800138000", "code", "123456",
          "client", "OWNER_APP", "deviceId", "pixel-9"))))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.data.roles[0]").value("OWNER"))
      .andReturn().getResponse().getContentAsString();

  String accessToken = json.readTree(body).at("/data/accessToken").asText();
  mvc.perform(get("/api/v1/admin/workers/pending")
      .header("Authorization", "Bearer " + accessToken))
      .andExpect(status().isForbidden());
}

@Test
void wrongCodeIsRejectedAndCannotBeReplayed() throws Exception {
  sendCode("13900139000", "WORKER_APP");
  login("13900139000", "000000", "WORKER_APP")
      .andExpect(status().isUnauthorized())
      .andExpect(jsonPath("$.code").value("SMS_CODE_INVALID"));
  login("13900139000", "123456", "WORKER_APP").andExpect(status().isOk());
  login("13900139000", "123456", "WORKER_APP")
      .andExpect(status().isUnauthorized())
      .andExpect(jsonPath("$.code").value("SMS_CODE_CONSUMED"));
}
```

Add cases for an expired code, six failed attempts, five sends per phone per hour, twenty sends per IP per hour, missing bearer token, malformed token and disabled account.

- [ ] **Step 3: Run authentication tests and verify failure**

Run: `cd zhidi_server && ./mvnw -Dtest=AuthApiTest test`

Expected: FAIL because the auth endpoints, security filter and V2 migration are absent.

- [ ] **Step 4: Implement configurable SMS sending and code verification**

Define validated requests:

```java
public record SendSmsRequest(
    @Pattern(regexp = "^1[3-9]\\d{9}$") String phone,
    @NotNull LoginClient client) {}

public record SmsLoginRequest(
    @Pattern(regexp = "^1[3-9]\\d{9}$") String phone,
    @Pattern(regexp = "^\\d{6}$") String code,
    @NotNull LoginClient client,
    @NotBlank @Size(max = 128) String deviceId) {}
```

Use `@ConfigurationProperties(prefix = "zhidi.sms")` with `mode: fixed|aliyun`, `fixed-code`, `ttl-seconds`, sign name and template code. Register `FixedCodeSmsSender` only when `mode=fixed`, and `AliyunSmsSender` only when `mode=aliyun`. The Aliyun adapter generates no code itself; it receives the service-generated six-digit code and calls the official SMS client.

`AuthService.sendCode` must enforce rate limits before saving the HMAC digest. `AuthService.login` loads the newest unconsumed record for the same phone, purpose and client; it rejects expiry and attempts, compares hashes in constant time, then marks the code consumed in the same transaction that creates the session.

Map clients to roles only on the server:

```java
Role requestedRole = switch (request.client()) {
  case OWNER_APP -> Role.OWNER;
  case WORKER_APP -> Role.WORKER;
};
```

Never accept a role string from the client. A first owner login grants `OWNER`; a first worker login grants `WORKER` and creates its incomplete profile in Task 4.

- [ ] **Step 5: Implement JWT access tokens and rotating refresh tokens**

Configure:

```yaml
zhidi:
  auth:
    jwt-secret: ${JWT_SECRET}
    hash-secret: ${AUTH_HASH_SECRET}
    access-token-seconds: 1800
    refresh-token-seconds: 2592000
```

Use a minimum 256-bit JWT HMAC secret. Access token claims are `sub` (user UUID), `sid` (session UUID), `roles`, `iat` and `exp`. Generate refresh tokens with 32 random bytes from `SecureRandom`, Base64URL-encode them, and store only the HMAC digest.

`POST /refresh` performs a single transaction: lock the stored refresh token, reject expired/revoked tokens, revoke it, create a replacement in the same session, set `replaced_by`, and return a new access/refresh pair. If a revoked token is reused, revoke all active tokens for that session and return `REFRESH_TOKEN_REUSED`.

Create `RefreshTokenRotationTest`:

```java
@Test
void refreshTokenCanBeUsedOnlyOnce() {
  TokenResponse first = auth.login(validWorkerLogin());
  TokenResponse second = auth.refresh(first.refreshToken(), "pixel-9");
  assertThat(second.refreshToken()).isNotEqualTo(first.refreshToken());
  assertThatThrownBy(() -> auth.refresh(first.refreshToken(), "pixel-9"))
      .isInstanceOfSatisfying(BusinessException.class,
          ex -> assertThat(ex.code()).isEqualTo("REFRESH_TOKEN_REUSED"));
}
```

- [ ] **Step 6: Configure stateless security and ownership-ready principals**

`SecurityConfig` must disable server sessions, CSRF form handling and HTTP Basic; allow `/api/v1/auth/**`, payment notification endpoints, `/actuator/health/**` and OpenAPI paths; require authentication elsewhere. Add `JwtAuthenticationFilter` before `UsernamePasswordAuthenticationFilter`.

`CurrentUser` contains only `UUID userId`, `UUID sessionId` and immutable roles. `CurrentUserArgumentResolver` resolves authenticated controllers without exposing raw JWT parsing to business modules.

Enable method security so admin controllers can use:

```java
@PreAuthorize("hasRole('ADMIN')")
```

Configure CORS from `ALLOWED_ORIGINS`; production does not use `*`. Return the shared API envelope for 401 and 403 responses with codes `UNAUTHENTICATED` and `FORBIDDEN`.

- [ ] **Step 7: Run security tests and commit**

Run:

```bash
cd zhidi_server
./mvnw -Dtest=AuthApiTest,RefreshTokenRotationTest test
./mvnw test
```

Expected: PASS. The full suite confirms MySQL migrations V1/V2, one-time codes, role separation, token rotation and protected endpoints.

Commit:

```bash
git add zhidi_server
git commit -m "feat(server): add SMS login and JWT sessions"
```

---

### Task 4: 实现工人资料、认证审核和公开师傅查询

**Files:**

- Create: `zhidi_server/src/main/resources/db/migration/V3__owner_and_worker_profiles.sql`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfile.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/worker/TradeType.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/worker/WorkerReviewStatus.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/worker/WorkerProfile.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/worker/WorkerReviewRecord.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/worker/WorkerProfileRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/worker/WorkerReviewRecordRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/worker/WorkerProfileService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/worker/WorkerReviewService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/worker/WorkerController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/worker/AdminWorkerController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/worker/dto/UpdateWorkerProfileRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/worker/dto/WorkerSummaryResponse.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/worker/dto/WorkerDetailResponse.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/worker/WorkerReviewApiTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/worker/WorkerDirectoryApiTest.java`

**Interfaces:**

- Produces: `WorkerProfileService.ensureProfile(UUID userId): WorkerProfile`, called after first `WORKER_APP` login in Task 3.
- Produces: `WorkerProfileService.getApprovedWorker(UUID workerId): WorkerDetailResponse`.
- Produces: `WorkerProfileRepository.findApprovedAvailableByTrade(TradeType trade, Pageable pageable): Page<WorkerProfile>`.
- Produces: immutable public identity fields `workerId`, `fullName`, `trade`, used later by appointments, projects and Flutter DTOs.
- Consumes: authenticated `CurrentUser` and `User` from Tasks 2–3.

- [ ] **Step 1: Create profile and review schema**

Create `V3__owner_and_worker_profiles.sql`:

```sql
CREATE TABLE owner_profiles (
  id BINARY(16) PRIMARY KEY,
  user_id BINARY(16) NOT NULL,
  display_name VARCHAR(50) NOT NULL,
  city VARCHAR(50) NOT NULL DEFAULT '',
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT uk_owner_user UNIQUE (user_id),
  CONSTRAINT fk_owner_user FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE worker_profiles (
  id BINARY(16) PRIMARY KEY,
  user_id BINARY(16) NOT NULL,
  full_name VARCHAR(50) NOT NULL DEFAULT '',
  avatar_file_id BINARY(16) NULL,
  trade VARCHAR(32) NULL,
  experience_years INT NOT NULL DEFAULT 0,
  service_city VARCHAR(50) NOT NULL DEFAULT '',
  service_districts_json JSON NULL,
  introduction VARCHAR(500) NOT NULL DEFAULT '',
  review_status VARCHAR(32) NOT NULL,
  accepting_orders BOOLEAN NOT NULL DEFAULT FALSE,
  rating DECIMAL(2,1) NOT NULL DEFAULT 5.0,
  completed_order_count INT NOT NULL DEFAULT 0,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT uk_worker_user UNIQUE (user_id),
  CONSTRAINT ck_worker_experience CHECK (experience_years BETWEEN 0 AND 60),
  INDEX idx_worker_directory (review_status, accepting_orders, trade, service_city)
);

CREATE TABLE worker_review_records (
  id BINARY(16) PRIMARY KEY,
  worker_id BINARY(16) NOT NULL,
  reviewer_user_id BINARY(16) NOT NULL,
  from_status VARCHAR(32) NOT NULL,
  to_status VARCHAR(32) NOT NULL,
  reason VARCHAR(500) NULL,
  reviewed_at DATETIME(6) NOT NULL,
  CONSTRAINT fk_review_worker FOREIGN KEY (worker_id) REFERENCES worker_profiles(id),
  CONSTRAINT fk_review_admin FOREIGN KEY (reviewer_user_id) REFERENCES users(id),
  INDEX idx_review_worker_time (worker_id, reviewed_at)
);
```

The `avatar_file_id` foreign key is added in Task 7 after `file_objects` exists. Until then it remains a nullable UUID reference value without a database foreign key.

- [ ] **Step 2: Write failing review and visibility tests**

Create `WorkerReviewApiTest`:

```java
@Test
void workerMustCompleteProfileAndReceiveAdminApproval() throws Exception {
  String workerToken = loginAsWorker("13900139000");

  mvc.perform(put("/api/v1/workers/me/profile")
      .header(AUTHORIZATION, bearer(workerToken))
      .contentType(APPLICATION_JSON)
      .content(workerProfileJson("张三", "PLUMBING", 10, "成都")))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.data.reviewStatus").value("PENDING_REVIEW"))
      .andExpect(jsonPath("$.data.acceptingOrders").value(false));

  mvc.perform(get("/api/v1/workers").param("trade", "PLUMBING"))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.data.content").isEmpty());

  String adminToken = loginAsAdmin();
  UUID workerId = workerIdForPhone("13900139000");
  mvc.perform(post("/api/v1/admin/workers/{id}/approve", workerId)
      .header(AUTHORIZATION, bearer(adminToken)))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.data.reviewStatus").value("APPROVED"));
}

@Test
void rejectionRequiresReasonAndResubmissionPreservesHistory() throws Exception {
  UUID workerId = submittedWorker("周建平", TradeType.MASONRY);
  mvc.perform(post("/api/v1/admin/workers/{id}/reject", workerId)
      .header(AUTHORIZATION, bearer(loginAsAdmin()))
      .contentType(APPLICATION_JSON).content("{\"reason\":\"证件照片不清晰\"}"))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.data.reviewStatus").value("REJECTED"));
  assertThat(reviewRepository.findByWorkerIdOrderByReviewedAtAsc(workerId)).hasSize(1);
}
```

Also test that a non-admin cannot approve, an incomplete worker cannot submit, and an approved worker editing identity/trade returns to `PENDING_REVIEW` and becomes hidden.

- [ ] **Step 3: Write the failing public directory identity test**

Create `WorkerDirectoryApiTest`:

```java
@Test
void listAndDetailReturnTheSameIdFullNameAndTrade() throws Exception {
  UUID workerId = approvedAvailableWorker("陈志远", TradeType.PLUMBING, "成都");

  String listBody = mvc.perform(get("/api/v1/workers")
      .param("trade", "PLUMBING").param("city", "成都"))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.data.content[0].workerId").value(workerId.toString()))
      .andExpect(jsonPath("$.data.content[0].fullName").value("陈志远"))
      .andReturn().getResponse().getContentAsString();

  mvc.perform(get("/api/v1/workers/{id}", workerId))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.data.workerId").value(workerId.toString()))
      .andExpect(jsonPath("$.data.fullName").value("陈志远"))
      .andExpect(jsonPath("$.data.trade").value("PLUMBING"));
}

@Test
void unapprovedOrUnavailableWorkerIsNeverPublic() throws Exception {
  UUID pending = pendingWorker("测试师傅", TradeType.DEMOLITION);
  mvc.perform(get("/api/v1/workers/{id}", pending))
      .andExpect(status().isNotFound())
      .andExpect(jsonPath("$.code").value("WORKER_NOT_FOUND"));
}
```

- [ ] **Step 4: Run worker tests and verify failure**

Run: `cd zhidi_server && ./mvnw -Dtest=WorkerReviewApiTest,WorkerDirectoryApiTest test`

Expected: FAIL because the profile schema, state machine and endpoints are absent.

- [ ] **Step 5: Implement profile completion and review state machine**

Define canonical trades:

```java
public enum TradeType {
  DEMOLITION, PLUMBING, WATERPROOFING, MASONRY,
  CARPENTRY, PAINTING, INSTALLATION, QUOTATION
}
```

Map the Flutter labels only in DTOs: 拆除、水电、防水、泥瓦、木工、油漆、安装、报价. Do not persist localized labels as keys.

Define review states:

```java
public enum WorkerReviewStatus {
  PROFILE_INCOMPLETE, PENDING_REVIEW, APPROVED, REJECTED
}
```

`ensureProfile` creates exactly one `PROFILE_INCOMPLETE` row for a worker user. Profile submission requires nonblank full name, trade, service city, introduction of at most 500 characters and experience between 0 and 60. A complete submission moves to `PENDING_REVIEW` and forces `acceptingOrders=false`.

`approve` is legal only from `PENDING_REVIEW`, records the transition, and does not automatically open availability; the worker must explicitly enable it. `reject` requires a 2–500 character reason. Editing `fullName` or `trade` after approval returns the profile to `PENDING_REVIEW` and hides it; editing only introduction or service districts preserves approval.

- [ ] **Step 6: Implement public directory and owner profile endpoints**

Expose:

```text
PUT /api/v1/owners/me
PUT /api/v1/workers/me/profile
PUT /api/v1/workers/me/availability
GET /api/v1/workers?trade=PLUMBING&city=成都&page=0&size=20
GET /api/v1/workers/{workerId}
GET /api/v1/admin/workers/pending?page=0&size=20
POST /api/v1/admin/workers/{workerId}/approve
POST /api/v1/admin/workers/{workerId}/reject
```

`availability=true` requires `APPROVED`; otherwise return HTTP 409 with `WORKER_NOT_APPROVED`. Public summary and detail use the same mapper and always return `workerId`, `fullName`, `trade`, `tradeLabel`, avatar reference, experience, city, rating, completed count, review badge and availability. Never abbreviate `fullName` to “张师傅” or reconstruct it from the phone number.

Seed the first admin through environment variables `BOOTSTRAP_ADMIN_PHONE` and `BOOTSTRAP_ADMIN_ENABLED=true`. The bootstrap runner grants `ADMIN` only when explicitly enabled and logs the action; public auth endpoints can never grant it.

- [ ] **Step 7: Run worker module and full tests, then commit**

Run:

```bash
cd zhidi_server
./mvnw -Dtest=WorkerReviewApiTest,WorkerDirectoryApiTest test
./mvnw test
```

Expected: PASS. Pending/rejected workers remain hidden; approved available workers appear once; list and detail return identical ID, full name and trade.

Commit:

```bash
git add zhidi_server
git commit -m "feat(server): add verified worker directory"
```

---

### Task 5: 实现预约、接单和版本化人工/辅材报价

**Files:**

- Create: `zhidi_server/src/main/resources/db/migration/V4__appointments_and_quotes.sql`
- Create: `zhidi_server/src/main/java/com/zhidi/server/appointment/Appointment.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/appointment/AppointmentStatus.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/appointment/AppointmentStatusHistory.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/appointment/AppointmentRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/appointment/AppointmentService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/appointment/AppointmentController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/appointment/WorkerAppointmentController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/appointment/dto/CreateAppointmentRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/appointment/dto/AppointmentResponse.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/quotation/Quote.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/quotation/QuoteItem.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/quotation/QuoteStatus.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/quotation/QuoteRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/quotation/QuotationService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/quotation/QuotationController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/quotation/dto/SubmitQuoteRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/quotation/dto/QuoteResponse.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/appointment/AppointmentFlowApiTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/quotation/QuotationFlowApiTest.java`

**Interfaces:**

- Produces: `AppointmentService.create(UUID ownerUserId, CreateAppointmentRequest request, String idempotencyKey): AppointmentResponse`.
- Produces: `AppointmentService.accept(UUID workerUserId, UUID appointmentId): AppointmentResponse`.
- Produces: `QuotationService.submit(UUID workerUserId, UUID appointmentId, SubmitQuoteRequest request): QuoteResponse`.
- Produces: confirmed quote totals `laborTotalFen`, `materialTotalFen`, `grandTotalFen`, consumed by Task 6 projects and Task 8 payment plans.
- Consumes: approved worker identity from Task 4 and authenticated owner/worker principals from Task 3.

- [ ] **Step 1: Add appointment, status history and quote schema**

Create `V4__appointments_and_quotes.sql`:

```sql
CREATE TABLE appointments (
  id BINARY(16) PRIMARY KEY,
  owner_user_id BINARY(16) NOT NULL,
  target_worker_id BINARY(16) NULL,
  assigned_worker_id BINARY(16) NULL,
  trade VARCHAR(32) NOT NULL,
  city VARCHAR(50) NOT NULL,
  district VARCHAR(50) NOT NULL,
  address_detail VARCHAR(255) NOT NULL,
  area_sqm DECIMAL(8,2) NOT NULL,
  expected_visit_at DATETIME(6) NOT NULL,
  description VARCHAR(1000) NOT NULL DEFAULT '',
  status VARCHAR(40) NOT NULL,
  cancel_reason VARCHAR(500) NULL,
  idempotency_key VARCHAR(64) NOT NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT uk_appointment_owner_key UNIQUE (owner_user_id, idempotency_key),
  CONSTRAINT fk_appointment_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
  CONSTRAINT fk_appointment_target FOREIGN KEY (target_worker_id) REFERENCES worker_profiles(id),
  CONSTRAINT fk_appointment_assigned FOREIGN KEY (assigned_worker_id) REFERENCES worker_profiles(id),
  CONSTRAINT ck_appointment_area CHECK (area_sqm > 0 AND area_sqm <= 99999),
  INDEX idx_appointment_owner_time (owner_user_id, created_at),
  INDEX idx_appointment_worker_status (assigned_worker_id, status, created_at),
  INDEX idx_appointment_target_status (target_worker_id, status, created_at)
);

CREATE TABLE appointment_status_history (
  id BINARY(16) PRIMARY KEY,
  appointment_id BINARY(16) NOT NULL,
  from_status VARCHAR(40) NULL,
  to_status VARCHAR(40) NOT NULL,
  actor_user_id BINARY(16) NOT NULL,
  reason VARCHAR(500) NULL,
  changed_at DATETIME(6) NOT NULL,
  CONSTRAINT fk_appointment_history FOREIGN KEY (appointment_id) REFERENCES appointments(id),
  INDEX idx_appointment_history_time (appointment_id, changed_at)
);

CREATE TABLE quotes (
  id BINARY(16) PRIMARY KEY,
  appointment_id BINARY(16) NOT NULL,
  version_number INT NOT NULL,
  labor_total_fen BIGINT NOT NULL,
  material_total_fen BIGINT NOT NULL,
  grand_total_fen BIGINT NOT NULL,
  status VARCHAR(40) NOT NULL,
  worker_note VARCHAR(1000) NOT NULL DEFAULT '',
  owner_rejection_reason VARCHAR(500) NULL,
  submitted_at DATETIME(6) NOT NULL,
  decided_at DATETIME(6) NULL,
  row_version BIGINT NOT NULL DEFAULT 0,
  CONSTRAINT uk_quote_appointment_version UNIQUE (appointment_id, version_number),
  CONSTRAINT fk_quote_appointment FOREIGN KEY (appointment_id) REFERENCES appointments(id),
  CONSTRAINT ck_quote_totals CHECK (
    labor_total_fen >= 0 AND material_total_fen >= 0
    AND grand_total_fen = labor_total_fen + material_total_fen
  ),
  INDEX idx_quote_appointment_status (appointment_id, status)
);

CREATE TABLE quote_items (
  id BINARY(16) PRIMARY KEY,
  quote_id BINARY(16) NOT NULL,
  item_type VARCHAR(20) NOT NULL,
  name VARCHAR(100) NOT NULL,
  unit VARCHAR(20) NOT NULL,
  quantity DECIMAL(12,3) NOT NULL,
  unit_price_fen BIGINT NOT NULL,
  subtotal_fen BIGINT NOT NULL,
  sort_order INT NOT NULL,
  CONSTRAINT fk_quote_item_quote FOREIGN KEY (quote_id) REFERENCES quotes(id),
  CONSTRAINT ck_quote_item_type CHECK (item_type IN ('LABOR', 'MATERIAL')),
  CONSTRAINT ck_quote_item_amount CHECK (
    quantity > 0 AND unit_price_fen >= 0 AND subtotal_fen >= 0
  )
);
```

- [ ] **Step 2: Write failing appointment tests for identity, multiplicity and locking**

Create `AppointmentFlowApiTest`:

```java
@Test
void ownerCanCreateMultipleServicesIncludingTheSameTrade() throws Exception {
  UUID workerA = approvedAvailableWorker("陈志远", TradeType.PLUMBING, "成都");
  UUID workerB = approvedAvailableWorker("赵大国", TradeType.PLUMBING, "成都");
  String ownerToken = loginAsOwner("13800138000");

  UUID first = createAppointment(ownerToken, workerA, "PLUMBING", "bathroom-1");
  UUID second = createAppointment(ownerToken, workerB, "PLUMBING", "kitchen-1");

  mvc.perform(get("/api/v1/appointments").header(AUTHORIZATION, bearer(ownerToken)))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.data.content.length()").value(2))
      .andExpect(jsonPath("$.data.content[?(@.id=='" + first + "')]").exists())
      .andExpect(jsonPath("$.data.content[?(@.id=='" + second + "')]").exists());
}

@Test
void repeatedIdempotencyKeyReturnsTheOriginalAppointment() throws Exception {
  String token = loginAsOwner("13800138001");
  UUID worker = approvedAvailableWorker("钟国强", TradeType.WATERPROOFING, "成都");
  UUID first = createAppointment(token, worker, "WATERPROOFING", "same-key");
  UUID repeated = createAppointment(token, worker, "WATERPROOFING", "same-key");
  assertThat(repeated).isEqualTo(first);
  assertThat(appointmentRepository.count()).isEqualTo(1);
}

@Test
void onlyTheTargetApprovedWorkerCanAcceptOnce() throws Exception {
  Appointment appointment = directedAppointmentFor("陈志远", TradeType.PLUMBING);
  mvc.perform(post("/api/v1/worker/appointments/{id}/accept", appointment.getId())
      .header(AUTHORIZATION, bearer(loginDifferentWorker())))
      .andExpect(status().isForbidden())
      .andExpect(jsonPath("$.code").value("APPOINTMENT_NOT_ASSIGNED_TO_WORKER"));
  acceptAsTarget(appointment).andExpect(status().isOk());
  acceptAsTarget(appointment).andExpect(status().isConflict())
      .andExpect(jsonPath("$.code").value("APPOINTMENT_STATE_CONFLICT"));
}
```

Also test that a worker whose approval is revoked cannot accept, and that worker responses reveal the complete address only after successful acceptance.

- [ ] **Step 3: Write failing quote calculation and version tests**

Create `QuotationFlowApiTest`:

```java
@Test
void serverCalculatesLaborMaterialAndGrandTotals() throws Exception {
  AcceptedAppointment accepted = acceptedAppointment();
  String request = """
      {"items":[
        {"type":"LABOR","name":"水管布置","unit":"米","quantity":20,"unitPriceFen":8000},
        {"type":"LABOR","name":"开槽","unit":"米","quantity":10,"unitPriceFen":3000},
        {"type":"MATERIAL","name":"PPR水管","unit":"米","quantity":20,"unitPriceFen":2500}
      ],"workerNote":"固定工价，报价透明"}
      """;
  mvc.perform(post("/api/v1/worker/appointments/{id}/quotes", accepted.id())
      .header(AUTHORIZATION, bearer(accepted.workerToken()))
      .contentType(APPLICATION_JSON).content(request))
      .andExpect(status().isCreated())
      .andExpect(jsonPath("$.data.laborTotalFen").value(190000))
      .andExpect(jsonPath("$.data.materialTotalFen").value(50000))
      .andExpect(jsonPath("$.data.grandTotalFen").value(240000));
}

@Test
void rejectedQuoteRemainsAndNextSubmissionGetsNewVersion() throws Exception {
  Flow flow = submittedQuote();
  rejectQuote(flow.ownerToken(), flow.quoteId(), "辅材型号需要调整");
  UUID secondQuote = submitReplacement(flow.workerToken(), flow.appointmentId());
  assertThat(quoteRepository.findByAppointmentIdOrderByVersionNumberAsc(flow.appointmentId()))
      .extracting(Quote::getVersionNumber, Quote::getStatus)
      .containsExactly(tuple(1, QuoteStatus.REJECTED), tuple(2, QuoteStatus.SUBMITTED));
}
```

Also test quantity scale, negative prices, more than 100 items, zero grand total, a non-assigned worker submitting a quote, an owner confirming another owner's quote and double confirmation.

- [ ] **Step 4: Run the flow tests and verify failure**

Run: `cd zhidi_server && ./mvnw -Dtest=AppointmentFlowApiTest,QuotationFlowApiTest test`

Expected: FAIL because V4, appointment endpoints and quote calculation do not exist.

- [ ] **Step 5: Implement appointment privacy and state transitions**

Define appointment statuses:

```java
public enum AppointmentStatus {
  PENDING, ACCEPTED, QUOTING, QUOTE_PENDING_CONFIRMATION,
  QUOTE_REJECTED, READY_TO_START, IN_PROGRESS,
  INSPECTION, COMPLETED, REJECTED, CANCELLED
}
```

Creation validates that the selected worker is `APPROVED`, available, serves the requested trade and city. It persists the target `workerId`, not the worker name. The response joins the current canonical full name from `worker_profiles`.

Before acceptance, the worker DTO exposes `city + district` and masks the detailed address. `accept` locks the appointment with `PESSIMISTIC_WRITE`, verifies the authenticated worker matches `target_worker_id`, sets both `assigned_worker_id` and `ACCEPTED`, and records status history. Rejection requires a reason and preserves the appointment.

Owner list endpoints filter strictly by `owner_user_id`; worker list endpoints filter by target/assigned worker profile ID. Pagination defaults to 20 and caps at 100.

- [ ] **Step 6: Implement immutable quote versions and server-side totals**

`SubmitQuoteRequest` accepts 1–100 items. For each item calculate subtotal with `quantity.multiply(unitPriceFen).setScale(0, HALF_UP).longValueExact()`. Sum subtotals by type, then compute `grandTotalFen = laborTotalFen + materialTotalFen`; reject overflow with `QUOTE_AMOUNT_TOO_LARGE` and cap one quote at 100,000,000 fen.

Submission is allowed only for the assigned worker while the appointment is `ACCEPTED`, `QUOTING` or `QUOTE_REJECTED`. The next version is `max(version_number)+1`; save items and transition the appointment to `QUOTE_PENDING_CONFIRMATION` in one transaction.

Only the appointment owner can confirm or reject the latest `SUBMITTED` quote. Confirmation sets the quote to `CONFIRMED` and appointment to `READY_TO_START`; rejection requires a reason, sets `REJECTED` and transitions the appointment to `QUOTE_REJECTED`. Existing quote rows and items are never updated into a replacement version.

- [ ] **Step 7: Run appointment/quotation tests and commit**

Run:

```bash
cd zhidi_server
./mvnw -Dtest=AppointmentFlowApiTest,QuotationFlowApiTest test
./mvnw test
```

Expected: PASS. Multiple same-trade services remain distinct, idempotency prevents duplicate creation, only the target worker accepts, and all quote totals are computed by the server.

Commit:

```bash
git add zhidi_server
git commit -m "feat(server): add appointment and quotation flow"
```

---

### Task 6: 实现施工项目、工序进度、施工日志和节点验收

**Files:**

- Create: `zhidi_server/src/main/resources/db/migration/V5__projects_logs_and_inspections.sql`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/Project.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/ProjectStage.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/ProjectStatus.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/StageStatus.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/ConstructionLog.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/ConstructionLogType.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/Inspection.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/InspectionStatus.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/ProjectRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/ProjectStageRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/ConstructionLogRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/InspectionRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/ProjectService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/ConstructionLogService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/InspectionService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/ProjectController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/WorkerProjectController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/dto/ProjectDetailResponse.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/dto/CreateConstructionLogRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/project/dto/SubmitInspectionRequest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/project/ProjectCreationTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/project/ConstructionFlowApiTest.java`

**Interfaces:**

- Produces: `ProjectService.createFromConfirmedQuote(UUID appointmentId, UUID quoteId): Project`.
- Produces: `ProjectService.detail(UUID actorUserId, UUID projectId): ProjectDetailResponse`.
- Produces: `ConstructionLogService.create(UUID workerUserId, UUID projectId, CreateConstructionLogRequest request)`.
- Produces: `InspectionService.approve(UUID ownerUserId, UUID inspectionId, String comment)` and `reject(...)`.
- Consumes: canonical worker identity and confirmed quotation totals from Tasks 4–5.
- File IDs remain UUID references in this task; Task 7 enforces their existence and access rules.

- [ ] **Step 1: Add project, stage, log and inspection schema**

Create `V5__projects_logs_and_inspections.sql`:

```sql
CREATE TABLE projects (
  id BINARY(16) PRIMARY KEY,
  appointment_id BINARY(16) NOT NULL,
  confirmed_quote_id BINARY(16) NOT NULL,
  owner_user_id BINARY(16) NOT NULL,
  worker_id BINARY(16) NOT NULL,
  trade VARCHAR(32) NOT NULL,
  status VARCHAR(32) NOT NULL,
  started_at DATETIME(6) NULL,
  completed_at DATETIME(6) NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT uk_project_appointment UNIQUE (appointment_id),
  CONSTRAINT fk_project_appointment FOREIGN KEY (appointment_id) REFERENCES appointments(id),
  CONSTRAINT fk_project_quote FOREIGN KEY (confirmed_quote_id) REFERENCES quotes(id),
  CONSTRAINT fk_project_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
  CONSTRAINT fk_project_worker FOREIGN KEY (worker_id) REFERENCES worker_profiles(id),
  INDEX idx_project_owner_status (owner_user_id, status, updated_at),
  INDEX idx_project_worker_status (worker_id, status, updated_at)
);

CREATE TABLE project_stages (
  id BINARY(16) PRIMARY KEY,
  project_id BINARY(16) NOT NULL,
  trade VARCHAR(32) NOT NULL,
  stage_name VARCHAR(80) NOT NULL,
  sequence_number INT NOT NULL,
  status VARCHAR(32) NOT NULL,
  started_at DATETIME(6) NULL,
  completed_at DATETIME(6) NULL,
  version BIGINT NOT NULL DEFAULT 0,
  CONSTRAINT uk_project_stage_sequence UNIQUE (project_id, sequence_number),
  CONSTRAINT fk_stage_project FOREIGN KEY (project_id) REFERENCES projects(id),
  INDEX idx_stage_project_status (project_id, status)
);

CREATE TABLE construction_logs (
  id BINARY(16) PRIMARY KEY,
  project_id BINARY(16) NOT NULL,
  stage_id BINARY(16) NOT NULL,
  worker_id BINARY(16) NOT NULL,
  log_type VARCHAR(32) NOT NULL,
  work_date DATE NOT NULL,
  title VARCHAR(100) NOT NULL,
  content VARCHAR(2000) NOT NULL,
  craftsmanship VARCHAR(2000) NOT NULL DEFAULT '',
  acceptance_standard VARCHAR(2000) NOT NULL DEFAULT '',
  created_at DATETIME(6) NOT NULL,
  CONSTRAINT fk_log_project FOREIGN KEY (project_id) REFERENCES projects(id),
  CONSTRAINT fk_log_stage FOREIGN KEY (stage_id) REFERENCES project_stages(id),
  CONSTRAINT fk_log_worker FOREIGN KEY (worker_id) REFERENCES worker_profiles(id),
  INDEX idx_log_project_date (project_id, work_date, created_at),
  INDEX idx_log_stage_type (stage_id, log_type)
);

CREATE TABLE construction_log_files (
  construction_log_id BINARY(16) NOT NULL,
  file_id BINARY(16) NOT NULL,
  sort_order INT NOT NULL,
  PRIMARY KEY (construction_log_id, file_id),
  CONSTRAINT fk_log_file_log FOREIGN KEY (construction_log_id) REFERENCES construction_logs(id)
);

CREATE TABLE inspections (
  id BINARY(16) PRIMARY KEY,
  project_id BINARY(16) NOT NULL,
  stage_id BINARY(16) NOT NULL,
  submission_number INT NOT NULL,
  status VARCHAR(32) NOT NULL,
  worker_comment VARCHAR(1000) NOT NULL DEFAULT '',
  owner_comment VARCHAR(1000) NULL,
  submitted_at DATETIME(6) NOT NULL,
  decided_at DATETIME(6) NULL,
  decided_by BINARY(16) NULL,
  version BIGINT NOT NULL DEFAULT 0,
  CONSTRAINT uk_inspection_submission UNIQUE (stage_id, submission_number),
  CONSTRAINT fk_inspection_project FOREIGN KEY (project_id) REFERENCES projects(id),
  CONSTRAINT fk_inspection_stage FOREIGN KEY (stage_id) REFERENCES project_stages(id),
  CONSTRAINT fk_inspection_owner FOREIGN KEY (decided_by) REFERENCES users(id),
  INDEX idx_inspection_stage_status (stage_id, status)
);

CREATE TABLE inspection_files (
  inspection_id BINARY(16) NOT NULL,
  file_id BINARY(16) NOT NULL,
  sort_order INT NOT NULL,
  PRIMARY KEY (inspection_id, file_id),
  CONSTRAINT fk_inspection_file_inspection FOREIGN KEY (inspection_id) REFERENCES inspections(id)
);
```

- [ ] **Step 2: Write failing project creation and multi-service tests**

Create `ProjectCreationTest`:

```java
@Test
void confirmingAQuoteCreatesExactlyOneProjectWithCanonicalIdentity() {
  ConfirmedFlow flow = confirmedQuote("陈志远", TradeType.PLUMBING);
  Project project = projectService.createFromConfirmedQuote(
      flow.appointmentId(), flow.quoteId());

  ProjectDetailResponse detail = projectService.detail(flow.ownerUserId(), project.getId());
  assertThat(detail.worker().workerId()).isEqualTo(flow.workerId());
  assertThat(detail.worker().fullName()).isEqualTo("陈志远");
  assertThat(detail.trade()).isEqualTo(TradeType.PLUMBING);
  assertThat(detail.quote().grandTotalFen()).isEqualTo(flow.grandTotalFen());
  assertThat(detail.stages()).isNotEmpty();
}

@Test
void ownerProjectListDoesNotCollapseProjectsWithTheSameTrade() {
  UUID owner = owner("13800138000");
  createProject(owner, "陈志远", TradeType.PLUMBING);
  createProject(owner, "赵大国", TradeType.PLUMBING);
  assertThat(projectService.listForOwner(owner, PageRequest.of(0, 20)).getTotalElements())
      .isEqualTo(2);
}

@Test
void repeatedCreationReturnsTheExistingProject() {
  ConfirmedFlow flow = confirmedQuote("钟国强", TradeType.WATERPROOFING);
  Project first = projectService.createFromConfirmedQuote(flow.appointmentId(), flow.quoteId());
  Project second = projectService.createFromConfirmedQuote(flow.appointmentId(), flow.quoteId());
  assertThat(second.getId()).isEqualTo(first.getId());
}
```

- [ ] **Step 3: Write failing construction, inspection and rectification tests**

Create `ConstructionFlowApiTest`:

```java
@Test
void workerRecordsEntryDailyWorkAndInspectionWithCraftStandards() throws Exception {
  ActiveProject flow = activeProject(TradeType.WATERPROOFING);
  UUID stageId = flow.firstStageId();

  startStage(flow.workerToken(), flow.projectId(), stageId).andExpect(status().isOk());
  createLog(flow.workerToken(), flow.projectId(), stageId, "SITE_ENTRY",
      "进场保护", "门窗及公共区域完成保护", "保护膜完整无破损", List.of(fileId()))
      .andExpect(status().isCreated());
  createLog(flow.workerToken(), flow.projectId(), stageId, "DAILY",
      "基层处理", "阴角做圆弧处理", "基层牢固平整", List.of(fileId(), fileId()))
      .andExpect(status().isCreated());

  UUID inspectionId = submitInspection(flow.workerToken(), flow.projectId(), stageId);
  mvc.perform(get("/api/v1/projects/{id}", flow.projectId())
      .header(AUTHORIZATION, bearer(flow.ownerToken())))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.data.stages[0].status").value("PENDING_INSPECTION"))
      .andExpect(jsonPath("$.data.logs.length()").value(2))
      .andExpect(jsonPath("$.data.logs[1].craftsmanship").value("阴角做圆弧处理"))
      .andExpect(jsonPath("$.data.pendingInspection.id").value(inspectionId.toString()));
}

@Test
void rejectedInspectionRequiresRectificationAndKeepsBothSubmissions() throws Exception {
  InspectionFlow flow = pendingInspection();
  rejectInspection(flow.ownerToken(), flow.inspectionId(), "闭水高度不足");
  assertThat(stage(flow.stageId()).getStatus()).isEqualTo(StageStatus.RECTIFICATION);

  createRectificationLog(flow.workerToken(), flow.projectId(), flow.stageId());
  UUID second = submitInspection(flow.workerToken(), flow.projectId(), flow.stageId());
  approveInspection(flow.ownerToken(), second, "验收通过");

  assertThat(inspectionRepository.findByStageIdOrderBySubmissionNumberAsc(flow.stageId()))
      .extracting(Inspection::getSubmissionNumber, Inspection::getStatus)
      .containsExactly(tuple(1, InspectionStatus.REJECTED),
          tuple(2, InspectionStatus.APPROVED));
  assertThat(stage(flow.stageId()).getStatus()).isEqualTo(StageStatus.COMPLETED);
}
```

Also test a different worker adding logs, an unrelated owner reading the project, starting two stages simultaneously for a single-trade project, submitting inspection without photos, approving another owner's inspection and completing a project before every required stage is completed.

- [ ] **Step 4: Run project tests and verify failure**

Run: `cd zhidi_server && ./mvnw -Dtest=ProjectCreationTest,ConstructionFlowApiTest test`

Expected: FAIL because V5 and project services do not exist.

- [ ] **Step 5: Implement project creation and canonical stage templates**

Define:

```java
public enum ProjectStatus { READY_TO_START, IN_PROGRESS, INSPECTION, COMPLETED, CANCELLED }
public enum StageStatus { NOT_STARTED, IN_PROGRESS, PENDING_INSPECTION, RECTIFICATION, COMPLETED }
public enum ConstructionLogType { SITE_ENTRY, DAILY, RECTIFICATION, NODE_ACCEPTANCE }
public enum InspectionStatus { PENDING, APPROVED, REJECTED }
```

For a single-trade appointment, create one required stage named from its trade. For a future whole-home appointment, use this canonical sequence: demolition 1, plumbing 2, waterproofing 3, masonry 4, carpentry 5, painting 6, installation 7. `QUOTATION` is a service type and never becomes a construction stage.

`createFromConfirmedQuote` validates the quote belongs to the appointment and is `CONFIRMED`; the unique appointment constraint makes retries return the existing project. Copy only stable IDs and trade to the project. Project response joins current worker full name and avatar so every screen displays the same identity.

Owner lists query by `owner_user_id`; worker lists query by `worker_id`; neither query groups or deduplicates by trade. Detail access is limited to the project owner, assigned worker or admin.

- [ ] **Step 6: Implement logs, inspections and project completion**

Only the assigned worker can start stages, create logs or submit inspections. A log requires title, content, valid work date, 0–9 file IDs, and its stage must belong to the same project. Node inspection requires at least one photo and at least one existing log for the stage.

Submitting inspection locks the stage, assigns `submission_number = max + 1`, sets the stage to `PENDING_INSPECTION`, and updates project status to `INSPECTION`. Only the project owner can decide. Approval completes the stage; rejection requires a 2–1000 character reason and sets it to `RECTIFICATION`.

After stage approval, if all required stages are complete, set project and appointment to `COMPLETED` with timestamps. Otherwise return the project to `IN_PROGRESS`. Every status transition is transactional and writes `operation_logs` with the request trace ID.

`ProjectDetailResponse` returns:

```java
public record ProjectDetailResponse(
    UUID projectId,
    ProjectStatus status,
    TradeType trade,
    WorkerIdentity worker,
    QuoteSummary quote,
    List<StageResponse> stages,
    List<ConstructionLogResponse> logs,
    InspectionResponse pendingInspection,
    PaymentPlanSummary paymentPlan) {}
```

Keep `paymentPlan` nullable until Task 8 creates it; the field remains in the contract so Flutter integration does not require a breaking response change.

- [ ] **Step 7: Run construction tests and commit**

Run:

```bash
cd zhidi_server
./mvnw -Dtest=ProjectCreationTest,ConstructionFlowApiTest test
./mvnw test
```

Expected: PASS. Project identity matches the worker directory, duplicate project creation is idempotent, logs retain craft/acceptance text, and rejected inspections preserve their full rectification history.

Commit:

```bash
git add zhidi_server
git commit -m "feat(server): add construction and inspection workflow"
```

---

### Task 7: 实现私有文件上传、本地存储和阿里云 OSS 适配

**Files:**

- Create: `zhidi_server/src/main/resources/db/migration/V6__file_objects.sql`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/FileObject.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/FilePurpose.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/FileStatus.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/FileObjectRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/FileStorage.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/StoredObject.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/LocalFileStorage.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/OssFileStorage.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/FileAuthorizationService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/FileService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/FileController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/dto/FileResponse.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/storage/dto/FileAccessResponse.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/storage/LocalFileStorageTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/storage/FileApiAuthorizationTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/storage/OssFileStorageContractTest.java`

**Interfaces:**

- Produces: `FileStorage.store(String objectKey, InputStream input, long size, String contentType): StoredObject`.
- Produces: `FileStorage.createReadUrl(String objectKey, Duration ttl): URI`.
- Produces: `FileStorage.delete(String objectKey): void`.
- Produces: `FileService.requireUsableFiles(UUID actorUserId, Collection<UUID> fileIds, FilePurpose purpose): List<FileObject>`, consumed by Task 6 log/inspection creation.
- Consumes: project participant checks from Task 6 and authenticated principals from Task 3.

- [ ] **Step 1: Add file metadata and foreign key migration**

Create `V6__file_objects.sql`:

```sql
CREATE TABLE file_objects (
  id BINARY(16) PRIMARY KEY,
  uploader_user_id BINARY(16) NOT NULL,
  purpose VARCHAR(32) NOT NULL,
  storage_provider VARCHAR(20) NOT NULL,
  object_key VARCHAR(512) NOT NULL,
  original_name VARCHAR(255) NOT NULL,
  content_type VARCHAR(100) NOT NULL,
  size_bytes BIGINT NOT NULL,
  sha256 CHAR(64) NOT NULL,
  status VARCHAR(20) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  deleted_at DATETIME(6) NULL,
  CONSTRAINT uk_file_object_key UNIQUE (object_key),
  CONSTRAINT fk_file_uploader FOREIGN KEY (uploader_user_id) REFERENCES users(id),
  CONSTRAINT ck_file_size CHECK (size_bytes > 0 AND size_bytes <= 10485760),
  INDEX idx_file_uploader_time (uploader_user_id, created_at)
);

ALTER TABLE construction_log_files
  ADD CONSTRAINT fk_log_file_object FOREIGN KEY (file_id) REFERENCES file_objects(id);
ALTER TABLE inspection_files
  ADD CONSTRAINT fk_inspection_file_object FOREIGN KEY (file_id) REFERENCES file_objects(id);
ALTER TABLE worker_profiles
  ADD CONSTRAINT fk_worker_avatar_file FOREIGN KEY (avatar_file_id) REFERENCES file_objects(id);
```

`FilePurpose` values are `WORKER_AVATAR`, `CONSTRUCTION_LOG`, `INSPECTION`. `FileStatus` values are `ACTIVE`, `PENDING_DELETE`, `DELETED`.

- [ ] **Step 2: Write the failing local storage traversal and integrity tests**

Create `LocalFileStorageTest` with `@TempDir Path root`:

```java
@Test
void storesBytesUnderTheConfiguredRootAndReadsThemBack() throws Exception {
  LocalFileStorage storage = new LocalFileStorage(root);
  byte[] bytes = "image-content".getBytes(UTF_8);
  StoredObject stored = storage.store(
      "construction/2026/07/id.jpg", new ByteArrayInputStream(bytes),
      bytes.length, "image/jpeg");
  assertThat(root.resolve("construction/2026/07/id.jpg")).hasBinaryContent(bytes);
  assertThat(stored.sizeBytes()).isEqualTo(bytes.length);
}

@Test
void rejectsPathTraversalAndAbsoluteKeys() {
  LocalFileStorage storage = new LocalFileStorage(root);
  assertThatThrownBy(() -> storage.store("../../secret", input(), 1, "image/jpeg"))
      .isInstanceOf(IllegalArgumentException.class);
  assertThatThrownBy(() -> storage.store("/etc/passwd", input(), 1, "image/jpeg"))
      .isInstanceOf(IllegalArgumentException.class);
}
```

Add cases for a declared size different from streamed bytes, duplicate object keys, read of a missing object and deletion limited to the configured root.

- [ ] **Step 3: Write failing upload and resource authorization tests**

Create `FileApiAuthorizationTest`:

```java
@Test
void acceptsRealJpegAndRejectsSpoofedOrOversizedFiles() throws Exception {
  String workerToken = activeProject().workerToken();
  MockMultipartFile jpeg = new MockMultipartFile(
      "file", "site.jpg", "image/jpeg", validJpegBytes());
  mvc.perform(multipart("/api/v1/files")
      .file(jpeg).param("purpose", "CONSTRUCTION_LOG")
      .header(AUTHORIZATION, bearer(workerToken)))
      .andExpect(status().isCreated())
      .andExpect(jsonPath("$.data.contentType").value("image/jpeg"));

  MockMultipartFile fake = new MockMultipartFile(
      "file", "fake.jpg", "image/jpeg", "not-an-image".getBytes(UTF_8));
  mvc.perform(multipart("/api/v1/files").file(fake)
      .param("purpose", "CONSTRUCTION_LOG")
      .header(AUTHORIZATION, bearer(workerToken)))
      .andExpect(status().isBadRequest())
      .andExpect(jsonPath("$.code").value("FILE_CONTENT_INVALID"));
}

@Test
void onlyProjectParticipantsCanResolveAConstructionPhoto() throws Exception {
  ProjectFile flow = projectConstructionFile();
  mvc.perform(get("/api/v1/files/{id}", flow.fileId())
      .header(AUTHORIZATION, bearer(flow.unrelatedOwnerToken())))
      .andExpect(status().isForbidden())
      .andExpect(jsonPath("$.code").value("FILE_ACCESS_DENIED"));
  mvc.perform(get("/api/v1/files/{id}", flow.fileId())
      .header(AUTHORIZATION, bearer(flow.projectOwnerToken())))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.data.expiresAt").exists());
}
```

Also test anonymous access, a worker attaching another worker's unbound upload, more than nine images per log, inactive files, duplicate file IDs and avatar access rules.

- [ ] **Step 4: Run storage tests and verify failure**

Run: `cd zhidi_server && ./mvnw -Dtest=LocalFileStorageTest,FileApiAuthorizationTest test`

Expected: FAIL because V6 and storage services are absent.

- [ ] **Step 5: Implement safe local storage and metadata creation**

Define the storage port:

```java
public interface FileStorage {
  StoredObject store(String objectKey, InputStream input, long size,
                     String contentType) throws IOException;
  URI createReadUrl(String objectKey, Duration ttl);
  void delete(String objectKey) throws IOException;
}
```

Select adapters with `zhidi.storage.provider=local|oss`. For local storage, normalize `root.resolve(objectKey)` and require the result to start with normalized root before every operation. Stream to a temporary sibling file, verify actual byte count and SHA-256, then atomically move to its final path. Never use the original filename as an object key.

Create keys in this form:

```text
{purpose-lowercase}/{yyyy}/{MM}/{uploaderUserId}/{randomUuid}.{validatedExtension}
```

Inspect magic bytes rather than trusting the multipart content type. Allow JPEG, PNG and WebP only, with a maximum of 10 MiB. Remove path components and control characters from `originalName` before storing it as metadata.

Local read access uses an authenticated controller streaming the resource; it does not expose a `file://` path. `FileAccessResponse` can return `/api/v1/files/{id}/content` with a five-minute expiry marker.

- [ ] **Step 6: Implement OSS adapter and its contract test**

Configure:

```yaml
zhidi:
  storage:
    provider: ${STORAGE_PROVIDER:local}
    local-root: ${LOCAL_STORAGE_ROOT:./data/files}
    oss:
      endpoint: ${OSS_ENDPOINT:}
      bucket: ${OSS_BUCKET:}
      access-key-id: ${OSS_ACCESS_KEY_ID:}
      access-key-secret: ${OSS_ACCESS_KEY_SECRET:}
      read-url-ttl-seconds: 300
```

`OssFileStorage` uploads to a private bucket, supplies `Content-Type` and SHA-256 metadata, and creates a signed GET URL valid for at most five minutes. It must never enable public-read ACL. Load OSS credentials only when `provider=oss`, so local development does not require cloud keys.

Create `OssFileStorageContractTest` against a mocked OSS client boundary. Verify exact bucket/object key, private ACL behavior, metadata propagation, five-minute signature expiry, not-found mapping and delete calls. Keep the Alibaba SDK type inside the adapter; `FileService` sees only `FileStorage`.

- [ ] **Step 7: Enforce file binding and access authorization**

An uploaded construction/inspection file initially belongs only to its uploader. `requireUsableFiles` locks each file, checks `ACTIVE`, correct purpose and uploader, then allows Task 6 to bind it to exactly one authorized project log or inspection. Bound files are readable by that project's owner, assigned worker and admins.

Worker avatars are readable to authenticated and anonymous directory users, but only through a short-lived application/OSS URL. Construction evidence is always private. Mark deleted business files as `PENDING_DELETE`; a scheduled cleanup deletes storage bytes only when no active database relation references them, then marks `DELETED`.

- [ ] **Step 8: Run file tests and commit**

Run:

```bash
cd zhidi_server
./mvnw -Dtest=LocalFileStorageTest,FileApiAuthorizationTest,OssFileStorageContractTest test
./mvnw test
```

Expected: PASS. Traversal and fake images are rejected, private project files enforce participant access, and both storage adapters satisfy the same contract.

Commit:

```bash
git add zhidi_server
git commit -m "feat(server): add private construction file storage"
```

---

### Task 8: 实现微信/支付宝统一支付、分阶段付款、退款和对账

**Files:**

- Create: `zhidi_server/src/main/resources/db/migration/V7__payments.sql`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentPlan.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentStage.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentOrder.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentCallback.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/RefundOrder.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/ReconciliationRecord.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentChannel.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentOrderStatus.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentGateway.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentPlanService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentNotificationService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/RefundService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/ReconciliationService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentNotifyController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/AdminPaymentController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/adapter/WechatPaymentGateway.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/adapter/AlipayPaymentGateway.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/dto/PaymentLaunchResponse.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/dto/PaymentPlanResponse.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/payment/PaymentPlanTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/payment/PaymentApiTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/payment/PaymentNotificationTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/payment/RefundAndReconciliationTest.java`

**Interfaces:**

- Produces: `PaymentGateway.createAppPayment(CreatePaymentCommand command): GatewayPayment`.
- Produces: `PaymentGateway.verifyAndParseNotification(Map<String,String> headers, byte[] body): VerifiedPaymentNotification`.
- Produces: `PaymentGateway.query(String merchantOrderNo): GatewayPaymentStatus`.
- Produces: `PaymentGateway.refund(RefundCommand command): GatewayRefund`.
- Produces: `PaymentPlanService.createForProject(UUID projectId, long confirmedTotalFen): PaymentPlan`.
- Consumes: confirmed quote amount from Task 5 and project/inspection state from Task 6.

- [ ] **Step 1: Add payment schema with financial uniqueness constraints**

Create `V7__payments.sql`:

```sql
CREATE TABLE payment_plans (
  id BINARY(16) PRIMARY KEY,
  project_id BINARY(16) NOT NULL,
  total_fen BIGINT NOT NULL,
  status VARCHAR(32) NOT NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT uk_payment_plan_project UNIQUE (project_id),
  CONSTRAINT fk_payment_plan_project FOREIGN KEY (project_id) REFERENCES projects(id),
  CONSTRAINT ck_payment_plan_total CHECK (total_fen > 0)
);

CREATE TABLE payment_stages (
  id BINARY(16) PRIMARY KEY,
  payment_plan_id BINARY(16) NOT NULL,
  stage_code VARCHAR(40) NOT NULL,
  stage_name VARCHAR(80) NOT NULL,
  sequence_number INT NOT NULL,
  amount_fen BIGINT NOT NULL,
  trigger_type VARCHAR(40) NOT NULL,
  status VARCHAR(32) NOT NULL,
  paid_fen BIGINT NOT NULL DEFAULT 0,
  version BIGINT NOT NULL DEFAULT 0,
  CONSTRAINT uk_payment_stage_sequence UNIQUE (payment_plan_id, sequence_number),
  CONSTRAINT uk_payment_stage_code UNIQUE (payment_plan_id, stage_code),
  CONSTRAINT fk_payment_stage_plan FOREIGN KEY (payment_plan_id) REFERENCES payment_plans(id),
  CONSTRAINT ck_payment_stage_amount CHECK (amount_fen > 0 AND paid_fen >= 0 AND paid_fen <= amount_fen)
);

CREATE TABLE payment_orders (
  id BINARY(16) PRIMARY KEY,
  payment_stage_id BINARY(16) NOT NULL,
  owner_user_id BINARY(16) NOT NULL,
  channel VARCHAR(20) NOT NULL,
  merchant_order_no VARCHAR(64) NOT NULL,
  channel_transaction_no VARCHAR(128) NULL,
  amount_fen BIGINT NOT NULL,
  status VARCHAR(32) NOT NULL,
  idempotency_key VARCHAR(64) NOT NULL,
  launch_payload_json JSON NULL,
  expires_at DATETIME(6) NOT NULL,
  paid_at DATETIME(6) NULL,
  closed_at DATETIME(6) NULL,
  version BIGINT NOT NULL DEFAULT 0,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT uk_payment_merchant_order UNIQUE (merchant_order_no),
  CONSTRAINT uk_payment_owner_key UNIQUE (owner_user_id, idempotency_key),
  CONSTRAINT uk_payment_channel_transaction UNIQUE (channel, channel_transaction_no),
  CONSTRAINT fk_payment_order_stage FOREIGN KEY (payment_stage_id) REFERENCES payment_stages(id),
  CONSTRAINT fk_payment_order_owner FOREIGN KEY (owner_user_id) REFERENCES users(id),
  CONSTRAINT ck_payment_order_amount CHECK (amount_fen > 0),
  INDEX idx_payment_stage_status (payment_stage_id, status),
  INDEX idx_payment_created_status (created_at, status)
);

CREATE TABLE payment_callbacks (
  id BINARY(16) PRIMARY KEY,
  channel VARCHAR(20) NOT NULL,
  notification_id VARCHAR(128) NOT NULL,
  merchant_order_no VARCHAR(64) NULL,
  signature_valid BOOLEAN NOT NULL,
  body_sha256 CHAR(64) NOT NULL,
  processing_result VARCHAR(40) NOT NULL,
  error_code VARCHAR(80) NULL,
  received_at DATETIME(6) NOT NULL,
  processed_at DATETIME(6) NULL,
  CONSTRAINT uk_payment_callback UNIQUE (channel, notification_id)
);

CREATE TABLE refund_orders (
  id BINARY(16) PRIMARY KEY,
  payment_order_id BINARY(16) NOT NULL,
  merchant_refund_no VARCHAR(64) NOT NULL,
  channel_refund_no VARCHAR(128) NULL,
  amount_fen BIGINT NOT NULL,
  reason VARCHAR(500) NOT NULL,
  status VARCHAR(32) NOT NULL,
  requested_by BINARY(16) NOT NULL,
  created_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL,
  CONSTRAINT uk_merchant_refund UNIQUE (merchant_refund_no),
  CONSTRAINT fk_refund_payment FOREIGN KEY (payment_order_id) REFERENCES payment_orders(id),
  CONSTRAINT fk_refund_admin FOREIGN KEY (requested_by) REFERENCES users(id),
  CONSTRAINT ck_refund_amount CHECK (amount_fen > 0)
);

CREATE TABLE reconciliation_records (
  id BINARY(16) PRIMARY KEY,
  channel VARCHAR(20) NOT NULL,
  bill_date DATE NOT NULL,
  merchant_order_no VARCHAR(64) NOT NULL,
  local_amount_fen BIGINT NULL,
  channel_amount_fen BIGINT NULL,
  local_status VARCHAR(32) NULL,
  channel_status VARCHAR(32) NULL,
  result VARCHAR(32) NOT NULL,
  detail VARCHAR(500) NULL,
  created_at DATETIME(6) NOT NULL,
  CONSTRAINT uk_reconciliation_order UNIQUE (channel, bill_date, merchant_order_no),
  INDEX idx_reconciliation_result (bill_date, result)
);
```

- [ ] **Step 2: Write failing stage split and eligibility tests**

Create `PaymentPlanTest`:

```java
@Test
void defaultPlanSplitsTwentyThirtyThirtyTwentyAndKeepsEveryFen() {
  PaymentPlan plan = paymentPlanService.createForProject(projectId(), 1_199_683L);
  assertThat(plan.getStages()).extracting(PaymentStage::getStageCode)
      .containsExactly("START", "PLUMBING_ACCEPTED", "MASONRY_ACCEPTED", "COMPLETION");
  assertThat(plan.getStages()).extracting(PaymentStage::getAmountFen)
      .containsExactly(239_936L, 359_905L, 359_905L, 239_937L);
  assertThat(plan.getStages().stream().mapToLong(PaymentStage::getAmountFen).sum())
      .isEqualTo(1_199_683L);
}

@Test
void onlyTheCurrentEligibleStageCanBePaid() {
  PaymentPlan plan = planForReadyProject();
  assertThat(plan.stage("START").isPayable()).isTrue();
  assertThat(plan.stage("PLUMBING_ACCEPTED").isPayable()).isFalse();
  assertThatThrownBy(() -> paymentService.createOrder(ownerId(),
      plan.stage("PLUMBING_ACCEPTED").getId(), PaymentChannel.WECHAT, "key-1"))
      .isInstanceOfSatisfying(BusinessException.class,
          ex -> assertThat(ex.code()).isEqualTo("PAYMENT_STAGE_NOT_PAYABLE"));
}
```

The default allocation uses integer floor for the first three nodes: 20%, 30%, 30%; the final node receives `total - previous amounts`, so the sum always equals the confirmed quote. For a project without plumbing or masonry stages, those trigger names remain commercial payment milestones and become eligible when the configured percentage of project stages is approved; they do not fabricate construction stages.

- [ ] **Step 3: Write failing payment creation and idempotency tests**

Create `PaymentApiTest` with fake gateways:

```java
@Test
void ownerCanCreateWechatOrAlipayAppPaymentForOwnStage() throws Exception {
  PayableStage stage = payableStageForOwner();
  mvc.perform(post("/api/v1/payment-stages/{id}/pay", stage.id())
      .header(AUTHORIZATION, bearer(stage.ownerToken()))
      .header("Idempotency-Key", "owner-action-1")
      .contentType(APPLICATION_JSON).content("{\"channel\":\"WECHAT\"}"))
      .andExpect(status().isCreated())
      .andExpect(jsonPath("$.data.channel").value("WECHAT"))
      .andExpect(jsonPath("$.data.launchParameters").isMap())
      .andExpect(jsonPath("$.data.amountFen").value(stage.amountFen()));
}

@Test
void repeatedIdempotencyKeyReturnsSameOrderWithoutCallingGatewayTwice() throws Exception {
  PayableStage stage = payableStageForOwner();
  PaymentLaunchResponse first = pay(stage, PaymentChannel.ALIPAY, "same-key");
  PaymentLaunchResponse second = pay(stage, PaymentChannel.ALIPAY, "same-key");
  assertThat(second.paymentOrderId()).isEqualTo(first.paymentOrderId());
  verify(alipayGateway, times(1)).createAppPayment(any());
}
```

Also test a different owner, a mismatched amount attempt, an already-paid stage, two simultaneous active orders, expired order replacement and gateway timeout without marking the stage paid.

- [ ] **Step 4: Write failing notification verification and duplicate callback tests**

Create `PaymentNotificationTest`:

```java
@Test
void validNotificationMarksOrderAndStagePaidExactlyOnce() {
  PendingPayment payment = pendingWechatPayment(50_000L);
  VerifiedPaymentNotification notification = successNotification(
      payment.merchantOrderNo(), "wx-transaction-1", 50_000L, "CNY", merchantId());
  when(wechatGateway.verifyAndParseNotification(anyMap(), any()))
      .thenReturn(notification);

  notificationService.handle(PaymentChannel.WECHAT, headers(), body());
  notificationService.handle(PaymentChannel.WECHAT, headers(), body());

  assertThat(paymentOrder(payment.id()).getStatus()).isEqualTo(PaymentOrderStatus.PAID);
  assertThat(paymentStage(payment.stageId()).getPaidFen()).isEqualTo(50_000L);
  assertThat(callbackRepository.countByNotificationId(notification.notificationId()))
      .isEqualTo(1);
}

@Test
void invalidSignatureOrAmountNeverChangesFinancialState() {
  PendingPayment payment = pendingAlipayPayment(88_000L);
  when(alipayGateway.verifyAndParseNotification(anyMap(), any()))
      .thenThrow(new PaymentVerificationException("SIGNATURE_INVALID"));
  assertThatThrownBy(() -> notificationService.handle(
      PaymentChannel.ALIPAY, headers(), body())).isInstanceOf(PaymentVerificationException.class);
  assertThat(paymentOrder(payment.id()).getStatus()).isEqualTo(PaymentOrderStatus.PENDING);

  when(alipayGateway.verifyAndParseNotification(anyMap(), any()))
      .thenReturn(successNotification(payment.merchantOrderNo(), "ali-1", 87_999L, "CNY", merchantId()));
  assertThatThrownBy(() -> notificationService.handle(
      PaymentChannel.ALIPAY, headers(), body()))
      .isInstanceOfSatisfying(BusinessException.class,
          ex -> assertThat(ex.code()).isEqualTo("PAYMENT_AMOUNT_MISMATCH"));
}
```

Also test wrong app ID, merchant ID, currency, merchant order, duplicate channel transaction number, late success after local expiry, callback transaction rollback and active query repair after a missed callback.

- [ ] **Step 5: Run payment tests and verify failure**

Run: `cd zhidi_server && ./mvnw -Dtest=PaymentPlanTest,PaymentApiTest,PaymentNotificationTest test`

Expected: FAIL because V7, payment services and gateways do not exist.

- [ ] **Step 6: Implement payment plan and order creation**

Define:

```java
public enum PaymentChannel { WECHAT, ALIPAY }
public enum PaymentOrderStatus { CREATING, PENDING, PAID, CLOSED, FAILED, REFUNDING, PARTIALLY_REFUNDED, REFUNDED }
public enum PaymentStageStatus { LOCKED, PAYABLE, PAYING, PAID, PARTIALLY_REFUNDED, REFUNDED }
```

Create the plan in the same application flow that creates a project from a confirmed quote. The first stage is `PAYABLE`; later stages are `LOCKED`. Stage eligibility service unlocks milestones based on project creation and approved construction progress. Once any payment order exists, plan amounts and order are immutable.

`POST /api/v1/payment-stages/{stageId}/pay` accepts only a channel; amount is always loaded from the database. Lock the stage, verify project ownership and eligibility, reuse an active order for the same idempotency key, create a merchant number in the form `ZD{yyyyMMdd}{20 random uppercase digits}`, then call the selected gateway. Store only launch parameters safe for returning to Flutter; never store merchant private keys or decrypted callback secrets.

`PaymentLaunchResponse` contains `paymentOrderId`, `merchantOrderNo`, `channel`, `amountFen`, `expiresAt` and a channel-specific `launchParameters` map. Flutter passes those parameters to the official mobile SDK and then polls `GET /api/v1/payment-orders/{id}`; it cannot submit a paid state.

- [ ] **Step 7: Implement official gateway adapters and secure callbacks**

Configuration:

```yaml
zhidi:
  payment:
    enabled: ${PAYMENT_ENABLED:false}
    notify-base-url: ${PAYMENT_NOTIFY_BASE_URL:}
    wechat:
      app-id: ${WECHAT_APP_ID:}
      merchant-id: ${WECHAT_MERCHANT_ID:}
      merchant-serial-no: ${WECHAT_MERCHANT_SERIAL_NO:}
      private-key-path: ${WECHAT_PRIVATE_KEY_PATH:}
      api-v3-key: ${WECHAT_API_V3_KEY:}
      platform-certificate-path: ${WECHAT_PLATFORM_CERTIFICATE_PATH:}
    alipay:
      app-id: ${ALIPAY_APP_ID:}
      private-key-path: ${ALIPAY_PRIVATE_KEY_PATH:}
      alipay-public-key-path: ${ALIPAY_PUBLIC_KEY_PATH:}
      app-cert-path: ${ALIPAY_APP_CERT_PATH:}
      alipay-root-cert-path: ${ALIPAY_ROOT_CERT_PATH:}
```

When `PAYMENT_ENABLED=false`, real pay endpoints return HTTP 503 `PAYMENT_NOT_CONFIGURED`; tests inject fake gateways. `WechatPaymentGateway` uses WeChat Pay API v3 APP payment, verifies platform certificate signatures and decrypts notification resources with the API v3 key. `AlipayPaymentGateway` uses app payment, signs requests with the application private key and verifies asynchronous notification parameters with the configured Alipay public certificate/key.

Implementation must be checked against the payment providers' current official APP payment and notification documentation at coding time. Adapter tests pin the expected request fields, signature input, notification parsing and error mapping so SDK upgrades cannot silently alter business behavior.

Notification controllers read raw bytes and original headers/parameters. After adapter verification, `PaymentNotificationService` locks the payment order, compares app/merchant identity, merchant order, currency `CNY` and exact amount, then updates order and stage in one transaction. Unique notification and channel transaction constraints make duplicates idempotent. Return provider-required success text only after the transaction commits.

- [ ] **Step 8: Implement refund and reconciliation tests**

Create `RefundAndReconciliationTest`:

```java
@Test
void adminCanRefundAtMostTheRemainingPaidAmount() {
  PaidPayment payment = paidPayment(100_000L);
  RefundOrder first = refundService.request(
      adminId(), payment.id(), 30_000L, "项目取消，退还未施工部分");
  gatewayCompletes(first, "channel-refund-1");
  assertThat(paymentOrder(payment.id()).getStatus())
      .isEqualTo(PaymentOrderStatus.PARTIALLY_REFUNDED);
  assertThatThrownBy(() -> refundService.request(
      adminId(), payment.id(), 70_001L, "超额退款测试"))
      .isInstanceOfSatisfying(BusinessException.class,
          ex -> assertThat(ex.code()).isEqualTo("REFUND_AMOUNT_EXCEEDS_PAID"));
}

@Test
void reconciliationRecordsAmountAndStatusDifferences() {
  localPaidOrder("ZD001", 50_000L);
  reconciliationService.reconcile(LocalDate.of(2026, 7, 13),
      PaymentChannel.WECHAT,
      List.of(channelBill("ZD001", 49_900L, "SUCCESS")));
  assertThat(reconciliationRepository.findByMerchantOrderNo("ZD001").orElseThrow().getResult())
      .isEqualTo(ReconciliationResult.AMOUNT_MISMATCH);
}
```

Only admins can request refund. The service locks the paid order, verifies cumulative successful/pending refunds do not exceed paid amount, calls the original channel and persists merchant/channel refund numbers. Daily reconciliation compares merchant order, amount and status, classifying `MATCHED`, `LOCAL_MISSING`, `CHANNEL_MISSING`, `AMOUNT_MISMATCH` or `STATUS_MISMATCH`; it never auto-adjusts money.

- [ ] **Step 9: Run all payment tests and commit**

Run:

```bash
cd zhidi_server
./mvnw -Dtest=PaymentPlanTest,PaymentApiTest,PaymentNotificationTest,RefundAndReconciliationTest test
./mvnw test
```

Expected: PASS. Every fen is allocated, only eligible stages can pay, callbacks are verified and idempotent, over-refunds fail, and reconciliation records differences without mutating balances.

Commit:

```bash
git add zhidi_server
git commit -m "feat(server): add staged WeChat and Alipay payments"
```

---

### Task 9: 完成 Docker Compose、Nginx、备份和 Ubuntu 22.04 部署

**Files:**

- Create: `zhidi_server/.dockerignore`
- Create: `zhidi_server/.env.example`
- Create: `zhidi_server/Dockerfile`
- Create: `zhidi_server/compose.yaml`
- Create: `zhidi_server/compose.debug.yaml`
- Create: `zhidi_server/src/main/resources/application-prod.yml`
- Create: `zhidi_server/deploy/nginx/zhidi.conf`
- Create: `zhidi_server/deploy/scripts/backup-mysql.sh`
- Create: `zhidi_server/deploy/scripts/restore-mysql.sh`
- Create: `zhidi_server/deploy/scripts/deploy.sh`
- Create: `zhidi_server/deploy/scripts/rollback.sh`
- Create: `zhidi_server/deploy/systemd/zhidi-backup.service`
- Create: `zhidi_server/deploy/systemd/zhidi-backup.timer`
- Create: `zhidi_server/docs/ubuntu-22.04-deployment.md`
- Test: `zhidi_server/src/test/java/com/zhidi/server/deployment/ProductionConfigurationTest.java`
- Test: `zhidi_server/deploy/tests/compose-config-test.sh`

**Interfaces:**

- Produces: HTTPS API at `https://api.example.com/api/v1/*` and health at `/actuator/health/readiness`.
- Produces: application image tagged by immutable release version, plus executable JAR in `target/`.
- Produces: backup artifact `zhidi-{UTC timestamp}.sql.gz` and SHA-256 sidecar.
- Consumes: all environment property names introduced in Tasks 1–8.

- [ ] **Step 1: Write failing production configuration tests**

Create `ProductionConfigurationTest`:

```java
class ProductionConfigurationTest {
  @Test
  void productionRefusesMissingJwtAndDatabaseSecrets() {
    new ApplicationContextRunner()
        .withUserConfiguration(ZhidiServerApplication.class)
        .withPropertyValues(
            "spring.profiles.active=prod",
            "DB_URL=jdbc:mysql://mysql:3306/zhidi")
        .run(context -> {
          assertThat(context).hasFailed();
          assertThat(context.getStartupFailure().getMessage())
              .containsAnyOf("JWT_SECRET", "AUTH_HASH_SECRET", "DB_PASSWORD");
        });
  }
}
```

Use `ApplicationContextRunner` directly; do not add Spring Modulith for this test. Add tests that `PAYMENT_ENABLED=true` requires both configured channel certificates, `STORAGE_PROVIDER=oss` requires OSS configuration, and production CORS rejects wildcard origins.

- [ ] **Step 2: Create production profile with fail-fast validation**

Create `application-prod.yml`:

```yaml
spring:
  datasource:
    url: ${DB_URL}
    username: ${DB_USER}
    password: ${DB_PASSWORD}
    hikari:
      maximum-pool-size: ${DB_POOL_SIZE:20}
      minimum-idle: ${DB_MIN_IDLE:2}
      connection-timeout: 10000
  jpa:
    hibernate:
      ddl-auto: validate
  flyway:
    enabled: true
server:
  forward-headers-strategy: framework
  shutdown: graceful
  tomcat:
    max-swallow-size: 40MB
management:
  endpoint:
    health:
      probes:
        enabled: true
  health:
    readinessstate:
      enabled: true
    livenessstate:
      enabled: true
logging:
  level:
    root: INFO
    com.zhidi.server: INFO
```

Bind security, SMS, storage and payment properties with `@Validated @ConfigurationProperties`. Production validation rejects secrets shorter than 32 bytes, fixed SMS mode, wildcard CORS, HTTP payment callback URLs, empty database credentials, enabled payment without channel keys, and OSS mode without bucket/endpoint credentials.

- [ ] **Step 3: Build a non-root multi-stage application image**

Create `Dockerfile`:

```dockerfile
FROM eclipse-temurin:21-jdk-jammy AS build
WORKDIR /workspace
COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN ./mvnw -B -DskipTests dependency:go-offline
COPY src src
RUN ./mvnw -B -DskipTests clean package

FROM eclipse-temurin:21-jre-jammy
RUN groupadd --system zhidi && useradd --system --gid zhidi --home /app zhidi
WORKDIR /app
COPY --from=build /workspace/target/zhidi-server-*.jar app.jar
RUN mkdir -p /app/data/files && chown -R zhidi:zhidi /app
USER zhidi
EXPOSE 8080
ENTRYPOINT ["java","-XX:MaxRAMPercentage=75","-Djava.security.egd=file:/dev/urandom","-jar","/app/app.jar"]
```

`.dockerignore` excludes `target`, `.git`, `.env`, `data`, logs, private keys, certificates and IDE files. Add build metadata (`implementation-version` and Git commit) to `/actuator/info` without exposing secrets.

- [ ] **Step 4: Create the Compose stack and configuration test**

Create `compose.yaml` with three services:

```yaml
services:
  mysql:
    image: mysql:8.4
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: zhidi
      MYSQL_USER: ${DB_USER}
      MYSQL_PASSWORD: ${DB_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
      TZ: Asia/Shanghai
    command: ["--character-set-server=utf8mb4", "--collation-server=utf8mb4_0900_ai_ci"]
    volumes:
      - mysql_data:/var/lib/mysql
    networks: [backend]
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h localhost -uroot -p$$MYSQL_ROOT_PASSWORD --silent"]
      interval: 10s
      timeout: 5s
      retries: 12

  api:
    image: ${ZHIDI_IMAGE}:${ZHIDI_VERSION}
    restart: unless-stopped
    env_file: [.env]
    environment:
      SPRING_PROFILES_ACTIVE: prod
      DB_URL: jdbc:mysql://mysql:3306/zhidi?useUnicode=true&characterEncoding=utf8&serverTimezone=Asia/Shanghai
    volumes:
      - local_files:/app/data/files
      - ./secrets:/run/secrets:ro
    networks: [backend]
    depends_on:
      mysql:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:8080/actuator/health/readiness | grep -q UP"]
      interval: 15s
      timeout: 5s
      retries: 12
      start_period: 30s

  nginx:
    image: nginx:1.28-alpine
    restart: unless-stopped
    ports: ["80:80", "443:443"]
    volumes:
      - ./deploy/nginx/zhidi.conf:/etc/nginx/conf.d/default.conf:ro
      - ./certs:/etc/nginx/certs:ro
    networks: [backend]
    depends_on:
      api:
        condition: service_healthy

networks:
  backend:
    internal: false
volumes:
  mysql_data:
  local_files:
```

Do not publish MySQL or API ports to the host. Nginx is the only public service. Create `deploy/tests/compose-config-test.sh` to run `docker compose --env-file .env.test config`, assert no `3306:` or `8080:` host publishing, and assert all three health checks are present.

- [ ] **Step 5: Configure TLS proxy, upload limits and API rate boundaries**

Create `deploy/nginx/zhidi.conf` with:

```nginx
limit_req_zone $binary_remote_addr zone=api_per_ip:10m rate=20r/s;
limit_req_zone $binary_remote_addr zone=sms_per_ip:10m rate=2r/m;

server {
  listen 80;
  server_name ${API_DOMAIN};
  return 301 https://$host$request_uri;
}

server {
  listen 443 ssl http2;
  server_name ${API_DOMAIN};
  ssl_certificate /etc/nginx/certs/fullchain.pem;
  ssl_certificate_key /etc/nginx/certs/privkey.pem;
  ssl_protocols TLSv1.2 TLSv1.3;
  client_max_body_size 40m;

  location = /api/v1/auth/sms/send {
    limit_req zone=sms_per_ip burst=2 nodelay;
    proxy_pass http://api:8080;
    include /etc/nginx/proxy_params;
  }
  location / {
    limit_req zone=api_per_ip burst=40 nodelay;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_read_timeout 60s;
    proxy_pass http://api:8080;
  }
}
```

Because Compose does not substitute variables inside mounted files, `deploy.sh` renders `${API_DOMAIN}` with `envsubst` into `deploy/runtime/zhidi.conf` and Compose mounts the rendered file. Validate with `docker compose exec nginx nginx -t` before reloading.

- [ ] **Step 6: Implement verified backups and guarded restores**

`backup-mysql.sh` must use `set -Eeuo pipefail`, create a restrictive `umask 077`, run `mysqldump --single-transaction --routines --triggers --set-gtid-purged=OFF`, gzip the dump, calculate SHA-256, and delete backups older than `${BACKUP_RETENTION_DAYS:-14}` only after the new backup succeeds.

`restore-mysql.sh` requires three explicit arguments: backup path, checksum path and the literal confirmation `RESTORE_ZHIDI`. It verifies SHA-256, refuses a running API container unless `ALLOW_RUNNING_API=true` is explicitly supplied for a tested maintenance scenario, creates a pre-restore backup, then imports through the MySQL container. It prints verification commands after completion.

Create a systemd timer:

```ini
[Timer]
OnCalendar=*-*-* 03:15:00 Asia/Shanghai
Persistent=true
RandomizedDelaySec=10m
```

The service runs the backup script as a dedicated deployment user. Deployment documentation includes a monthly restore drill into a separate database; a backup is not considered operational until a restore has been tested.

- [ ] **Step 7: Implement immutable deploy and rollback scripts**

`deploy.sh VERSION` performs:

1. Validate `.env`, certificate and secret file permissions.
2. Pull/build the exact `${ZHIDI_IMAGE}:${VERSION}`.
3. Run `docker compose config` and Nginx config validation.
4. Save current version to `.previous-version`.
5. Start MySQL, then API, wait up to 180 seconds for readiness.
6. Start/reload Nginx and call HTTPS `/actuator/health/readiness`.
7. Write the successful version to `.current-version`.

`rollback.sh` reads `.previous-version`, rejects an empty or identical value, checks migration compatibility documented for that release, switches the image tag, waits for readiness and records the rollback. It never deletes volumes or reverses Flyway migrations automatically.

- [ ] **Step 8: Write the Ubuntu 22.04 runbook**

Document exact commands for:

- Installing Docker Engine and Compose plugin from Docker's Ubuntu repository.
- Creating `/opt/zhidi`, deployment user/group and directories with least privilege.
- Copying `.env.example` to `.env` and generating 32+ byte secrets with `openssl rand -base64 48`.
- Placing TLS, WeChat, Alipay and OSS credentials with mode `600`.
- Starting with `./deploy/scripts/deploy.sh 0.1.0`.
- Verifying container health, Flyway migration, HTTPS, OpenAPI access policy and logs.
- Configuring firewall ports 22, 80 and 443 only.
- Enabling the backup timer, testing restore and rotating credentials.
- Deploying a new immutable tag and performing rollback.

Do not include real merchant values, phone numbers, private keys or production passwords in examples.

- [ ] **Step 9: Run build/deployment validation and commit**

Run:

```bash
cd zhidi_server
./mvnw clean verify
cp .env.example .env.test
./deploy/tests/compose-config-test.sh
docker build -t zhidi-server:plan-test .
docker run --rm --entrypoint java zhidi-server:plan-test -version
```

Expected: Maven verification PASS; Compose config contains no public database/API port; image builds and reports Java 21. When Docker is unavailable locally, record only the Docker checks as environment-blocked and do not claim deployment verification until they run on a Docker-capable host.

Commit:

```bash
git add zhidi_server
git commit -m "ops(server): add Ubuntu Docker deployment"
```

---

### Task 10: 完成全链路验收、OpenAPI 契约和 Flutter 对接清单

**Files:**

- Create: `zhidi_server/src/test/java/com/zhidi/server/e2e/CoreWorkflowE2eTest.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/e2e/PaymentWorkflowE2eTest.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/e2e/SecurityBoundaryE2eTest.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/support/FakeSmsSender.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/support/FakePaymentGateway.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/support/TestFileFactory.java`
- Create: `zhidi_server/src/test/resources/application-e2e.yml`
- Create: `zhidi_server/openapi/zhidi-api-v1.json`
- Create: `zhidi_server/scripts/export-openapi.sh`
- Create: `zhidi_server/scripts/verify-openapi.sh`
- Create: `zhidi_server/docs/flutter-api-mapping.md`
- Create: `zhidi_server/docs/api-error-codes.md`
- Create: `zhidi_server/README.md`

**Interfaces:**

- Produces: versioned OpenAPI contract `openapi/zhidi-api-v1.json` for Flutter client generation or manual integration.
- Produces: Flutter mapping from current local/Firebase models to server IDs, statuses, integer money and endpoints.
- Verifies: complete owner/worker/payment workflow against real MySQL and application HTTP stack.
- Consumes: every API and domain service produced by Tasks 1–9.

- [ ] **Step 1: Write the failing core owner/worker workflow test**

Create `CoreWorkflowE2eTest` as `@SpringBootTest(webEnvironment = RANDOM_PORT)` using the MySQL Testcontainer and real HTTP requests:

```java
@Test
void ownerAndWorkerCompleteTheConstructionLoop() {
  Session admin = client.loginAdmin(bootstrapAdminPhone(), "123456");
  Session worker = client.loginWorker("13900139000", "123456", "worker-device");
  UUID workerId = client.updateWorkerProfile(worker,
      workerProfile("陈志远", "PLUMBING", 10, "成都"));
  client.approveWorker(admin, workerId);
  client.setWorkerAvailability(worker, true);

  Session owner = client.loginOwner("13800138000", "123456", "owner-device");
  WorkerDto listed = client.listWorkers("PLUMBING", "成都").getFirst();
  assertThat(listed.workerId()).isEqualTo(workerId);
  assertThat(listed.fullName()).isEqualTo("陈志远");
  assertThat(client.workerDetail(workerId).fullName()).isEqualTo("陈志远");

  UUID appointmentId = client.createAppointment(owner,
      appointment(workerId, "PLUMBING", "成都", "天府新区", "12栋3单元502"),
      "owner-appointment-1");
  client.acceptAppointment(worker, appointmentId);
  UUID quoteId = client.submitQuote(worker, appointmentId,
      quote(labor("水管布置", 20, 8_000), material("PPR水管", 20, 2_500)));
  ProjectDto project = client.confirmQuote(owner, quoteId);

  UUID stageId = project.stages().getFirst().stageId();
  client.startStage(worker, project.projectId(), stageId);
  UUID dailyPhoto = client.uploadJpeg(worker, "CONSTRUCTION_LOG");
  client.createDailyLog(worker, project.projectId(), stageId,
      "水管布置", "冷热水管按规范布置", "管卡间距符合标准", List.of(dailyPhoto));
  UUID inspectionPhoto = client.uploadJpeg(worker, "INSPECTION");
  UUID inspectionId = client.submitInspection(worker, project.projectId(), stageId,
      List.of(inspectionPhoto));
  client.approveInspection(owner, inspectionId, "验收通过");

  ProjectDto completed = client.project(owner, project.projectId());
  assertThat(completed.status()).isEqualTo("COMPLETED");
  assertThat(completed.worker().fullName()).isEqualTo("陈志远");
  assertThat(completed.logs()).singleElement()
      .extracting("craftsmanship", "acceptanceStandard")
      .containsExactly("冷热水管按规范布置", "管卡间距符合标准");
}
```

Add a second test creating demolition, waterproofing and two plumbing services for one owner. Assert four distinct appointment IDs and four distinct project entries; no endpoint may collapse them by trade.

- [ ] **Step 2: Write the failing staged dual-channel payment test**

Create `PaymentWorkflowE2eTest` using deterministic fake gateways but real controllers, transactions and MySQL:

```java
@Test
void ownerPaysStagesThroughWechatAndAlipayNotifications() {
  PaidProjectFlow flow = readyProjectWithTotal(1_199_683L);
  PaymentPlanDto plan = client.paymentPlan(flow.owner(), flow.projectId());
  assertThat(plan.stages()).extracting(PaymentStageDto::amountFen)
      .containsExactly(239_936L, 359_905L, 359_905L, 239_937L);

  PaymentLaunchDto first = client.pay(flow.owner(), plan.stages().getFirst().id(),
      "WECHAT", "pay-stage-1");
  fakeWechat.sendSignedSuccess(first.merchantOrderNo(), first.amountFen());
  assertThat(client.payment(first.paymentOrderId()).status()).isEqualTo("PAID");

  flow.approveProgressUntilSecondPayment();
  PaymentLaunchDto second = client.pay(flow.owner(), plan.stages().get(1).id(),
      "ALIPAY", "pay-stage-2");
  fakeAlipay.sendSignedSuccess(second.merchantOrderNo(), second.amountFen());
  fakeAlipay.sendSignedSuccess(second.merchantOrderNo(), second.amountFen());
  assertThat(client.payment(second.paymentOrderId()).status()).isEqualTo("PAID");
  assertThat(paymentCallbackRepository.countFor(second.merchantOrderNo())).isEqualTo(1);
}
```

Add cases for tampered signature, one-fen amount mismatch, duplicate callback, refresh-token replay during checkout, refund then reconciliation mismatch, and provider query repairing a missed notification.

- [ ] **Step 3: Write the failing cross-role and data privacy test**

Create `SecurityBoundaryE2eTest`:

```java
@Test
void unrelatedActorsCannotReadOrMutatePrivateResources() {
  PrivateProject flow = privateProject();
  Session unrelatedOwner = client.loginOwner("13800138009", "123456", "other-owner");
  Session unrelatedWorker = approvedWorkerSession("13900139009", "其他师傅");

  client.getProject(unrelatedOwner, flow.projectId()).expectStatus(403);
  client.getProject(unrelatedWorker, flow.projectId()).expectStatus(403);
  client.getFile(unrelatedOwner, flow.constructionFileId()).expectStatus(403);
  client.approveInspection(unrelatedOwner, flow.inspectionId(), "越权").expectStatus(403);
  client.submitQuote(unrelatedWorker, flow.appointmentId(), sampleQuote()).expectStatus(403);
  client.refund(unrelatedOwner, flow.paymentOrderId(), 1, "越权").expectStatus(403);
}

@Test
void pendingWorkerAndOwnerCannotEscalateToAdmin() {
  Session owner = client.loginOwner("13800138008", "123456", "owner");
  client.callAdminPendingWorkers(owner).expectStatus(403);
  client.loginWithRequestedRole("13800138008", "ADMIN").expectStatus(400);
}
```

Also verify logs and responses never contain the SMS code, JWT, refresh token, complete phone, complete address before acceptance, payment private key or decrypted callback secret.

- [ ] **Step 4: Run E2E tests and fix only contract gaps**

Run:

```bash
cd zhidi_server
./mvnw -Dtest='com.zhidi.server.e2e.*' test
```

Expected: initial FAIL identifies any missing wiring between otherwise-complete modules. Fix only wiring, transaction boundary, DTO mapping and authorization gaps required by these workflows; do not add new product scope.

Repeat until all three E2E classes PASS.

- [ ] **Step 5: Export and lock the OpenAPI v1 contract**

`scripts/export-openapi.sh` starts the app with the `e2e` profile on a random available port, waits for readiness, downloads `/v3/api-docs` to a temporary file, canonicalizes JSON key ordering with `jq -S`, and atomically replaces `openapi/zhidi-api-v1.json`.

`scripts/verify-openapi.sh` exports to a temporary file and runs:

```bash
diff -u openapi/zhidi-api-v1.json "$TMP_OPENAPI"
```

The checked-in contract must include all `/api/v1` endpoints, bearer authentication, pagination models, integer `*Fen` fields, UUID identifiers, enums, multipart upload and the shared error envelope. Payment notification endpoints are documented as server-to-server callbacks and excluded from Flutter operations.

Run:

```bash
cd zhidi_server
./scripts/export-openapi.sh
./scripts/verify-openapi.sh
```

Expected: export succeeds and verification produces no diff.

- [ ] **Step 6: Write the exact Flutter migration map**

Create `docs/flutter-api-mapping.md` with this migration order:

| Flutter current source | Server replacement | Stable key |
|---|---|---|
| `OwnerAppState.login` simulated delay | `POST /api/v1/auth/sms/login` | `userId` |
| `WorkerAppState.login` simulated delay | `POST /api/v1/auth/sms/login` | `userId` + `workerId` |
| Firebase `shared_workers` | `GET /api/v1/workers` | `workerId` |
| Local/Firebase order bridge | `/api/v1/appointments` | `appointmentId` |
| Local quotation JSON | appointment quote endpoints | `quoteId` + version |
| Local `shared_orders.json` | `/api/v1/projects` | `projectId` |
| Local daily reports | project log endpoints | `constructionLogId` |
| Local inspections | inspection endpoints | `inspectionId` |
| Local fee totals | project payment plan | `paymentStageId` |

Document enum label mappings, ISO-8601 timestamps with `Asia/Shanghai` display conversion, integer fen formatting, bearer/refresh storage, 401 refresh-and-retry exactly once, idempotency key generation and pagination. State explicitly that Flutter must never join by `workerName`, `tradeLabel` or list position.

List the recommended Flutter integration sequence as separate future work: API client/auth storage, worker directory, appointments/quotes, projects/logs, files, payments, then removal of Firebase/local bridges after regression passes. The Spring Boot implementation task does not delete those client paths.

- [ ] **Step 7: Document error codes and local startup**

`docs/api-error-codes.md` groups stable codes by HTTP status and includes at least:

```text
400 VALIDATION_ERROR, FILE_CONTENT_INVALID
401 UNAUTHENTICATED, SMS_CODE_INVALID, SMS_CODE_EXPIRED, SMS_CODE_CONSUMED
403 FORBIDDEN, FILE_ACCESS_DENIED, APPOINTMENT_NOT_ASSIGNED_TO_WORKER
404 WORKER_NOT_FOUND, APPOINTMENT_NOT_FOUND, PROJECT_NOT_FOUND
409 APPOINTMENT_STATE_CONFLICT, WORKER_NOT_APPROVED,
    PAYMENT_STAGE_NOT_PAYABLE, PAYMENT_AMOUNT_MISMATCH,
    REFRESH_TOKEN_REUSED, REFUND_AMOUNT_EXCEEDS_PAID
429 SMS_RATE_LIMITED
503 PAYMENT_NOT_CONFIGURED, EXTERNAL_SERVICE_UNAVAILABLE
```

`README.md` contains prerequisites, local MySQL startup, required development environment values, `./mvnw spring-boot:run`, Swagger location, test commands, production build command and links to deployment/payment/Flutter mapping documents. Development examples use fixed code `123456` and non-production secrets only.

- [ ] **Step 8: Run the complete verification matrix**

Run:

```bash
cd zhidi_server
./mvnw clean verify
./scripts/verify-openapi.sh
./deploy/tests/compose-config-test.sh
docker build -t zhidi-server:0.1.0 .
docker compose -f compose.yaml -f compose.debug.yaml --env-file .env.test up -d mysql api
curl --fail --retry 20 --retry-delay 3 http://localhost:8080/actuator/health/readiness
docker compose -f compose.yaml -f compose.debug.yaml --env-file .env.test down
```

`compose.debug.yaml` is a local-only override that publishes API port `8080`; `compose.yaml` itself never publishes that port. Production Compose validation checks only `compose.yaml`. Expected: Maven, OpenAPI and Compose checks PASS; image builds; migrations V1–V7 apply to a clean MySQL; readiness reports `UP`.

Run secret and forbidden-pattern scans:

```bash
git grep -nE '(BEGIN (RSA |EC |)PRIVATE KEY|api-v3-key: [^$]|access-key-secret: [^$])' -- zhidi_server
git grep -nE '(shared_orders\.json|shared_workers|FirebaseFirestore)' -- zhidi_server/src || true
```

Expected: the secret scan prints nothing; the backend contains no Firebase or local Flutter bridge dependency.

- [ ] **Step 9: Commit the verified backend release**

Commit only after every available verification command passes and any environment-blocked Docker/payment sandbox checks are recorded accurately:

```bash
git add zhidi_server
git commit -m "test(server): verify complete renovation workflow"
```

Tagging and production deployment require separate user authorization; do not push, tag or deploy as part of this implementation plan.

---

## Completion Criteria

The backend implementation is complete only when all of the following are true:

- A clean MySQL 8.4 database migrates through V1–V7 without manual SQL.
- Owner and worker fixed-code logins return role-limited JWT sessions; refresh rotation and logout pass tests.
- Only approved/available workers appear publicly, with identical ID, full name and trade in list/detail/project responses.
- Multiple services, including repeated trades, remain distinct throughout appointment and project lists.
- The owner/worker appointment, quote, construction log, inspection and rectification workflow passes over real HTTP and MySQL.
- File content and authorization tests pass for local and OSS storage adapters.
- WeChat and Alipay adapters satisfy the common contract; notifications are verified, amount-safe and idempotent.
- Stage payment sums equal the confirmed quote exactly; refund and reconciliation tests pass.
- Production config fails closed without secrets, MySQL/API ports are not public, and backup/restore scripts are documented and tested where Docker is available.
- OpenAPI verification has no diff and the Flutter migration mapping contains every temporary data source currently in use.
- `./mvnw clean verify` passes with no skipped core workflow tests.
