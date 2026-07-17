# 知底项目状态

> Codex 快速上下文。最近核对：2026-07-17（源码基线整理 + 全量验证）。开始任务时先读本文件；只有任务涉及的部分才继续读取源码或 `docs/superpowers/` 下的设计与计划。

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

- 当前业务交付只保留 Android 为完成标准；2026-07-17 已按用户要求删除未开发且未被 Git 跟踪的 `zhidi_app/ios/` Flutter 脚手架目录。Web、macOS、Windows 和 Linux 工程结构仍在工作区，但不作为当前交付目标。
- Android 通过 `--flavor owner` 启动业主端；未指定时默认启动工匠端。
- 两端共用设计主题和中文本地化。
- 业主端已有启动页、手机号登录、首次资料引导、首页、工匠列表/详情、预约与订单、透明价格、装修项目、消息、聊天、个人中心、地址、收藏、设置、售后等页面或交互原型。
- 工匠端已有登录、首页、订单详情、报价、施工日报、验收、收入、资料等页面或交互原型。
- 业主端手机号验证码登录已接入 Spring Boot；JWT 使用平台安全存储保存。
- 业主资料 GET/PUT 接入和首次引导保存已在 Android 模拟器完成端到端验证：登录后读取服务端默认资料，首次引导提交资料落库，强停重启后不再回到首次引导。后端 API、Flutter API client、会话/资料状态同步、登录页、首次引导页、业主端 app shell 路由、设置退出、个人中心基础 UI token 化、报价收藏、报价页保存入口、工人详情报价入口、完整工种工价数据映射、透明工价列表页、施工中师傅/阶段完成状态底座、“我的家”最小施工进度页、工人详情预约写入施工进度链路、工人列表进入详情预约链路、本地验收申请/通过/驳回闭环、验收通过自动归档展示和材料估算确认采购已整理提交；剩余地址扩展等能力仍在主工作区未提交改动中。
- 业主端工匠列表/详情已接入 Spring Boot 公开工匠 API：列表优先读取 `GET /api/v1/workers`，按当前工种筛选，后端失败或无匹配数据时回退本地 Mock；详情页可展示服务端返回的姓名、工种、经验、城市、日薪和简介。该链路已通过 Flutter 聚焦测试，并已在 Android 模拟器使用本地 Spring Boot + MySQL 真实工匠资料完成联调。
- 业主端真实工匠详情页“立即预约师傅”已接入 Spring Boot 预约 API：服务端工匠会先调用 `POST /api/v1/bookings`，成功后再同步本地“我的家/我的预约”状态；本地 Mock 工匠仍保留原本本地预约路径。该链路已通过 Flutter 聚焦测试，并已在 Android 模拟器使用本地 Spring Boot + MySQL 真实落库验证，预约初始状态为 `PENDING`，成功页文案已调整为“预约已提交/待确认”。
- 生产预约闭环已通过公网 API 和 Android Studio Pixel 9 模拟器验证：测试工人发布完整资料后出现在业主端工人目录；测试业主创建预约后，工人端可登录真实账号并看到云端真实预约卡片；工人端在模拟器 UI 点击“立即接单”后，待接单列表清空，业主预约列表通过 API 回读为 `ACCEPTED`。业主端和工人端 debug APK 已使用 `API_BASE_URL=http://47.109.0.191:8080` 构建成功。模拟器验证使用订单 `1090709c-5c6d-442c-8183-e33c82821787`，工人 `19817313015`，业主 `19917334870`。
- 业主端消息反馈已接入真实预约状态同步：`fetchRemoteBookings()` 拉到远程 `ACCEPTED` 预约时，会生成去重的“工人已接单”预约通知；切换到底部“消息”Tab 时会主动刷新远程预约，避免只显示旧 Mock/本地通知。该逻辑已通过 Flutter 聚焦测试和 `flutter analyze`；能力已包含在当前 `output/apks/app-owner-debug-20260716-worker-cases.apk`。本机已手动安装 Android 35 ARM64 稳定系统镜像并创建 `Zhidi_API35` AVD，业主端登录测试账号后已在消息页看到 2 条来自远程已接单预约的“工人已接单”通知，截图证据为 `output/evidence/owner-message-feedback-20260716.png`。
- 工人端登录错误提示已补齐中文映射：`SMS_CODE_INVALID`、`SMS_CODE_EXPIRED`、`SMS_CODE_ATTEMPTS_EXCEEDED`、网络错误和工匠权限错误不再直接透出后端英文 message；已通过 `test/worker_login_page_test.dart` 覆盖。工人端登录资料同步也已修正：登录成功后读取 `GET /api/v1/workers/me` 并用服务器资料覆盖本地缓存，且不再把本地旧资料（例如历史残留的 Bill）自动上传覆盖服务器。生产测试工人 `19817313015` 曾被旧流程污染为 Bill，已通过 `PUT /api/v1/workers/me` 修回“模拟器闭环工人”；能力已包含在当前 `output/apks/app-worker-debug-20260716-worker-cases.apk`。
- 工人首次资料完善已接入真实后端：服务器资料缺少真实姓名、服务城市、工种、工龄、日薪或自我介绍时，工人端强制进入“完善工人资料”，手机号只读；保存会先 `PUT /api/v1/workers/me`，再 GET 回读成功结果，本地状态不会在服务器失败时假保存。该链路通过 8 个 Flutter 聚焦测试、`flutter analyze`、后端纯单元测试与生产 API 回读；ECS 已于 `20260716213046` 备份并发布，健康检查为 `UP`。该能力已包含在当前 `output/apks/app-worker-debug-20260716-worker-cases.apk`，模拟器页面证据为 `output/evidence/worker-profile-onboarding-real-app-20260716.png`。
- Android 双模拟器真实 UI 闭环复验完成：工人端 `Zhidi_Worker_API35` 恢复真实登录态后从 ECS REST API 看到云端预约“两个模拟器联通测试 3 栋 303”，在工人端 UI 点击“立即接单”后待接单列表清空；业主端 `Zhidi_API35` 切到消息页后刷新出对应“工人已接单”反馈。证据截图为 `output/evidence/worker-home-restored-cloud-booking-20260716.png`、`output/evidence/worker-ui-accepted-cleared-20260716.png`、`output/evidence/owner-message-after-worker-ui-accept-20260716.png`。
- 工匠施工案例已形成真实 ECS/MySQL 双端闭环：工人端个人资料可新增、编辑、删除 1–6 张图的施工案例，图片通过工人 JWT 上传到 `/opt/zhidi/uploads/cases`；业主端真实工人详情只读取公开案例 API，并提供加载、空、失败重试状态，不再为远程工人伪造 Picsum 案例。生产测试工人“模拟器闭环工人”已上传并创建“水电改造施工案例”，工人端案例管理和业主端详情均显示同一条记录。聚焦验证为后端 9 项、Flutter 20 项测试及 `flutter analyze` 无问题；正常 APK 为 `output/apks/app-worker-debug-20260716-worker-cases.apk`、`output/apks/app-owner-debug-20260716-worker-cases.apk`，证据为 `output/evidence/worker-profile-with-cases-20260716.png`、`output/evidence/owner-worker-detail-name-20260716.png`、`output/evidence/owner-worker-case-detail-20260716.png`。
- 大量业务状态已能在本地持久化，并带有 Mock 示例数据。
- 部分业主/工匠订单和工匠资料使用 Firestore 桥接；这不是完整正式后端。
- 已存在 Flutter 单元/Widget 测试，覆盖认证、启动、引导、退出以及若干重点页面。

