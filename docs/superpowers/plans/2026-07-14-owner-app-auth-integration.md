# 业主端手机号认证接入实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**目标：** 为 Spring Boot 增加验证码统一登录和 30 天 JWT，并让 Flutter 业主端登录页真实调用后端、安全保存会话。

**架构：** 后端复用现有验证码实体与限流服务，在一个事务内完成验证码消费、已有业主登录或新业主注册，然后由独立 JWT 组件签发令牌。Flutter 使用可替换的认证 API 客户端和安全会话存储，页面只负责交互，`OwnerAppState` 负责登录状态和退出清理。

**技术栈：** Java 21、Spring Boot 3.5、JJWT 0.12.7、MySQL 8.4、Flutter/Dart、`http`、`flutter_secure_storage`、JUnit 5、MockMvc、Testcontainers、Flutter Test。

## 全局约束

- 只接入业主端；工匠端保持不变。
- 新手机号自动创建 `ACTIVE/OWNER`，已有 `ACTIVE/OWNER` 直接登录。
- `DISABLED` 返回 `ACCOUNT_DISABLED`；无 `OWNER` 返回 `OWNER_ACCESS_DENIED`。
- JWT 使用 `AUTH_JWT_SECRET`、HMAC 签名，有效期固定为 30 天（`2592000` 秒）。
- JWT 包含 `sub`、`phone`、`roles`、`iat`、`exp`，不在数据库或日志保存明文。
- 现有 `/register` 接口及行为保持不变。
- App 通过 `--dart-define=API_BASE_URL=<url>` 获取后端地址，不写死正式环境主机。
- 令牌必须保存到平台安全存储；保存失败不得进入已登录状态。
- 本地 HTTP 例外只允许开发场景；正式环境必须使用 HTTPS。
- 所有功能使用测试驱动开发；后端集成测试使用 Docker MySQL，Flutter 测试使用假实现。

---

### 任务 1：JWT 签发与验证组件

**文件：**
- 新建：`zhidi_server/src/main/java/com/zhidi/server/auth/JwtTokenService.java`
- 新建：`zhidi_server/src/main/java/com/zhidi/server/auth/JwtTokenResult.java`
- 修改：`zhidi_server/src/main/resources/application-dev.yml`
- 修改：`zhidi_server/src/main/resources/application-test.yml`
- 新建：`zhidi_server/src/test/java/com/zhidi/server/auth/JwtTokenServiceTest.java`

**接口：**
- 输入：`User`、现有 `Clock` Bean、`auth.jwt.secret` 与 `auth.jwt.ttl`。
- 输出：`JwtTokenResult issue(UUID userId, String phone, Set<UserRole> roles)`，包含令牌和 `2592000` 秒有效期。

- [ ] **步骤 1：先写失败测试**

```java
@Test
void issuesAThirtyDayTokenWithOwnerClaims() {
    UUID userId = UUID.fromString("01904f24-3f5b-7000-8000-000000000001");
    JwtTokenService service = new JwtTokenService(
        "test-only-jwt-signing-secret-at-least-32-bytes",
        Duration.ofDays(30), Clock.fixed(NOW, ZoneOffset.UTC));

    JwtTokenResult result = service.issue(
        userId, "16600000002", Set.of(UserRole.OWNER));
    Claims claims = service.parse(result.accessToken());

    assertThat(result.expiresInSeconds()).isEqualTo(2_592_000);
    assertThat(claims.getSubject()).isEqualTo(userId.toString());
    assertThat(claims.get("phone", String.class)).isEqualTo("16600000002");
    assertThat(claims.get("roles", List.class)).containsExactly("OWNER");
    assertThat(claims.getExpiration().toInstant()).isEqualTo(NOW.plus(Duration.ofDays(30)));
}
```

- [ ] **步骤 2：运行测试确认 RED**

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test \
  -Dtest=JwtTokenServiceTest \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

预期：因 `JwtTokenService` 和 `JwtTokenResult` 不存在而编译失败。

- [ ] **步骤 3：实现最小 JWT 组件**

```java
public record JwtTokenResult(String accessToken, long expiresInSeconds) {}

@Service
public class JwtTokenService {
    public JwtTokenService(
        @Value("${auth.jwt.secret}") String secret,
        @Value("${auth.jwt.ttl:PT720H}") Duration ttl,
        Clock clock);

    public JwtTokenResult issue(UUID userId, String phone, Set<UserRole> roles);

    Claims parse(String token); // 包级可见，仅供同包测试与后续认证过滤器使用
}
```

