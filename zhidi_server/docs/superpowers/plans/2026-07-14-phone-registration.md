# Phone Registration With Simulated SMS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two documented public APIs that issue a simulated, rate-limited SMS code and use it once to register an active owner account.

**Architecture:** Persist verification state in MySQL, coordinate issuance and registration in a transactional auth service, and expose the flow through a small MVC controller. Generate six-digit codes through an injectable component and persist only an HMAC-SHA256 digest; return plaintext only in the development response.

**Tech Stack:** Java 21, Spring Boot 3.5, Spring MVC, Spring Data JPA, Flyway, MySQL 8.4, Jakarta Validation, JUnit 5, MockMvc, Testcontainers.

## Global Constraints

- Public endpoints are `POST /api/v1/auth/sms-codes` and `POST /api/v1/auth/register`.
- Codes contain six digits, expire after 5 minutes, and are never stored or logged as plaintext.
- Phone limits: once per 60 seconds, 5 per rolling hour, 10 per rolling 24 hours.
- IP limits: 20 per rolling hour, 50 per rolling 24 hours.
- Five wrong attempts invalidate a code; success consumes it; a new code invalidates older codes.
- The simulated code is returned only with the `dev` profile.
- Registration creates an `ACTIVE` user with `OWNER` and does not issue a token.
- Integration tests use the existing Docker-backed MySQL support.

---

### Task 1: Persist Verification Codes

**Files:**
- Create: `src/main/resources/db/migration/V2__sms_verification_codes.sql`
- Create: `src/main/java/com/zhidi/server/auth/SmsVerificationCode.java`
- Create: `src/main/java/com/zhidi/server/auth/SmsVerificationCodeRepository.java`
- Create: `src/test/java/com/zhidi/server/auth/SmsVerificationCodeRepositoryTest.java`

**Interfaces:**
- Consumes: `BaseEntity` and `MySqlContainerSupport`.
- Produces: persisted verification state and rate-limit/locking queries.

- [ ] **Step 1: Write the failing repository test**

Create a `@DataJpaTest` extending `MySqlContainerSupport`. Test persistence, rolling phone/IP counts, newest-code lookup, invalidation, failed-attempt increments, consumption, and pessimistic locking.

```java
@Test
void locksAndConsumesTheLatestActiveCode() {
    Instant now = Instant.parse("2026-07-14T01:00:00Z");
    repository.saveAndFlush(SmsVerificationCode.issue(
        "13800138000", "digest", "127.0.0.1", now, now.plusSeconds(300)));
    SmsVerificationCode code = repository
        .findFirstByPhoneAndConsumedAtIsNullAndInvalidatedAtIsNullOrderByIssuedAtDesc(
            "13800138000").orElseThrow();
    code.consume(now.plusSeconds(10));
    repository.flush();
    assertThat(code.isActiveAt(now.plusSeconds(11))).isFalse();
}
```

- [ ] **Step 2: Run the test and verify RED**

```bash
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test \
  -Dtest=SmsVerificationCodeRepositoryTest \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

Expected: compilation fails because the entity and repository do not exist.

- [ ] **Step 3: Add migration and minimal persistence code**

Create `sms_verification_codes` with `BINARY(16)` ID, `phone VARCHAR(20)`, `code_hash CHAR(64)`, `request_ip VARCHAR(45)`, `issued_at`, `expires_at`, `failed_attempts`, `invalidated_at`, `consumed_at`, `version`, `created_at`, and `updated_at`. Add indexes `(phone, issued_at)`, `(request_ip, issued_at)`, and `(phone, expires_at, consumed_at, invalidated_at)`.

Entity behavior:

```java
public static SmsVerificationCode issue(
    String phone, String codeHash, String requestIp, Instant issuedAt, Instant expiresAt);
public boolean isExpiredAt(Instant now);
public boolean isActiveAt(Instant now);
public int recordFailedAttempt(Instant now);
public void invalidate(Instant now);
public void consume(Instant now);
```

Repository behavior:

```java
long countByPhoneAndIssuedAtGreaterThanEqual(String phone, Instant since);
long countByRequestIpAndIssuedAtGreaterThanEqual(String requestIp, Instant since);
Optional<SmsVerificationCode> findTopByPhoneOrderByIssuedAtDesc(String phone);

