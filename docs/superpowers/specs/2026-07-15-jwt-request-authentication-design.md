# JWT 入站认证与当前用户身份设计

## 目标

让 Spring Boot 后端能够验证登录接口签发的 Bearer JWT，并为后续业主资料、预约等业务接口提供统一、强类型的当前用户身份。

本阶段只建设认证基础设施和权限测试，不新增临时 `/auth/me` 接口。下一阶段的 `GET /api/v1/owners/me` 将作为第一个正式受保护接口。

## 范围

包含：

- 解析和验证 Bearer JWT。
- 每次受保护请求从数据库读取用户，实时校验账号状态和角色。
- 将当前用户写入 Spring Security 上下文。
- 为 Controller 和 Service 提供强类型 `CurrentUserPrincipal`。
- 统一输出带 trace ID 的 401/403 `ApiResponse`。
- 保护除公开白名单外的 `/api/v1/**`。

不包含：

- Refresh Token、令牌撤销、设备或会话管理。
- 新业务 API、Flutter 修改或数据库迁移。
- 工匠登录流程。
- 对 Swagger、健康检查或其他非 `/api/v1/**` 路径增加认证。

## 公开与受保护路径

以下路径始终公开：

- `/api/v1/auth/**`
- `/actuator/health/**`
- `/v3/api-docs/**`
- `/swagger-ui/**`
- `/swagger-ui.html`

其他 `/api/v1/**` 必须认证。其余路径维持当前可访问行为，避免本阶段意外改变静态资源或框架端点。

公开路径不解析或拒绝客户端携带的旧 JWT。即使 `Authorization` 无效或过期，登录、验证码、Swagger 和健康检查仍应正常处理，便于客户端重新登录。

## 认证流程

1. `TraceIdFilter` 先创建或恢复 trace ID。
2. JWT 认证过滤器仅处理受保护的 `/api/v1/**` 请求。
3. 过滤器读取 `Authorization: Bearer <token>`。
4. `JwtTokenService` 验证签名、格式和过期时间，并返回 claims。
5. `sub` 必须是合法 UUID；过滤器用它调用 `UserRepository.findById`。
6. 用户必须存在且状态为 `ACTIVE`。
7. 从数据库当前手机号和角色构造 `CurrentUserPrincipal`，并转换为 `ROLE_OWNER`、`ROLE_WORKER`、`ROLE_ADMIN` authorities。
8. 将认证对象写入 `SecurityContext` 后继续过滤器链。

数据库是账号状态和授权角色的最终事实来源。JWT 中的 `phone` 和 `roles` 用于令牌自描述，但不作为请求授权依据，因此禁用账号和角色撤销可立即生效。

## 组件边界

### `JwtTokenService`

保留签发职责，并提供公开的验证方法。验证结果必须能让调用方读取 `sub`，同时把 JJWT 的过期、签名、格式异常留给认证层分类，不在日志记录原始令牌。

### `CurrentUserPrincipal`

不可变对象，包含：

- `UUID userId`
- `String phone`
- `Set<UserRole> roles`

它是后续业务代码读取当前身份的稳定接口，不暴露 JPA `User` 实体，也不依赖 JWT claims。

### JWT 认证过滤器

负责路径判断、Bearer 头解析、令牌验证、数据库用户校验和 SecurityContext 建立。过滤器每个请求只执行一次，且在用户名密码认证过滤器之前运行。

### Security 错误写入器

401 与 403 在 Spring Security 过滤器链中发生，不能依赖 MVC 的 `GlobalExceptionHandler`。专用写入器使用 Jackson 输出现有 `ApiResponse<Void>`，并从 MDC 获取 `TraceIdFilter` 已设置的 trace ID。

## 错误契约

所有错误响应使用 `application/json` 和现有结构：

```json
{
  "code": "TOKEN_EXPIRED",
  "message": "access token expired",
  "data": null,
  "traceId": "..."
}
```

错误映射：

- 未提供 Bearer Token：HTTP 401，`AUTHENTICATION_REQUIRED`。
- JWT 已过期：HTTP 401，`TOKEN_EXPIRED`。
- JWT 签名错误、结构错误、`sub` 非 UUID、用户不存在：HTTP 401，`TOKEN_INVALID`。
- 数据库用户为 `DISABLED`：HTTP 403，`ACCOUNT_DISABLED`。
- 已认证但缺少接口所需角色：HTTP 403，`ACCESS_DENIED`。

响应和日志不得包含原始 JWT。认证失败清理 `SecurityContext`，防止线程复用或过滤器继续执行时残留身份。

## 测试策略

使用聚焦单元测试和 Spring Security MockMvc 集成测试覆盖：

- 公开认证接口在无令牌、过期令牌和篡改令牌下仍可访问。
- 受保护测试控制器缺少令牌时返回统一 401。
- 有效 JWT + `ACTIVE` 数据库用户建立正确 principal 和 authorities。
- 过期、篡改、格式错误、非法 `sub` 和用户不存在均返回对应 401。
- `DISABLED` 用户返回 `ACCOUNT_DISABLED` 403。
- 数据库角色变化覆盖 JWT 中的旧角色。
- OWNER 可以访问 OWNER 测试端点，其他当前角色收到 `ACCESS_DENIED` 403。
- 所有 401/403 都包含响应头和响应体 trace ID。

测试专用 Controller 只存在于测试源码，不增加生产 API。

## 完成标准

- `/api/v1/**` 除认证白名单外默认要求有效 JWT。
- 当前用户身份来自数据库，并能被后续 Controller 以强类型 principal 使用。
- 账号禁用和角色变化无需等待 JWT 过期即可生效。
- 公开接口不会被客户端残留的无效 JWT 阻断。
- 聚焦认证测试和后端全量测试均通过。
- `PROJECT_STATUS.md` 更新为 JWT 入站认证已完成，并删除对应未完成项。
