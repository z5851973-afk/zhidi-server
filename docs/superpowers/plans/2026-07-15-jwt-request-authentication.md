# JWT 入站认证与当前用户身份实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 验证登录签发的 Bearer JWT，以数据库当前用户状态和角色建立 Spring Security 身份，并为受保护 API 提供统一 401/403 响应。

**Architecture:** `JwtAuthenticationFilter` 只处理公开白名单之外的 `/api/v1/**`，调用 `JwtTokenService.verify` 验证令牌，再按 `sub` 查询 `UserRepository`。数据库用户被映射为不可变 `CurrentUserPrincipal` 和 `ROLE_*` authorities；过滤器认证错误与 Spring Security 授权错误都由统一 JSON 写入器输出已有 `ApiResponse`。

**Tech Stack:** Java 21、Spring Boot 3.5、Spring Security 6、JJWT 0.12.7、Jackson、JUnit 5、Mockito、MockMvc。

## Global Constraints

- 只修改 `zhidi_server`、本计划、对应设计文档和 `PROJECT_STATUS.md`；不修改 Flutter。
- 每个受保护请求必须用 JWT `sub` 查询数据库，账号状态和角色以数据库为准。
- 公开路径忽略无效或过期 JWT，不得阻断登录、验证码、Swagger 或健康检查。
- 只有公开白名单之外的 `/api/v1/**` 必须认证；其他路径维持当前可访问行为。
- 不新增临时 `/auth/me` 或其他生产业务 API；测试 Controller 只放在测试源码。
- 不新增数据库迁移、Refresh Token、令牌撤销或会话管理。
- 不记录或返回原始 JWT。
- 所有 401/403 使用 `ApiResponse<Void>` 并携带当前 trace ID。
- 未经用户明确要求，不执行 `git add`、`git commit`、推送或创建 PR。

---

### Task 1: JWT 验证接口与强类型当前用户

**Files:**
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/security/CurrentUserPrincipal.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/auth/JwtTokenService.java`
- Modify: `zhidi_server/src/test/java/com/zhidi/server/auth/JwtTokenServiceTest.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/common/security/CurrentUserPrincipalTest.java`

**Interfaces:**
- Produces: `public Claims JwtTokenService.verify(String token)`。
- Produces: `public record CurrentUserPrincipal(UUID userId, String phone, Set<UserRole> roles)`。
- Produces: `Collection<? extends GrantedAuthority> CurrentUserPrincipal.authorities()`，角色映射为 `ROLE_<ENUM_NAME>`。

- [x] **Step 1: 写 JWT 验证失败测试**

在 `JwtTokenServiceTest` 增加测试，证明公开验证接口可读取 subject，且过期令牌抛出 JJWT 的 `ExpiredJwtException`：

```java
@Test
void verifiesIssuedTokensThroughThePublicApi() {
    UUID userId = UUID.fromString("01904f24-3f5b-7000-8000-000000000001");
    JwtTokenService service = serviceAt(NOW);
    String token = service.issue(userId, "16600000002", Set.of(UserRole.OWNER)).accessToken();

    assertThat(service.verify(token).getSubject()).isEqualTo(userId.toString());
}

@Test
void rejectsExpiredTokens() {
    UUID userId = UUID.fromString("01904f24-3f5b-7000-8000-000000000001");
    String token = serviceAt(NOW)
        .issue(userId, "16600000002", Set.of(UserRole.OWNER)).accessToken();

    assertThatThrownBy(() -> serviceAt(NOW.plus(Duration.ofDays(31))).verify(token))
        .isInstanceOf(ExpiredJwtException.class);
}
```

测试内增加 `serviceAt(Instant now)` 帮助方法，固定使用测试密钥和 30 天 TTL。

- [x] **Step 2: 运行 JWT 测试确认 RED**

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test \
  -Dtest=JwtTokenServiceTest \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

预期：编译失败，因为 `verify(String)` 尚不存在。

- [x] **Step 3: 实现公开 JWT 验证接口**

将现有包级 `parse` 改为：

```java
public Claims verify(String token) {
    return Jwts.parser()
        .verifyWith(signingKey)
        .clock(() -> Date.from(clock.instant()))
        .build()
        .parseSignedClaims(token)
        .getPayload();
}
```

测试中的原 `service.parse(...)` 同步改为 `service.verify(...)`。显式传入同一个 `Clock`，保证过期判断可确定测试。

- [x] **Step 4: 写 principal 失败测试**

```java
@Test
void mapsCurrentDatabaseRolesToSpringAuthorities() {
    UUID userId = UUID.fromString("01904f24-3f5b-7000-8000-000000000001");
    CurrentUserPrincipal principal = new CurrentUserPrincipal(
        userId, "16600000002", Set.of(UserRole.ADMIN, UserRole.OWNER));

    assertThat(principal.authorities())
        .extracting(GrantedAuthority::getAuthority)
        .containsExactly("ROLE_ADMIN", "ROLE_OWNER");
    assertThat(principal.roles()).isUnmodifiable();
}
```

- [x] **Step 5: 运行 principal 测试确认 RED**

运行 `-Dtest=CurrentUserPrincipalTest`，预期因类型不存在而编译失败。

- [x] **Step 6: 实现不可变 principal**

```java
public record CurrentUserPrincipal(UUID userId, String phone, Set<UserRole> roles) {
    public CurrentUserPrincipal {
        Objects.requireNonNull(userId, "userId must not be null");
        if (!StringUtils.hasText(phone)) {
            throw new IllegalArgumentException("phone must not be blank");
        }
        roles = Set.copyOf(roles);
    }