@Lock(LockModeType.PESSIMISTIC_WRITE)
Optional<SmsVerificationCode>
findFirstByPhoneAndConsumedAtIsNullAndInvalidatedAtIsNullOrderByIssuedAtDesc(String phone);

@Modifying
@Query("update SmsVerificationCode c set c.invalidatedAt = :now where c.phone = :phone " +
       "and c.consumedAt is null and c.invalidatedAt is null")
int invalidateActiveForPhone(String phone, Instant now);
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Expected: repository tests pass and Flyway applies V1 and V2.

- [ ] **Step 5: Commit**

```bash
git add src/main/resources/db/migration/V2__sms_verification_codes.sql \
  src/main/java/com/zhidi/server/auth/SmsVerificationCode.java \
  src/main/java/com/zhidi/server/auth/SmsVerificationCodeRepository.java \
  src/test/java/com/zhidi/server/auth/SmsVerificationCodeRepositoryTest.java
git commit -m "feat(server): persist SMS verification codes"
```

---

### Task 2: Generate and Hash Codes

**Files:**
- Create: `src/main/java/com/zhidi/server/auth/VerificationCodeGenerator.java`
- Create: `src/main/java/com/zhidi/server/auth/SecureVerificationCodeGenerator.java`
- Create: `src/main/java/com/zhidi/server/auth/VerificationCodeHasher.java`
- Create: `src/main/java/com/zhidi/server/auth/HmacVerificationCodeHasher.java`
- Create: `src/main/java/com/zhidi/server/auth/AuthConfiguration.java`
- Modify: `src/main/resources/application-dev.yml`
- Modify: `src/main/resources/application-test.yml`
- Create: `src/test/java/com/zhidi/server/auth/VerificationCodeSecurityTest.java`

**Interfaces:**
- Produces: `String VerificationCodeGenerator.generate()`, `hash(phone, code)`, and `matches(phone, code, digest)`.
- Consumes: `auth.sms.hmac-secret` supplied through `SMS_CODE_HMAC_SECRET` outside tests.

- [ ] **Step 1: Write failing unit tests**

```java
@Test
void generatesSixDigitsAndHashesWithoutExposingTheCode() {
    assertThat(new SecureVerificationCodeGenerator().generate()).matches("\\d{6}");
    VerificationCodeHasher hasher =
        new HmacVerificationCodeHasher("test-secret-at-least-32-characters");
    String digest = hasher.hash("13800138000", "123456");
    assertThat(digest).hasSize(64).doesNotContain("123456");
    assertThat(hasher.matches("13800138000", "123456", digest)).isTrue();
}
```

- [ ] **Step 2: Run the test and verify RED**

Run Task 1's Maven command with `-Dtest=VerificationCodeSecurityTest`. Expected: missing-type compilation failure.

- [ ] **Step 3: Implement minimal security components**

Use `SecureRandom.nextInt(1_000_000)` and `%06d`. Compute HMAC-SHA256 over `phone + ":" + code`, return lowercase hex, compare with `MessageDigest.isEqual`, and reject secrets shorter than 32 characters. Add a `Clock.systemUTC()` bean. Configure `${SMS_CODE_HMAC_SECRET:dev-only-sms-code-secret-change-me}` in dev and a fixed test-only secret in test.

- [ ] **Step 4: Run the focused test and verify GREEN**

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/zhidi/server/auth src/main/resources/application-dev.yml \
  src/main/resources/application-test.yml src/test/java/com/zhidi/server/auth