### Spring Boot 后端

- 基础框架：Java 21、Spring Boot 3.5、Maven、Spring MVC、Spring Data JPA、Spring Security、Flyway、MySQL、OpenAPI、Actuator。
- 已有统一 API 响应、trace ID、全局异常处理和基础审计表。
- 已完成用户、角色和短信验证码数据模型及 Flyway 迁移。
- 已完成业主/工匠验证码请求、注册、统一登录和 30 天 JWT 签发。
- 已完成 JWT 入站认证：受保护 API 回查数据库用户状态与角色，并统一返回 JSON 401/403 错误。
- 已实现验证码哈希保存、5 分钟有效期、错误次数限制，以及手机号/IP 发送频率限制。
- 已有服务、控制器、JWT、仓库和 MySQL Testcontainers 测试。
- 业主资料 MySQL 持久化、`GET /api/v1/owners/me`、`PUT /api/v1/owners/me` 已同步到主工作区，并通过后端全测试。
- 工匠资料 MySQL 持久化、`GET /api/v1/workers/me`、`PUT /api/v1/workers/me` 已同步到主工作区，并通过对应后端测试。
- 工匠公开列表和详情 `GET /api/v1/workers`、`GET /api/v1/workers/{userId}` 已同步到主工作区，仅展示资料完整工匠。
- 预约最小后端闭环已同步到主工作区：业主可为资料完整工匠创建预约，业主/工匠可分别查看自己的预约，工匠可接单或拒单；已通过后端全量测试。
- 生产 ECS 的 systemd `zhidi.service` 健康检查为 `UP`，Hibernate 生产配置为 `ddl-auto=validate`。此前 V8 已补齐预约业主快照字段、删除生产库遗留的 `worker_profiles(name, primary_trade)` 唯一索引，并验证两个同名同工种工人资料可同时保存；对应备份位于 `/opt/zhidi/backups/20260716151927/` 与 `/opt/zhidi/backups/20260716153533/`。
- 工匠案例表、案例 CRUD、公开读取和受保护图片上传已发布到生产；Flyway 当前为 V9 `worker cases`，生产文件目录为 `/opt/zhidi/uploads/cases`。公开案例路径的 JWT 过滤器遗漏曾在真实联调中表现为 401，已用回归测试修复并重新发布；发布备份位于 `/opt/zhidi/backups/20260716223307/` 与 `/opt/zhidi/backups/20260716225101/`，健康检查、公开案例 JSON 和 PNG 下载均已复验。

