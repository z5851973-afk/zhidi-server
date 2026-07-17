# 知底项目交接给马维斯（2026-07-17）

> 本文是继续开发的执行入口。先读本文和根目录 `PROJECT_STATUS.md`，再按任务读取源码。设计或计划文件存在不等于功能已经实现；源码、迁移、测试和生产回读才是事实。

## 1. 一句话现状

业主端、工人端和阿里云后端已经实现并验证了“真实登录 → 工人真实资料/案例 → 业主预约 → 工人接单 → 业主消息反馈”的公网双模拟器闭环。下一阶段“同一需求最多 3 位候选师傅 → 上门确认 → 固定平台价报价 → 业主独享比价和防误触确认”已经完成产品设计与阶段 A 实施计划，但尚未编写代码，生产数据库当前仍为 Flyway V9。

## 2. 仓库与生产环境

- 工作目录：`/Users/liupei/Documents/zhidi`
- 当前分支：`main`
- Flutter：`zhidi_app/`，Android 是当前交付目标
- 后端：`zhidi_server/`，Java 21、Spring Boot 3.5、MySQL、Flyway
- 服务器：阿里云 ECS `47.109.0.191`
- 后端地址：`http://47.109.0.191:8080`
- 部署：systemd 托管 `/opt/zhidi/zhidi-server.jar`，无 Docker、无域名
- 数据库：ECS 原生 MySQL，当前迁移 V9；生产 `ddl-auto=validate`
- 工人案例图片：`/opt/zhidi/uploads/cases`

不要把密码、JWT 或验证码写入仓库；部署所需环境变量以服务器 `/opt/zhidi/.env` 为准。

## 3. 极重要的工作区保护

交接时 `git status --short` 共 178 项：62 个修改、10 个删除、106 个未跟踪文件。这些包含用户此前允许继续整理的大量业务改动，也可能夹杂临时产物。

马维斯接手后必须：

1. 先运行 `git status --short` 并保存结果。
2. 禁止执行 `git reset --hard`、`git checkout -- .`、`git clean`，不得批量恢复删除文件。
3. 不得因为文件未提交就判定为垃圾；逐项确认归属和引用后再处理。
4. 不自动提交、推送或创建 PR，除非用户明确要求。
5. 每完成一个能力，运行对应测试并更新 `PROJECT_STATUS.md`。

## 4. 已上线且已验证的能力

### 4.1 账号与资料

- 业主和工人手机号验证码注册/登录、JWT 认证已接入后端。
- 业主首次资料完善可真实保存并在重启后恢复。
- 工人首次登录会强制完善真实姓名、城市、工种、工龄、日薪和自我介绍；保存为远程优先，失败不会本地假成功。
- 已修复本地历史资料把服务器工人姓名覆盖成 `Bill` 的问题；生产测试工人恢复为“模拟器闭环工人”。

### 4.2 工人目录与案例

- 业主端公开工人列表和详情读取真实 Spring Boot API。
- 工人可新增、编辑、删除包含 1–6 张图片的施工案例。
- 业主端能查看同一工人的真实案例和案例详情。
- 公开案例 JSON 与图片曾因 JWT 过滤器误拦截返回 401，现已修复并有回归测试。
- 生产 Flyway 当前为 V9 `worker cases`。

### 4.3 预约和接单最小闭环

- 业主为真实工人创建预约并落库，初始状态 `PENDING`。
- 工人端读取自己的真实待接订单并可接单/拒单。
- 工人接单后预约变成 `ACCEPTED`，业主端消息页刷新后生成去重的“工人已接单”通知。
- 已在两个 Android 35 模拟器通过公网 API 完成真实 UI 闭环，不是本地 Mock 互相可见。

### 4.4 已验证 APK 与证据

当前最完整的正常 APK：

- `output/apks/app-worker-debug-20260716-worker-cases.apk`
- `output/apks/app-owner-debug-20260716-worker-cases.apk`

主要截图证据：

- `output/evidence/worker-profile-with-cases-20260716.png`
- `output/evidence/owner-worker-detail-name-20260716.png`
- `output/evidence/owner-worker-case-detail-20260716.png`
- `output/evidence/worker-home-restored-cloud-booking-20260716.png`
- `output/evidence/worker-ui-accepted-cleared-20260716.png`
- `output/evidence/owner-message-after-worker-ui-accept-20260716.png`

生产案例闭环最后一次聚焦验证：后端 9 项测试、Flutter 20 项测试、`flutter analyze` 通过；生产健康检查、公开案例 JSON 和 PNG 下载均通过。再次交付前仍要重新执行测试，不能沿用旧结论冒充新验证。

## 5. 已完成设计、尚未开发的目标闭环