使用 `Jwts.builder()` 写入用户 ID、手机号、按名称排序的角色、签发时间和过期时间；使用 `Keys.hmacShaKeyFor` 和 UTF-8 密钥签名。密钥短于 32 字节时启动失败。开发配置使用 `${AUTH_JWT_SECRET:dev-only-jwt-signing-secret-change-me}`，测试配置使用明确的测试密钥，TTL 都是 `PT720H`。

- [ ] **步骤 4：运行测试确认 GREEN**

预期：JWT 字段、签名与过期时间测试全部通过。

- [ ] **步骤 5：提交**

```bash
git add zhidi_server/src/main/java/com/zhidi/server/auth/JwtTokenService.java \
  zhidi_server/src/main/java/com/zhidi/server/auth/JwtTokenResult.java \
  zhidi_server/src/main/resources/application-dev.yml \
  zhidi_server/src/main/resources/application-test.yml \
  zhidi_server/src/test/java/com/zhidi/server/auth/JwtTokenServiceTest.java
git commit -m "feat(server): issue owner JWT sessions"
```

---

### 任务 2：统一验证码登录服务

**文件：**
- 修改：`zhidi_server/src/main/java/com/zhidi/server/auth/AuthService.java`
- 新建：`zhidi_server/src/main/java/com/zhidi/server/auth/LoginResult.java`
- 修改：`zhidi_server/src/test/java/com/zhidi/server/auth/AuthServiceTest.java`
- 修改：`zhidi_server/src/test/java/com/zhidi/server/auth/AuthServiceIntegrationTest.java`

**接口：**
- 输入：手机号、六位验证码、验证码仓库、用户仓库、`JwtTokenService`。
- 输出：`LoginResult loginOwner(String phone, String code)`。

- [ ] **步骤 1：先写失败服务测试**

分别覆盖新用户、已有业主、禁用用户、无 `OWNER` 用户和验证码复用：

```java
@Test
void logsInAnExistingActiveOwnerWithoutCreatingAnotherUser() {
    User owner = persistedOwner("16600000002");
    given(userRepository.findByPhone("16600000002")).willReturn(Optional.of(owner));
    given(jwtTokenService.issue(owner)).willReturn(new JwtTokenResult("jwt", 2_592_000));
    givenValidCode("16600000002", "123456");

    LoginResult result = service.loginOwner("16600000002", "123456");

    assertThat(result.user().id()).isEqualTo(owner.getId());
    assertThat(result.accessToken()).isEqualTo("jwt");
    then(userRepository).should(never()).saveAndFlush(any());
}
```

集成测试使用真实 MySQL 证明新手机号创建一个 `OWNER`、验证码消费后不能再次登录，且已有业主不会重复插入。

- [ ] **步骤 2：运行测试确认 RED**

使用任务 1 的 Maven 命令，将 `-Dtest` 改为 `AuthServiceTest,AuthServiceIntegrationTest`。预期：缺少 `loginOwner` 和 `LoginResult`。

- [ ] **步骤 3：实现统一登录**

```java
public record LoginResult(
    String accessToken,
    String tokenType,
    long expiresInSeconds,
    RegistrationResult user
) {}

@Transactional(noRollbackFor = BusinessException.class)
public LoginResult loginOwner(String rawPhone, String code);
```

先复用一个私有 `verifyAndConsume(phone, code, now)` 方法统一 `/register` 与 `/login` 的验证码校验规则。验证码成功后：

- 无用户时创建 `ACTIVE/OWNER` 并 `saveAndFlush`；
- 已有 `DISABLED` 用户抛出 HTTP 403、`ACCOUNT_DISABLED`；
- 已有用户无 `OWNER` 时抛出 HTTP 403、`OWNER_ACCESS_DENIED`；
- 有效业主直接使用；
- 调用 `jwtTokenService.issue(user)`，返回 `tokenType = "Bearer"`。

数据库唯一约束竞争发生时，读取已存在用户并重新应用状态／角色检查。不要改变 `/register` 已有的重复手机号行为。

- [ ] **步骤 4：运行服务与集成测试确认 GREEN**

预期：新用户、已有用户、拒绝规则和一次性验证码全部通过。

- [ ] **步骤 5：提交**

```bash
git add zhidi_server/src/main/java/com/zhidi/server/auth/AuthService.java \
  zhidi_server/src/main/java/com/zhidi/server/auth/LoginResult.java \
  zhidi_server/src/test/java/com/zhidi/server/auth/AuthServiceTest.java \
  zhidi_server/src/test/java/com/zhidi/server/auth/AuthServiceIntegrationTest.java
git commit -m "feat(server): add unified owner login"
```