当前主工作区真实后端 API 包括：

```text
POST /api/v1/auth/sms-codes
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/workers/register
POST /api/v1/auth/workers/login
GET /api/v1/owners/me
PUT /api/v1/owners/me
GET /api/v1/workers
GET /api/v1/workers/{userId}
GET /api/v1/workers/me
PUT /api/v1/workers/me
GET /api/v1/workers/{userId}/cases
GET /api/v1/workers/me/cases
POST /api/v1/workers/me/cases
PUT /api/v1/workers/me/cases/{caseId}
DELETE /api/v1/workers/me/cases/{caseId}
POST /api/v1/workers/me/case-images
POST /api/v1/bookings
GET /api/v1/owners/me/bookings
GET /api/v1/workers/me/bookings
POST /api/v1/workers/me/bookings/{id}/accept
POST /api/v1/workers/me/bookings/{id}/reject
POST /api/v1/bookings/{id}/cancel
POST /api/v1/bookings/{bookingId}/reports
GET /api/v1/bookings/{bookingId}/reports
GET /api/v1/workers/me/reports
```

## 4. 当前未完成

### 后端关键缺口

- 真实短信供应商；开发环境目前返回模拟验证码。
- Refresh Token、登出撤销、会话/设备管理和账号注销。
- 业主资料 API 与数据库持久化已整理到主工作区提交范围；头像、地址簿、实名认证仍未实现。
- 工匠认证审核、可接单状态和更完整的筛选/排序；当前已完成工匠短信注册/登录、当前登录工匠资料 GET/PUT、公开工匠列表和详情。
- 预约创建、业主/工匠预约列表、工匠接单/拒单已有最小后端 API；派单、取消、改约、状态历史和更完整订单流转仍未实现。
- 报价单、报价版本、明细和业主确认。
- 施工项目、阶段、施工日报（后端 5 文件 + 前端 API client + worker/owner 状态对接已完成，Android 联调待验证）、图片、节点验收和整改。
- 聊天、消息、通知和客服协同。
- 通用文件上传及生产对象存储；工匠案例图片现阶段已使用 ECS 本地持久目录完成上传与公开读取。
- 收藏、评价、动态、举报、售后与反馈。
- 支付、退款、结算/对账和资金托管。
- 管理后台及管理 API。
- 生产环境安全配置、Docker/Nginx 部署、监控告警与备份方案。