    public Collection<? extends GrantedAuthority> authorities() {
        return roles.stream()
            .map(Enum::name)
            .sorted()
            .map(role -> new SimpleGrantedAuthority("ROLE_" + role))
            .toList();
    }
}
```

- [x] **Step 7: 运行 Task 1 测试确认 GREEN**

运行 `-Dtest=JwtTokenServiceTest,CurrentUserPrincipalTest`，预期全部通过。

---

### Task 2: 统一 Security JSON 错误响应

**Files:**
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/security/SecurityErrorWriter.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/common/security/SecurityErrorWriterTest.java`

**Interfaces:**
- Produces: `void SecurityErrorWriter.write(HttpServletResponse response, HttpStatus status, String code, String message)`。
- Uses: `ApiResponse.error(code, message, MDC.get(TraceIdFilter.MDC_KEY))`。

- [x] **Step 1: 写失败测试**

使用 `MockHttpServletResponse` 和真实 `ObjectMapper`：

```java
@Test
void writesTheSharedJsonEnvelopeWithTraceId() throws Exception {
    MDC.put(TraceIdFilter.MDC_KEY, "trace-security");
    MockHttpServletResponse response = new MockHttpServletResponse();

    writer.write(response, HttpStatus.UNAUTHORIZED,
        "TOKEN_INVALID", "access token invalid");

    assertThat(response.getStatus()).isEqualTo(401);
    assertThat(response.getContentType()).isEqualTo(MediaType.APPLICATION_JSON_VALUE);
    assertThatJson(response.getContentAsString()).and(
        a -> a.node("code").isEqualTo("TOKEN_INVALID"),
        a -> a.node("data").isNull(),
        a -> a.node("traceId").isEqualTo("trace-security"));
}
```

若项目未使用 `JsonContentAssert`，用 `ObjectMapper.readTree` 后 AssertJ 校验字段，避免增加依赖。

- [x] **Step 2: 运行测试确认 RED**

运行 `-Dtest=SecurityErrorWriterTest`，预期因 `SecurityErrorWriter` 不存在而编译失败。

- [x] **Step 3: 实现最小写入器**

```java
@Component
public final class SecurityErrorWriter {
    private final ObjectMapper objectMapper;

    public SecurityErrorWriter(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    public void write(HttpServletResponse response, HttpStatus status,
            String code, String message) throws IOException {
        response.setStatus(status.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        objectMapper.writeValue(response.getOutputStream(),
            ApiResponse.error(code, message, MDC.get(TraceIdFilter.MDC_KEY)));
    }
}
```

- [x] **Step 4: 运行 Task 2 测试确认 GREEN**

运行 `-Dtest=SecurityErrorWriterTest`，预期通过且响应为 UTF-8 JSON。

---

### Task 3: 数据库回查 JWT 认证过滤器

**Files:**
- Create: `zhidi_server/src/main/java/com/zhidi/server/common/security/JwtAuthenticationFilter.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/common/security/JwtAuthenticationFilterTest.java`

**Interfaces:**
- Consumes: `JwtTokenService.verify(String)`、`UserRepository.findById(UUID)`、`SecurityErrorWriter.write(...)`。
- Produces: Spring Security `UsernamePasswordAuthenticationToken`，principal 为 `CurrentUserPrincipal`。
- Produces: `shouldNotFilter` 对非 `/api/v1/**` 与 `/api/v1/auth/**` 返回 `true`。