---

### 任务 3：公开登录 API 与 Swagger 契约

**文件：**
- 新建：`zhidi_server/src/main/java/com/zhidi/server/auth/LoginRequest.java`
- 新建：`zhidi_server/src/main/java/com/zhidi/server/auth/LoginResponse.java`
- 新建：`zhidi_server/src/main/java/com/zhidi/server/auth/AuthUserResponse.java`
- 修改：`zhidi_server/src/main/java/com/zhidi/server/auth/AuthController.java`
- 修改：`zhidi_server/src/test/java/com/zhidi/server/auth/AuthControllerTest.java`

**接口：**
- 输入：`POST /api/v1/auth/login` 的 `{phone, code}`。
- 输出：现有 `ApiResponse<LoginResponse>` 外层结构。

- [ ] **步骤 1：先写失败 MockMvc 测试**

```java
@Test
void logsInAndDocumentsTheOperation() throws Exception {
    given(authService.loginOwner("16600000002", "123456"))
        .willReturn(ownerLoginResult());

    mvc.perform(post("/api/v1/auth/login")
            .contentType(APPLICATION_JSON)
            .content("{\"phone\":\"16600000002\",\"code\":\"123456\"}"))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.data.accessToken").value("jwt"))
        .andExpect(jsonPath("$.data.tokenType").value("Bearer"))
        .andExpect(jsonPath("$.data.user.roles[0]").value("OWNER"));

    mvc.perform(get("/v3/api-docs"))
        .andExpect(jsonPath("$.paths['/api/v1/auth/login'].post").exists());
}
```

另加请求格式、`ACCOUNT_DISABLED` 和 `OWNER_ACCESS_DENIED` 的状态码／错误结构测试。

- [ ] **步骤 2：运行测试确认 RED**

使用 Maven 聚焦 `AuthControllerTest`。预期：登录路径 404，OpenAPI 中不存在路径。

- [ ] **步骤 3：实现 DTO 与控制器**

```java
public record LoginRequest(
    @NotBlank @Pattern(regexp = "1[3-9]\\d{9}") String phone,
    @NotBlank @Pattern(regexp = "\\d{6}") String code
) {}

public record AuthUserResponse(
    UUID id, String phone, UserStatus status, Set<UserRole> roles
) {}

public record LoginResponse(
    String accessToken, String tokenType, long expiresInSeconds,
    AuthUserResponse user
) {}
```

在 `AuthController` 增加 `@PostMapping("/login")`，调用 `authService.loginOwner` 并映射现有 trace ID。

- [ ] **步骤 4：运行控制器测试确认 GREEN**

- [ ] **步骤 5：提交**

```bash
git add zhidi_server/src/main/java/com/zhidi/server/auth \
  zhidi_server/src/test/java/com/zhidi/server/auth/AuthControllerTest.java
git commit -m "feat(server): expose owner login API"
```

---

### 任务 4：Flutter 认证 API 客户端

**文件：**
- 修改：`zhidi_app/pubspec.yaml`
- 新建：`zhidi_app/lib/services/auth_api_client.dart`
- 新建：`zhidi_app/test/auth_api_client_test.dart`

**接口：**
- 输入：基础 URL、可注入的 `http.Client`、手机号和验证码。
- 输出：`requestSmsCode`、`loginOwner`、类型化响应与 `AuthApiException`。

- [ ] **步骤 1：先写失败 Dart 测试**

```dart
test('parses SMS and login envelopes', () async {
  final client = AuthApiClient(
    baseUrl: Uri.parse('http://localhost:8080'),
    httpClient: fakeHttpClient([
      okSmsEnvelope(simulatedCode: '256438'),
      okLoginEnvelope(accessToken: 'jwt'),
    ]),
  );

  final sms = await client.requestSmsCode('16600000002');
  final login = await client.loginOwner('16600000002', '256438');

  expect(sms.simulatedCode, '256438');
  expect(login.accessToken, 'jwt');
  expect(login.user.roles, contains('OWNER'));
});
```

增加 `SMS_RATE_LIMITED`、验证码错误、非 JSON、超时和无法连接的类型化异常测试。

- [ ] **步骤 2：运行测试确认 RED**

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
HOME=/Users/liupei/Documents/zhidi/zhidi_app/.codex-flutter-home \
  ../flutter/bin/flutter test test/auth_api_client_test.dart
