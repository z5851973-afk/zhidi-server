# 知底项目状态

> Codex 快速上下文。最近核对：2026-07-15。开始任务时先读本文件；只有任务涉及的部分才继续读取源码或 `docs/superpowers/` 下的设计与计划。

## 1. 产品是什么

“知底”是装修服务平台，核心目标是让业主直接找到可信工匠/工长，并围绕预约、报价、施工、验收和售后形成闭环。

当前 Flutter 工程同时包含两个应用角色：

- 业主端：浏览装修服务和工匠、预约、查看报价与项目进度、沟通、验收、管理个人资料。
- 工匠端：登录、维护资料、接单、报价、提交施工日报与验收、查看收入和消息。

较早的 MVP 产品设计强调“业主直连工长、平台客服派单、施工过程留痕”；后续 Spring Boot 设计扩大到报价、项目、支付和文件服务。实际开发时以当前用户任务和源码为准，不要把设计文档里的规划误判为已实现功能。

## 2. 仓库结构

```text
zhidi/
├── zhidi_app/       Flutter 应用，业主端和工匠端共用一个工程
├── zhidi_server/    Java 21 + Spring Boot 3.5 后端
├── flutter/         仓库内 Flutter SDK，不是业务应用
├── docs/superpowers/specs/  产品/功能设计文档
├── docs/superpowers/plans/  实施计划；计划存在不代表已经完成
└── .worktrees/      其他隔离工作树，不属于当前主工作目录
```

重要入口：

- Flutter 启动：`zhidi_app/lib/main.dart`
- 业主状态：`zhidi_app/lib/app/owner_app_state.dart`
- 工匠状态：`zhidi_app/lib/app/worker_app_state.dart`
- 后端启动：`zhidi_server/src/main/java/com/zhidi/server/ZhidiServerApplication.java`
- 后端迁移：`zhidi_server/src/main/resources/db/migration/`

## 3. 当前已完成

### Flutter 应用

- 支持 Android、iOS、Web、macOS、Windows 和 Linux 工程结构。
- Android 通过 `--flavor owner` 启动业主端；未指定时默认启动工匠端。
- 两端共用设计主题和中文本地化。
- 业主端已有启动页、手机号登录、首次资料引导、首页、工匠列表/详情、预约与订单、透明价格、装修项目、消息、聊天、个人中心、地址、收藏、设置、售后等页面或交互原型。
- 工匠端已有登录、首页、订单详情、报价、施工日报、验收、收入、资料等页面或交互原型。
- 业主端手机号验证码登录已接入 Spring Boot；JWT 使用平台安全存储保存。
- 业主资料 GET/PUT 接入和首次引导保存已在 Android 模拟器完成端到端验证：登录后读取服务端默认资料，首次引导提交资料落库，强停重启后不再回到首次引导。后端 API、Flutter API client、会话/资料状态同步、登录页、首次引导页、业主端 app shell 路由、设置退出、个人中心基础 UI token 化、报价收藏和报价页保存入口已整理提交；剩余订单/施工过程等个人中心扩展仍在主工作区未提交改动中。
- 大量业务状态已能在本地持久化，并带有 Mock 示例数据。
- 部分业主/工匠订单和工匠资料使用 Firestore 桥接；这不是完整正式后端。
- 已存在 Flutter 单元/Widget 测试，覆盖认证、启动、引导、退出以及若干重点页面。

### Spring Boot 后端

- 基础框架：Java 21、Spring Boot 3.5、Maven、Spring MVC、Spring Data JPA、Spring Security、Flyway、MySQL、OpenAPI、Actuator。
- 已有统一 API 响应、trace ID、全局异常处理和基础审计表。
- 已完成用户、角色和短信验证码数据模型及 Flyway 迁移。
- 已完成业主验证码请求、注册、统一登录和 30 天 JWT 签发。
- 已完成 JWT 入站认证：受保护 API 回查数据库用户状态与角色，并统一返回 JSON 401/403 错误。
- 已实现验证码哈希保存、5 分钟有效期、错误次数限制，以及手机号/IP 发送频率限制。
- 已有服务、控制器、JWT、仓库和 MySQL Testcontainers 测试。
- 业主资料 MySQL 持久化、`GET /api/v1/owners/me`、`PUT /api/v1/owners/me` 已同步到主工作区，并通过后端全测试。