完整规则已确认，设计文档是：

- `docs/superpowers/specs/2026-07-17-multi-worker-quote-closure-design.md`

核心业务规则：

1. 一个装修需求最多 3 位活动候选师傅，必须同工种；师傅之间互相不可见。
2. 师傅分别接单、约上门、到场并报价；只有业主能看候选与横向报价对比。
3. 业主或师傅在业主确认已上门前可以取消，必须保留操作者、原因和时间。
4. 顺序为 `ACCEPTED → VISIT_PROPOSED → VISIT_SCHEDULED → ARRIVAL_PENDING → ON_SITE → QUOTE_PENDING → READY_TO_START`。
5. 工人只有在业主确认 `ON_SITE` 后才可报价。
6. 平台价格固定；工人只选项目、规格、数量和备注，金额全部由后端用 `BigDecimal` 计算。
7. 业主可拒绝报价并填写原因，工人创建新版本重报；旧版本永久保留。
8. 业主确认某位师傅后，其他候选和待处理报价变为 `NOT_SELECTED`，历史不删除。
9. 确认报价防误触：二次确认层、关键信息汇总、必须勾选确认、持续按住 2 秒、后端幂等和乐观锁。

## 6. 下一步严格执行顺序

### 阶段 A：装修需求、多候选、上门前取消

详细逐文件、逐测试计划：

- `docs/superpowers/plans/2026-07-17-service-request-candidates.md`

执行顺序：

1. 新增 V10：`service_requests`、预约关联、取消审计字段、生产历史预约无损回填，并修复预约状态约束漏掉 `CANCELLED`。
2. 新增业主装修需求 API和“最多 3 位同工种候选”事务规则；保留旧 `POST /api/v1/bookings` 作为创建首位候选入口。
3. 新增业主/工人各自取消 API，原因必填；工人接口永远不能返回其他候选。
4. Flutter 新增服务需求 API client，网络成功后才能更新 UI。
5. 业主“找师傅”支持加入已有需求或创建新需求；“我的家”按需求显示候选 `n/3`。
6. 工人端接入真实取消和中文错误；做隐私回归测试。
7. 全量验证、生产备份、发布 V10、三工人真实 API 验证、双模拟器截图和新 APK。

当前状态：阶段 A 只有计划文件，没有 V10、`ServiceRequest` 源码或对应 Flutter 页面实现，不得宣称完成。

### 阶段 B：上门时间与到场确认

阶段 A 完成后再做：工人提出时间、业主确认/拒绝时间、工人标记到达、业主确认上门。重点验证 `ON_SITE` 之前可取消，之后普通取消返回 409。

### 阶段 C：固定平台价报价、重报与业主比价

阶段 B 完成后再做：升级现有 V6 报价结构、服务器价格目录、真实报价版本、业主拒绝原因、横向对比、防误触确认，以及事务性结束其他候选。

注意现有报价并未闭环：工人端提交失败可能被吞掉并产生本地假成功；业主报价页仍有 Mock；现有报价明细过粗且按预约查询缺少完整归属校验。阶段 C 必须一起修复，不可只改 UI。

## 7. 开发和验证命令

后端：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

Flutter：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter analyze
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test
```

公网 APK 构建时必须显式指定：

```bash
--dart-define=API_BASE_URL=http://47.109.0.191:8080
```

业主 flavor 还需要：

```bash
--flavor owner --dart-define=ZHIDI_APP_FLAVOR=owner
```

工人 flavor 使用：

```bash
--flavor worker --dart-define=ZHIDI_APP_FLAVOR=worker
```

## 8. 生产发布底线

1. 本地测试和打包全部通过后才允许发布。
2. 发布前备份 jar、systemd 文件、`.env` 和 MySQL；数据库备份必须非空。
3. 上传新 jar、重启 `zhidi.service`，轮询 `/actuator/health` 到 `UP`。
4. 查 `flyway_schema_history` 确认新版本 `success=1`。
5. 用真实业主与至少 3 个完整工人账号跑 API，再用两个模拟器跑 UI。
6. 服务器失败时客户端不得展示成功；不得靠 Mock 或 Firestore 结果冒充 Spring Boot 闭环。
7. 保存新 APK 和截图到 `output/`，最后更新 `PROJECT_STATUS.md`。

## 9. 马维斯开始工作的第一条任务

不要先改报价页。直接从阶段 A 计划的 Task 1 开始，先写 `ServiceRequestPersistenceTest` 让它失败，再实现 V10 和实体；每个任务完成后立即跑计划中列出的聚焦测试。Task 1–6 全部完成且本地验证通过后，才执行 Task 7 的生产部署。