```

预期：缺少 `AuthApiClient`。

- [ ] **步骤 3：添加依赖并实现客户端**

在 `pubspec.yaml` 添加：

```yaml
http: ^1.5.0
flutter_secure_storage: ^9.2.4
```

主要接口：

```dart
abstract interface class OwnerAuthApi {
  Future<SmsCodeResponse> requestSmsCode(String phone);
  Future<OwnerLoginResponse> loginOwner(String phone, String code);
}

final class AuthApiClient implements OwnerAuthApi {
  AuthApiClient({Uri? baseUrl, http.Client? httpClient});
  static const configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL', defaultValue: 'http://localhost:8080');
}
```

每个请求设置 JSON 头和 10 秒超时。解析 `ApiResponse`，非 `OK` 时抛出含 `code`、`message`、HTTP 状态的 `AuthApiException`。不得记录验证码或 JWT。

- [ ] **步骤 4：执行 `flutter pub get` 并运行测试确认 GREEN**

预期：客户端成功和错误测试全部通过，`pubspec.lock` 更新。

- [ ] **步骤 5：提交**

```bash
git add zhidi_app/pubspec.yaml zhidi_app/pubspec.lock \
  zhidi_app/lib/services/auth_api_client.dart zhidi_app/test/auth_api_client_test.dart
git commit -m "feat(owner): add authentication API client"
```

---

### 任务 5：安全会话存储与业主状态

**文件：**
- 新建：`zhidi_app/lib/services/auth_session_store.dart`
- 修改：`zhidi_app/lib/app/owner_app_state.dart`
- 修改：`zhidi_app/lib/main.dart`
- 新建：`zhidi_app/test/auth_session_store_test.dart`
- 修改：`zhidi_app/test/owner_app_startup_test.dart`

**接口：**
- 输出：`AuthSessionStore.save/read/clear`；`OwnerAppState.completeAuthenticatedLogin`；退出时清理令牌。

- [ ] **步骤 1：先写失败状态与存储测试**

```dart
test('saves a session before marking owner logged in and clears it on logout', () async {
  final sessions = MemoryAuthSessionStore();
  final state = await OwnerAppState.memory(sessionStore: sessions);

  await state.completeAuthenticatedLogin(ownerLoginResponse());
  expect(state.isLoggedIn, isTrue);
  expect(await sessions.read(), isNotNull);

  await state.logout();
  expect(state.isLoggedIn, isFalse);
  expect(await sessions.read(), isNull);
});
```

增加安全存储写入失败时 `isLoggedIn` 仍为 false 的测试。

- [ ] **步骤 2：运行测试确认 RED**

运行 `flutter test test/auth_session_store_test.dart test/owner_app_startup_test.dart`。预期：缺少会话接口和认证登录方法。

- [ ] **步骤 3：实现安全存储与状态注入**

```dart
abstract interface class AuthSessionStore {
  Future<AuthSession?> read();
  Future<void> save(AuthSession session);
  Future<void> clear();
}

final class SecureAuthSessionStore implements AuthSessionStore {
  SecureAuthSessionStore([FlutterSecureStorage? storage]);
}
```

为 `OwnerAppState.memory/load` 增加可选 `AuthSessionStore`，正式入口传入 `SecureAuthSessionStore`。`completeAuthenticatedLogin` 先保存 JWT，再持久化手机号和 `isLoggedIn`；任一步失败时不通知成功。`logout` 先清理令牌，再清理本地登录状态。

- [ ] **步骤 4：运行状态测试确认 GREEN**

- [ ] **步骤 5：提交**

```bash
git add zhidi_app/lib/services/auth_session_store.dart \
  zhidi_app/lib/app/owner_app_state.dart zhidi_app/lib/main.dart \
  zhidi_app/test/auth_session_store_test.dart zhidi_app/test/owner_app_startup_test.dart