- [x] **Step 1: 写路径与缺失令牌失败测试**

```java
@Test
void ignoresPublicAuthenticationPathsEvenWithABadToken() throws Exception {
    MockHttpServletRequest request = request("/api/v1/auth/login");
    request.addHeader(HttpHeaders.AUTHORIZATION, "Bearer broken");

    filter.doFilter(request, response, chain);

    verify(chain).doFilter(request, response);
    verifyNoInteractions(jwtTokenService, userRepository, errorWriter);
}

@Test
void rejectsProtectedRequestsWithoutABearerToken() throws Exception {
    MockHttpServletRequest request = request("/api/v1/owners/me");

    filter.doFilter(request, response, chain);

    verify(errorWriter).write(response, HttpStatus.UNAUTHORIZED,
        "AUTHENTICATION_REQUIRED", "authentication required");
    verifyNoInteractions(chain);
}
```

- [x] **Step 2: 写有效用户与数据库角色失败测试**

Mock `Claims.getSubject()` 返回固定 UUID；Mock `User` 返回 `ACTIVE`、数据库手机号和仅 `OWNER` 角色，即使 JWT claims 带 `ADMIN`。捕获传给 filter chain 时的 `SecurityContextHolder.getContext().getAuthentication()`，断言 principal 字段来自数据库且 authorities 只有 `ROLE_OWNER`。

- [x] **Step 3: 写错误分类失败测试**

分别覆盖：

```java
given(jwtTokenService.verify(token)).willThrow(new ExpiredJwtException(
    mock(Header.class), mock(Claims.class), "expired"));
// -> 401 TOKEN_EXPIRED

given(jwtTokenService.verify(token)).willThrow(new JwtException("bad token"));
// -> 401 TOKEN_INVALID

given(claims.getSubject()).willReturn("not-a-uuid");
// -> 401 TOKEN_INVALID

given(userRepository.findById(userId)).willReturn(Optional.empty());
// -> 401 TOKEN_INVALID

given(user.getStatus()).willReturn(UserStatus.DISABLED);
// -> 403 ACCOUNT_DISABLED
```

每个失败分支都断言 chain 未继续、`SecurityContextHolder` 无认证，并在 `@AfterEach` 调用 `SecurityContextHolder.clearContext()`。

- [x] **Step 4: 运行过滤器测试确认 RED**

运行 `-Dtest=JwtAuthenticationFilterTest`，预期因过滤器不存在而编译失败。

- [x] **Step 5: 实现过滤器最小路径**

实现 `OncePerRequestFilter`：

```java
@Override
protected boolean shouldNotFilter(HttpServletRequest request) {
    String path = request.getRequestURI();
    return !path.startsWith("/api/v1/") || path.startsWith("/api/v1/auth/");
}
```

在 `doFilterInternal` 中严格要求单个非空 `Bearer ` 前缀；验证 token、解析 UUID、查询用户、检查状态、构造 principal 和 `UsernamePasswordAuthenticationToken.authenticated(...)`。成功后调用 chain，并在请求完成后清理 SecurityContext。

- [x] **Step 6: 实现精确异常映射**

捕获顺序必须是：

```java
catch (ExpiredJwtException exception) {
    unauthorized(response, "TOKEN_EXPIRED", "access token expired");
}
catch (JwtException | IllegalArgumentException exception) {
    unauthorized(response, "TOKEN_INVALID", "access token invalid");
}
```

用户不存在走 `TOKEN_INVALID`；`DISABLED` 直接写 403 `ACCOUNT_DISABLED`。不要把异常对象或 token 写入日志。

- [x] **Step 7: 运行 Task 3 测试确认 GREEN**

运行 `-Dtest=JwtAuthenticationFilterTest`，预期所有路径、身份和错误分类测试通过。

---

### Task 4: Security 配置、权限集成测试与状态更新

**Files:**
- Modify: `zhidi_server/src/main/java/com/zhidi/server/common/security/SecurityConfig.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/common/security/JwtSecurityIntegrationTest.java`
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- Consumes: `JwtAuthenticationFilter`、`SecurityErrorWriter`。
- Produces: `/api/v1/auth/**` 等白名单公开；其他 `/api/v1/**` authenticated；其他路径 permitAll。
- Produces: 方法级 `@PreAuthorize` 支持，用于后续业务角色限制。

- [x] **Step 1: 写 MockMvc 失败集成测试**

创建测试专用 Controller：

