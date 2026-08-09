# 验收通过自动完成订单 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 师傅发起当前工种验收、业主通过后服务端自动将预约推进为 `COMPLETED`，双端按角色展示正确操作并保持付款闭环可用。

**Architecture:** Spring Boot 的预约状态是唯一事实来源；验收服务在同一事务内推进预约。Flyway 更新状态约束并安全回填历史数据，Flutter 仅映射服务端状态，不自行推断完成。

**Tech Stack:** Java 21、Spring Boot 3.5、JPA、Flyway、MySQL、Flutter、JUnit、Flutter Widget Test。

## Global Constraints

- 不删除或重新初始化生产数据。
- 仅当前工种验收通过才能完成订单。
- 验收只能由当前预约工人发起；业主只能对 `INSPECTING` 节点提交通过或不通过。
- 业主端不得出现“申请验收”或“发起验收”。
- 验收完成后仍允许生成支付订单。
- 保留工作区既有未提交改动，不自动提交 Git。

---

### Task 1: 服务端完成状态与验收推进

**Files:**
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingStatus.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/Booking.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/inspection/InspectionService.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/inspection/InspectionIntegrationTest.java`

**Interfaces:**
- Produces: `Booking.markCompleted()` 和 `BookingStatus.COMPLETED`。

- [x] **Step 1:** 新增验收通过后预约状态为 `COMPLETED` 的失败测试。
- [x] **Step 2:** 运行聚焦测试，确认因状态仍为 `HIRED` 而失败。
- [x] **Step 3:** 最小实现 `COMPLETED` 状态和验收事务内状态推进。
- [x] **Step 4:** 运行聚焦测试并确认通过。

### Task 2: 付款兼容与数据库迁移

**Files:**
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentOrderService.java`
- Create: `zhidi_server/src/main/resources/db/migration/V22__complete_bookings_after_passed_inspection.sql`
- Test: `zhidi_server/src/test/java/com/zhidi/server/payment/PaymentOrderServiceOfflineTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/migration/BookingCompletionMigrationTest.java`

**Interfaces:**
- Consumes: `BookingStatus.COMPLETED`。
- Produces: `HIRED` 与 `COMPLETED` 均可创建付款订单；历史订单安全回填。

- [x] **Step 1:** 新增 `COMPLETED` 可创建付款订单和迁移回填失败测试。
- [x] **Step 2:** 运行测试，确认旧实现拒绝 `COMPLETED` 且缺少 V22。
- [x] **Step 3:** 修改付款状态校验并添加 V22 状态约束/回填。
- [x] **Step 4:** 运行聚焦与后端全量测试。

### Task 3: 工人端自动归档

**Files:**
- Modify: `zhidi_app/lib/app/worker_app_state.dart`
- Test: `zhidi_app/test/worker_session_state_test.dart`
- Test: `zhidi_app/test/worker_bottom_navigation_test.dart`

**Interfaces:**
- Consumes: 服务端预约状态字符串 `COMPLETED`。
- Produces: `WorkerOrderStatus.completed`，只进入 `completedOrders`。

- [x] **Step 1:** 新增远端 `COMPLETED` 映射和页面归档失败测试。
- [x] **Step 2:** 运行测试，确认订单未进入已完成列表。
- [x] **Step 3:** 添加最小状态映射。
- [x] **Step 4:** 运行 Flutter 聚焦测试、全量测试和静态检查。

### Task 4: 部署与真实复验

**Files:**
- Modify: `PROJECT_STATUS.md`
- Create: `zhidi_app/output/apks/zhidi-worker-debug-20260802-inspection-completed.apk`

**Interfaces:**
- Consumes: 已验证后端 JAR、V22 和工人端 APK。
- Produces: 生产健康服务与模拟器截图证据。

- [x] **Step 1:** 备份生产 JAR、环境文件和数据库。
- [x] **Step 2:** 部署后端并验证 Flyway V22、健康检查和真实订单状态。
- [x] **Step 3:** 构建安装工人端 APK，刷新后确认订单位于“已完成”。
- [x] **Step 4:** 更新 `PROJECT_STATUS.md` 并执行最终差异、测试、构建和健康校验。

### Task 5: 修正业主端验收角色与五种状态文案

**Files:**
- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`
- Modify: `zhidi_app/lib/pages/home/owner_inspection_page.dart`
- Test: `zhidi_app/test/my_home_minimal_page_test.dart`
- Test: `zhidi_app/test/owner_inspection_page_remote_test.dart`
- Test: `zhidi_app/test/owner_inspection_state_test.dart`

**Interfaces:**
- Consumes: 服务端节点状态 `PENDING`、`INSPECTING`、`FAILED`、`PASSED`。
- Produces: 首页固定入口“验收进度”和业主验收页状态映射；只有 `INSPECTING` 产生 `onInspect` 操作。

- [x] **Step 1: 写首页错误文案的失败测试**

在 `my_home_minimal_page_test.dart` 构造 `HIRED` 候选，断言：

```dart
expect(find.text('施工中'), findsWidgets);
expect(find.text('申请验收'), findsNothing);
expect(find.text('发起验收'), findsNothing);
expect(find.text('验收进度'), findsOneWidget);
```

点击“验收进度”后断言进入 `OwnerInspectionPage`，而不是调用任何申请验收 API。

- [x] **Step 2: 运行首页测试确认失败**

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/my_home_minimal_page_test.dart --plain-name 'hired project lets worker initiate inspection only'`

Expected: FAIL，当前 `HIRED` 主按钮文字为“申请验收”。