git commit -m "feat(owner): persist secure authentication sessions"
```

---

### 任务 6：登录页接入真实接口

**文件：**
- 修改：`zhidi_app/lib/pages/auth/login_page.dart`
- 修改：`zhidi_app/lib/main.dart`
- 新建：`zhidi_app/test/login_page_auth_test.dart`

**接口：**
- 输入：`OwnerAuthApi`、`AuthSessionStore` 已注入的 `OwnerAppState`。
- 输出：真实获取验证码、自动填入、倒计时、登录和中文错误提示。

- [ ] **步骤 1：先写失败 Widget 测试**

```dart
testWidgets('fills development code and logs in through the backend', (tester) async {
  final api = FakeOwnerAuthApi(simulatedCode: '256438', login: ownerLoginResponse());
  await tester.pumpWidget(loginHarness(api: api));

  await tester.enterText(find.byKey(const Key('login-phone')), '16600000002');
  await tester.tap(find.text('获取验证码'));
  await tester.pump();

  expect(find.text('开发验证码已填入'), findsOneWidget);
  expect(find.widgetWithText(TextField, '256438'), findsOneWidget);

  await tester.tap(find.text('登录'));
  await tester.pumpAndSettle();
  expect(api.loginCalls.single.code, '256438');
});
```

增加发送失败不倒计时、`SMS_RATE_LIMITED`、验证码错误、网络异常、重复点击禁用和登录失败不进入首页测试。

- [ ] **步骤 2：运行测试确认 RED**

运行 `flutter test test/login_page_auth_test.dart`。预期：页面仍使用模拟流程，测试失败。

- [ ] **步骤 3：实现页面接入**

为手机号、验证码输入框增加稳定 Key。`_sendCode` 改为 `Future<void>`，成功后才设置 60 秒倒计时；如果有 `simulatedCode`，写入 `_codeController` 并显示提示。`_login` 调用 `api.loginOwner`，再调用 `OwnerAppState.completeAuthenticatedLogin`。所有异步分支使用 `try/catch/finally` 恢复按钮状态，并通过一个错误码映射函数显示已确认的中文文案。

在 owner 应用入口创建一个 `AuthApiClient` 并注入 `LoginPage`；不改工匠端入口。

- [ ] **步骤 4：运行 Widget 测试确认 GREEN**

- [ ] **步骤 5：提交**

```bash
git add zhidi_app/lib/pages/auth/login_page.dart zhidi_app/lib/main.dart \
  zhidi_app/test/login_page_auth_test.dart
git commit -m "feat(owner): connect phone login to backend"
```

---

### 任务 7：平台开发配置与全链路验证

**文件：**
- 修改：`zhidi_app/ios/Runner/Info.plist`
- 修改：`zhidi_app/android/app/src/debug/AndroidManifest.xml`（不存在则新建，仅用于 debug）
- 修改：`zhidi_app/README.md`

**接口：**
- 输入：本地后端地址、iOS/Android 调试网络权限。
- 输出：模拟器可访问本地 HTTP 后端，发布配置不全局放开明文流量。

- [ ] **步骤 1：写清本地启动契约并检查失败场景**

在 README 增加三条可复制命令：iOS 使用 `localhost:8080`、Android 使用 `10.0.2.2:8080`、真机使用局域网 IP。先运行 iOS/Android 配置检查，确认当前本地 HTTP 请求会被平台策略阻止或配置缺失。

- [ ] **步骤 2：加入仅开发环境的网络配置**

iOS 使用 debug 专用 plist 合并或最小本地域名例外；Android 只在 `src/debug/AndroidManifest.xml` 设置 `android:usesCleartextTraffic="true"`。不要修改 release Manifest 为全局明文允许。

- [ ] **步骤 3：运行完整后端测试**

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

预期：0 failures、0 errors。

- [ ] **步骤 4：运行 Flutter 静态检查和完整测试**

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
HOME=/Users/liupei/Documents/zhidi/zhidi_app/.codex-flutter-home \
  ../flutter/bin/flutter analyze
HOME=/Users/liupei/Documents/zhidi/zhidi_app/.codex-flutter-home \
  ../flutter/bin/flutter test
```

预期：静态检查无错误，完整测试 0 failures。

- [ ] **步骤 5：真实本地流程验证**

启动后端后，以 owner flavor 启动 iOS 模拟器：

```bash
../flutter/bin/flutter run \
  --dart-define=FLUTTER_APP_FLAVOR=owner \
  --dart-define=API_BASE_URL=http://localhost:8080
```

使用一个未注册手机号获取模拟验证码并登录，确认：自动填入、新业主创建、JWT 写入安全存储、进入既有 onboarding/home 路由、退出后令牌清除。随后使用同一手机号再次获取验证码，确认走已有业主登录且不创建重复用户。

- [ ] **步骤 6：检查差异并提交配置文档**

```bash
git diff --check
git status --short
git add zhidi_app/ios/Runner/Info.plist \
  zhidi_app/android/app/src/debug/AndroidManifest.xml zhidi_app/README.md
git commit -m "docs(owner): document local authentication setup"
```