git commit -m "feat(server): generate and hash SMS codes"
```

---

### Task 3: Issue Codes With Rate Limits

**Files:**
- Create: `src/main/java/com/zhidi/server/auth/AuthService.java`
- Create: `src/main/java/com/zhidi/server/auth/SmsCodeIssueResult.java`
- Create: `src/test/java/com/zhidi/server/auth/AuthServiceIssueCodeTest.java`
- Modify: `src/main/java/com/zhidi/server/account/User.java`

**Interfaces:**
- Produces: `SmsCodeIssueResult issueCode(String phone, String requestIp)`.
- Consumes: repository, generator, hasher, and `Clock`.

- [ ] **Step 1: Write failing MySQL-backed service tests**

Use an injectable deterministic generator and mutable test clock. Add separate tests for cooldown, sixth phone request/hour, eleventh phone request/day, twenty-first IP request/hour, fifty-first IP request/day, and invalidation of an older active code.

```java
@Test
void rejectsTheSixthPhoneRequestWithinOneHour() {
    issueFiveCodesOutsideCooldown("13800138000", "127.0.0.1");
    assertThatThrownBy(() -> service.issueCode("13800138000", "127.0.0.2"))
        .isInstanceOfSatisfying(BusinessException.class,
            error -> assertThat(error.code()).isEqualTo("SMS_RATE_LIMITED"));
}
```

- [ ] **Step 2: Run the test and verify RED**

Expected: `AuthService` is missing.

- [ ] **Step 3: Implement one transactional issuance path**

Expose or extract the existing phone normalization so `User` and `AuthService` share it. At one transaction boundary: enforce 60-second cooldown; count phone/IP rows in rolling hour/day windows; throw HTTP 429 `SMS_RATE_LIMITED`; invalidate older active records; generate, hash, and save the new code; return:

```java
public record SmsCodeIssueResult(
    String simulatedCode,
    long expiresInSeconds,
    long retryAfterSeconds
) {}
```

- [ ] **Step 4: Run issuance tests and verify GREEN**

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/zhidi/server/auth src/main/java/com/zhidi/server/account/User.java \
  src/test/java/com/zhidi/server/auth/AuthServiceIssueCodeTest.java
git commit -m "feat(server): enforce SMS issuance limits"
```

---

### Task 4: Verify Codes and Register Owners

**Files:**
- Modify: `src/main/java/com/zhidi/server/auth/AuthService.java`
- Create: `src/main/java/com/zhidi/server/auth/RegistrationResult.java`
- Modify: `src/main/java/com/zhidi/server/account/UserRepository.java`
- Create: `src/test/java/com/zhidi/server/auth/AuthServiceRegistrationTest.java`

**Interfaces:**
- Produces: `RegistrationResult register(String phone, String code)`.
- Consumes: latest locked code and `UserRepository`.

- [ ] **Step 1: Write failing registration tests**

Cover success, wrong attempts 1–4, invalidation at 5, expiration, reuse, mismatched phone, and duplicate phone.

```java
@Test
void registersAnActiveOwnerAndConsumesTheCode() {
    generator.willReturn("123456");
    service.issueCode("13800138000", "127.0.0.1");
    RegistrationResult result = service.register("13800138000", "123456");
    assertThat(result.status()).isEqualTo(UserStatus.ACTIVE);
    assertThat(result.roles()).containsExactly(UserRole.OWNER);
}
```

- [ ] **Step 2: Run the test and verify RED**

Expected: missing `register` method and result type.

- [ ] **Step 3: Implement transactional registration**

Require six digits; reject an existing phone with `PHONE_ALREADY_REGISTERED`; lock the latest active code. Map absence/mismatch to `SMS_CODE_INVALID`, expiration to `SMS_CODE_EXPIRED`, and the fifth failure to `SMS_CODE_ATTEMPTS_EXCEEDED`. On success, consume the code, create a user, grant `OWNER`, save and flush, and return:

```java
public record RegistrationResult(
    UUID id, String phone, UserStatus status, Set<UserRole> roles
) {}
```

Map a unique-constraint race to `PHONE_ALREADY_REGISTERED` without returning SQL details.

- [ ] **Step 4: Run all auth service tests and verify GREEN**

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/zhidi/server/auth \
  src/main/java/com/zhidi/server/account/UserRepository.java \
  src/test/java/com/zhidi/server/auth/AuthServiceRegistrationTest.java