当前主工作区真实后端 API 包括：

```text
POST /api/v1/auth/sms-codes
POST /api/v1/auth/register
POST /api/v1/auth/login
GET /api/v1/owners/me
PUT /api/v1/owners/me
```

## 4. 当前未完成

### 后端关键缺口

- 真实短信供应商；开发环境目前返回模拟验证码。
- Refresh Token、登出撤销、会话/设备管理和账号注销。
- 业主资料 API 与数据库持久化已整理到主工作区提交范围；头像、地址簿、实名认证仍未实现。
- 工匠登录、资料、工种、认证审核、可接单状态、列表和详情 API。
- 预约、派单、接单/拒单、状态历史。
- 报价单、报价版本、明细和业主确认。
- 施工项目、阶段、施工日报、图片、节点验收和整改。
- 聊天、消息、通知和客服协同。
- 文件上传及生产对象存储。
- 收藏、评价、动态、举报、售后与反馈。
- 支付、退款、结算/对账和资金托管。
- 管理后台及管理 API。
- 生产环境安全配置、Docker/Nginx 部署、监控告警与备份方案。

### Flutter 集成缺口

- 当前产品交付与本地端到端验证目标仅为 Android；iOS 目录是 Flutter 工程结构，不作为现阶段完成标准。
- 除业主认证和已验证的业主资料闭环外，大多数页面尚未接入 Spring Boot REST API。
- 许多看似可操作的功能实际只修改本地 `OwnerAppState` / `WorkerAppState` 或 Mock 数据。
- Firestore 桥接需要逐步迁移或明确保留方案，避免与 Spring Boot 形成双数据源。
- 上传、聊天、通知、支付和完整业务状态同步尚未形成端到端闭环。
- 业主端当前允许未登录浏览首页；首页以外底部 Tab 会触发登录，未登录时不显示受保护消息红点。

## 5. 当前优先方向

建议按依赖顺序推进：

1. JWT 入站认证、统一当前用户身份和权限测试已完成。
2. 业主资料 GET/PUT、Android 首次引导闭环、业主端 app shell 路由、设置退出、个人中心基础 UI、报价收藏和报价页保存入口已验证；下一步继续拆分订单/施工过程、地址扩展等 Flutter 未提交改动，再推进工匠账号与资料。
3. 完成工匠账号、资料、审核、列表和详情。
4. 完成预约/派单/接单，再替换现有本地与 Firestore 订单桥接。
5. 完成报价、施工项目、日报、验收和文件上传。
6. 最后建设消息通知、支付、管理后台和生产部署能力。

`docs/superpowers/plans/2026-07-14-owner-profile-backend.md` 是较早的业主资料后端计划；当前以主工作区未提交源码和最新验证结果为准。

## 6. 运行与验证

启动本地后端（需要 MySQL）：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw spring-boot:run \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

Swagger：`http://localhost:8080/swagger-ui/index.html`

启动 Flutter 业主端：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
../flutter/bin/flutter run \
  --flavor owner \
  --dart-define=ZHIDI_APP_FLAVOR=owner \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Flutter 检查：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter analyze
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test
```

后端测试：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

## 7. Codex 接手任务的最小流程

1. 读本文件。
2. 运行 `git status --short`，不要覆盖现有修改。
3. 根据任务只读相关入口、模型、服务和测试。
4. 检查对应计划是否真的已实现；以源码、迁移和测试为准。
5. 修改前说明范围，修改后运行与风险相匹配的验证。
6. 若能力状态发生变化，精简更新本文件的“已完成/未完成”。

## 8. 状态维护规则

- 只记录已由源码、迁移或测试验证的事实。
- 规划功能保留在“未完成”，不能因为存在设计/计划文件就移到“已完成”。
- 更新时修改“最近核对”日期，并删除过时描述，避免只追加内容导致文件膨胀。
- 保持本文件可在几分钟内读完；实现细节用链接指向源码或专题设计文档。