```java
@RestController
static class ProtectedProbeController {
    @GetMapping("/api/v1/test/current-user")
    CurrentUserPrincipal currentUser(Authentication authentication) {
        return (CurrentUserPrincipal) authentication.getPrincipal();
    }

    @PreAuthorize("hasRole('OWNER')")
    @GetMapping("/api/v1/test/owner-only")
    ResponseEntity<Void> ownerOnly() {
        return ResponseEntity.noContent().build();
    }
}
```

使用真实 `JwtTokenService`、`@MockitoBean UserRepository` 和固定测试密钥。覆盖：

- 无 token 访问 current-user -> 401 `AUTHENTICATION_REQUIRED`。
- 有效 token + ACTIVE OWNER -> 200，响应 userId/phone/roles 来自数据库。
- 数据库当前只有 WORKER、JWT 仍含 OWNER -> owner-only 返回 403 `ACCESS_DENIED`。
- DISABLED -> 403 `ACCOUNT_DISABLED`。
- 篡改 token -> 401 `TOKEN_INVALID`。
- 过期 token -> 401 `TOKEN_EXPIRED`。
- `/api/v1/auth/login` 携带坏 token 时仍进入 Controller 层而不是 Security 401；Mock `AuthService` 返回正常结果或用一个测试公开 probe 验证白名单。
- 401/403 的 `X-Trace-Id` 响应头和 JSON `traceId` 均等于请求提供值。

- [x] **Step 2: 运行集成测试确认 RED**

运行 `-Dtest=JwtSecurityIntegrationTest`，预期受保护接口仍被放行或 Security 配置缺少依赖，测试失败。

- [x] **Step 3: 收紧 SecurityConfig**

```java
@Configuration
@EnableMethodSecurity
public class SecurityConfig {
    @Bean
    SecurityFilterChain securityFilterChain(HttpSecurity http,
            JwtAuthenticationFilter jwtFilter,
            SecurityErrorWriter errors) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable)
            .sessionManagement(session -> session
                .sessionCreationPolicy(SessionCreationPolicy.STATELESS))
            .authorizeHttpRequests(authorize -> authorize
                .requestMatchers(PUBLIC_PATHS).permitAll()
                .requestMatchers("/api/v1/**").authenticated()
                .anyRequest().permitAll())
            .exceptionHandling(exceptions -> exceptions
                .authenticationEntryPoint((request, response, exception) ->
                    errors.write(response, HttpStatus.UNAUTHORIZED,
                        "AUTHENTICATION_REQUIRED", "authentication required"))
                .accessDeniedHandler((request, response, exception) ->
                    errors.write(response, HttpStatus.FORBIDDEN,
                        "ACCESS_DENIED", "access denied")))
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class)
            .build();
    }
}
```

`PUBLIC_PATHS` 精确包含设计文档列出的五组路径。

- [x] **Step 4: 运行认证聚焦测试确认 GREEN**

```bash
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test \
  -Dtest=JwtTokenServiceTest,CurrentUserPrincipalTest,SecurityErrorWriterTest,JwtAuthenticationFilterTest,JwtSecurityIntegrationTest \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

预期：0 failures、0 errors。

- [x] **Step 5: 运行后端全量测试**

```bash
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

预期：全部测试通过；若原有 Smoke 测试的 `/api/v1/test/validation` 因默认保护变为 401，应在该测试请求中使用有效测试认证，而不是把生产 `/api/v1/test/**` 加入公开白名单。

- [x] **Step 6: 更新 PROJECT_STATUS.md**

验证通过后：

- 在“Spring Boot 后端/当前已完成”增加 JWT 入站验证、数据库用户状态/角色回查和统一 401/403。
- 从“后端关键缺口”删除“JWT 请求认证过滤器和资源权限控制；当前其他请求仍为 permitAll”。
- 将当前优先方向第 1 项改为已完成事实，并把业主资料 GET/PUT 提升为下一优先项。
- 修正 Android 启动命令为 `--flavor owner` 和 `API_BASE_URL=http://10.0.2.2:8080`。

- [x] **Step 7: 最终差异和验证检查**

```bash
cd /Users/liupei/Documents/zhidi
git diff --check
git status --short
git diff -- zhidi_server PROJECT_STATUS.md \
  docs/superpowers/specs/2026-07-15-jwt-request-authentication-design.md \
  docs/superpowers/plans/2026-07-15-jwt-request-authentication.md
```

确认没有修改 Flutter、没有泄露 token/密钥、没有未经授权提交。