- [x] **Step 3: 最小修改首页动作语义**

将 `_ProjectWorkbenchCard._primaryLabel` 的 `HIRED` 分支改成“验收进度”，`_primaryAction` 仍然只打开 `OwnerInspectionPage`；施工验收卡的 trailing 从“进入验收 >”改为“查看进度 >”。不得在业主端调用 `InspectionApi.requestInspection` 或 `createNodes`。

```dart
'HIRED' => '验收进度',
```

- [x] **Step 4: 写业主验收页五状态失败测试**

使用可注入的 `InspectionApi` 分别返回：空列表、`PENDING`、`INSPECTING`、`FAILED`、`PASSED`，断言：

```dart
expect(find.text('师傅尚未发起验收'), findsOneWidget); // empty
expect(find.text('等待师傅发起验收'), findsOneWidget); // PENDING
expect(find.text('待您验收'), findsOneWidget); // INSPECTING
expect(find.text('去验收'), findsOneWidget); // INSPECTING only
expect(find.text('等待师傅整改并重新发起'), findsOneWidget); // FAILED
expect(find.text('验收已通过'), findsOneWidget); // PASSED
expect(find.text('申请验收'), findsNothing);
```

- [x] **Step 5: 实现业主节点状态展示**

`_OwnerNodeCard` 将标签映射为：

```dart
String get _label => switch (node.status) {
  'PENDING' => '等待师傅发起验收',
  'INSPECTING' => '待您验收',
  'FAILED' => '等待师傅整改并重新发起',
  'PASSED' => '验收已通过',
  _ => node.status,
};
```

空列表文案改为“师傅尚未发起验收”；仅 `INSPECTING` 显示“去验收”；`FAILED` 和 `PASSED` 只显示“查看验收记录”。为长文案使用 `Flexible`/`Wrap`，保证 320px 宽度不溢出。

- [x] **Step 6: 运行业主端聚焦测试**

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/my_home_minimal_page_test.dart test/owner_inspection_page_remote_test.dart test/owner_inspection_state_test.dart`

Expected: PASS，业主端测试树中没有可点击的“申请验收/发起验收”。

### Task 6: 工人发起能力与服务端角色回归

**Files:**
- Modify: `zhidi_app/test/worker_inspection_page_test.dart`
- Verify: `zhidi_app/lib/pages/worker/inspection_page.dart`
- Verify: `zhidi_server/src/main/java/com/zhidi/server/inspection/InspectionController.java`
- Verify: `zhidi_server/src/main/java/com/zhidi/server/inspection/InspectionService.java`
- Modify: `zhidi_server/src/test/java/com/zhidi/server/inspection/InspectionIntegrationTest.java`
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- Consumes: `InspectionApi.requestInspection`、`InspectionService.requestInspection(workerUserId, nodeId)`、`InspectionService.inspect(ownerUserId, nodeId, request)`。
- Produces: 工人 `PENDING/FAILED` 可申请，`INSPECTING/PASSED` 不可重复申请；服务端保持角色强制。

- [x] **Step 1: 补齐工人四状态组件测试**

断言 `PENDING` 显示“申请验收”，`FAILED` 显示“申请重新验收”，`INSPECTING` 显示“等待业主验收”且没有申请按钮，`PASSED` 显示“已通过”且没有申请按钮。点击允许的按钮后，fake API 的 `requestInspectionNodeId` 必须等于当前节点 ID。

- [x] **Step 2: 运行工人组件测试**

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/worker_inspection_page_test.dart`

Expected: PASS；若任何状态失败，只修改 `inspection_page.dart` 对应状态分支，不改订单或付款逻辑。

- [x] **Step 3: 补齐服务端角色断言**

在 `InspectionIntegrationTest` 保留并明确断言：业主调用 `requestInspection` 得到 `403/NOT_WORKER`；非本单工人调用得到 `403/NOT_WORKER`；工人调用 `inspect` 得到 `403/NOT_OWNER`；本单工人发起后本单业主可以提交结果。

- [x] **Step 4: 运行后端验收测试**

Run: `cd zhidi_server && MAVEN_USER_HOME=../.m2 ./mvnw -Dtest=InspectionIntegrationTest test -Dmaven.repo.local=../.m2/repository -s ../.m2/settings.xml`

Expected: `BUILD SUCCESS`，0 failures，0 errors；如果现有服务已满足权限，不修改生产服务代码。

- [x] **Step 5: 运行 Flutter 静态检查和相关回归**

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter analyze`

Expected: `No issues found!`

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/my_home_minimal_page_test.dart test/owner_inspection_page_remote_test.dart test/owner_inspection_state_test.dart test/worker_inspection_page_test.dart test/worker_order_detail_refresh_test.dart`

Expected: All tests passed。

- [x] **Step 6: 更新状态并构建业主端 APK**

在 `PROJECT_STATUS.md` 只记录已通过测试的角色边界与文案修复；构建公网配置业主 APK并安装到 `Zhidi_API35`，施工中首页不得再出现“申请验收”。工人端已有发起按钮保持不变，用双模拟器复验“工人发起 → 业主待验收”。

---

## 追加任务自查

- Spec coverage: Task 5 覆盖业主空节点及四种节点状态；Task 6 覆盖工人四状态、服务端双方角色和双模拟器复验。
- Placeholder scan: 追加任务没有 `TBD`、`TODO`、模糊错误处理或未定义接口。
- Type consistency: 前后端继续使用既有 `PENDING/INSPECTING/FAILED/PASSED`，不新增数据库状态或 API 字段。