git commit -m "feat(server): register owners with SMS codes"
```

---

### Task 5: Expose and Document Auth APIs

**Files:**
- Create: `src/main/java/com/zhidi/server/auth/AuthController.java`
- Create: `src/main/java/com/zhidi/server/auth/RequestSmsCodeRequest.java`
- Create: `src/main/java/com/zhidi/server/auth/RequestSmsCodeResponse.java`
- Create: `src/main/java/com/zhidi/server/auth/RegisterRequest.java`
- Create: `src/main/java/com/zhidi/server/auth/RegisterResponse.java`
- Modify: `src/main/java/com/zhidi/server/common/security/SecurityConfig.java`
- Create: `src/test/java/com/zhidi/server/auth/AuthControllerTest.java`

**Interfaces:**
- Produces: both public HTTP operations and their OpenAPI entries.
- Consumes: `AuthService`, `ApiResponse`, trace ID, Spring `Environment`.

- [ ] **Step 1: Write failing MockMvc tests**

Test both success envelopes, validation, HTTP 429 mapping, development-only code exposure, direct remote-address forwarding, and OpenAPI:

```java
@Test
void openApiListsBothAuthOperations() throws Exception {
    mvc.perform(get("/v3/api-docs"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.paths['/api/v1/auth/sms-codes'].post").exists())
        .andExpect(jsonPath("$.paths['/api/v1/auth/register'].post").exists());
}
```

- [ ] **Step 2: Run the controller test and verify RED**

Expected: missing controller or HTTP 404.

- [ ] **Step 3: Implement validated DTOs and controller**

Use `@Pattern(regexp = "1[3-9]\\d{9}")` for phone and `@Pattern(regexp = "\\d{6}")` for code. Read `HttpServletRequest.getRemoteAddr()`, not forwarding headers.

```java
@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
    @PostMapping("/sms-codes")
    ResponseEntity<ApiResponse<RequestSmsCodeResponse>> issueCode(
        @Valid @RequestBody RequestSmsCodeRequest request,
        HttpServletRequest servletRequest);

    @PostMapping("/register")
    ResponseEntity<ApiResponse<RegisterResponse>> register(
        @Valid @RequestBody RegisterRequest request);
}
```

Omit `simulatedCode` unless `Environment.matchesProfiles("dev")`. Explicitly permit auth, Swagger, and health paths in `SecurityConfig`; require authentication for unrelated future endpoints.

- [ ] **Step 4: Run controller tests and verify GREEN**

- [ ] **Step 5: Commit**

```bash
git add src/main/java/com/zhidi/server/auth \
  src/main/java/com/zhidi/server/common/security/SecurityConfig.java \
  src/test/java/com/zhidi/server/auth/AuthControllerTest.java
git commit -m "feat(server): expose phone registration API"
```

---

### Task 6: End-to-End Verification

**Files:**
- Modify only files required by defects found during verification.

**Interfaces:**
- Consumes: Tasks 1–5.
- Produces: Docker-backed evidence for the complete backend and Swagger contract.

- [ ] **Step 1: Run the complete test suite**

```bash
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

Expected: zero failures and zero errors.

- [ ] **Step 2: Start and inspect the development server**

```bash
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw spring-boot:run \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

Verify `curl -fsS http://localhost:8080/actuator/health` contains `"status":"UP"` and `/v3/api-docs` contains both auth paths.

- [ ] **Step 3: Exercise the real flow**

```bash
curl -sS -X POST http://localhost:8080/api/v1/auth/sms-codes \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138000"}'

curl -sS -X POST http://localhost:8080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"phone":"13800138000","code":"REPLACE_WITH_RETURNED_CODE"}'
```

Expected: the first response exposes a six-digit development code; the second contains `ACTIVE` and `OWNER`; reuse fails.

- [ ] **Step 4: Check the final diff**

```bash
git diff --check
git status --short
```

Commit only focused verification fixes, if any. Preserve all unrelated pre-existing workspace changes.