### Flutter 集成缺口

- 当前产品交付与本地端到端验证目标仅为 Android；iOS 脚手架目录已删除，如未来恢复 iOS，需要重新生成平台工程并单独完成签名、权限和真机适配。
- 除业主认证、已验证的业主资料闭环、业主端工匠列表/详情公开资料读取、业主端服务端工匠预约创建外，大多数页面尚未接入 Spring Boot REST API。
- 生产公网 API 的业主预约、工人查看真实业主信息、工人接单、业主回读状态已验证；Android Studio 模拟器已可视化验证工人端登录、真实预约卡片展示和 UI 点击“立即接单”闭环。当前证据包括 APK 构建、工人端模拟器截图、UI 点击后工人端待接单列表清空，以及业主 API 回读 `ACCEPTED`。
- 业主端消息页已补真实接单反馈生成与 Tab 切换刷新，并已在 `Zhidi_API35` Android 模拟器上完成截图复验：登录业主测试账号后，消息页显示 2 条真实“工人已接单”通知。
- 许多看似可操作的功能实际只修改本地 `OwnerAppState` / `WorkerAppState` 或 Mock 数据。
- Firestore 桥接需要逐步迁移或明确保留方案，避免与 Spring Boot 形成双数据源。
- 上传、聊天、通知、支付和完整业务状态同步尚未形成端到端闭环。
- 业主端当前允许未登录浏览首页；首页以外底部 Tab 会触发登录，未登录时不显示受保护消息红点。

## 5. 当前优先方向

建议按依赖顺序推进：

1. JWT 入站认证、统一当前用户身份和权限测试已完成。
2. 业主资料 GET/PUT、Android 首次引导闭环、业主端 app shell 路由、设置退出、个人中心基础 UI、报价收藏、报价页保存入口、工人详情报价入口、完整工种工价数据映射、透明工价列表页、施工中师傅/阶段完成状态底座、“我的家”最小施工进度页、工人详情预约写入施工进度链路、工人列表进入详情预约链路、本地验收申请/通过/驳回闭环、验收通过自动归档展示和材料估算确认采购已验证；下一步继续拆分地址扩展等 Flutter 未提交改动，再推进工匠账号与资料。
3. 工匠短信注册/登录、当前资料 GET/PUT、公开列表和详情已完成；业主端工匠列表/详情已在 Android 模拟器联调真实后端工匠数据。
4. 生产公网 API 已验证工匠真实预约列表与接单闭环；下一步做 Android 双端可视化联调、强停重启会话恢复实测，并推进派单、取消/改约、状态历史，逐步替换现有本地与 Firestore 订单桥接。
5. 工匠施工案例和案例图片上传已完成；继续完成报价、施工项目、日报、验收和通用文件上传。
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

## 9. 源码基线（2026-07-17 整理）

工作区已按 `docs/superpowers/specs/2026-07-17-source-baseline-cleanup-design.md` 整理成可恢复、可验证的源码基线：

- 源码归档：`output/baselines/20260717_154949/source-baseline.tar.gz`（135 MB，SHA-256 已记录）
- 基线 APK：`output/apks/app-owner-debug-baseline.apk`、`output/apks/app-worker-debug-baseline.apk`（均指向 `http://47.109.0.191:8080`）
- 全量验证：`git diff --check` PASS、Flutter analyze 0 问题、Flutter 133/133 测试通过、双端 APK 构建成功；后端 106 个测试中 73 通过、1 失败、33 上下文加载错误（需要 Docker 才会通过，非业务代码缺陷）
- 详细报告：`docs/superpowers/reports/2026-07-17-baseline-cleanup-report.md`
- 已删除文件审核：`output/baselines/20260717_154949/deleted-file-audit.md`（7 项合理删除 + 3 项待用户决定）

未执行任何 git commit、push，未修改生产数据库或服务器部署。基线整理不改变任何业务能力。
