# 工人收入与已完工工地 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为工人端增加清晰的真实收入入口和可查看的只读完工档案。

**Architecture:** 复用 `WorkerAppState` 已缓存的真实结算/质保金及现有订单详情、日报、验收、结算页面。完成订单卡片只负责导航与本单金额摘要，详情页按完成状态切换为只读档案。

**Tech Stack:** Flutter、Dart、Widget Test。

## Global Constraints

- 不新增 Mock 或本地假收入。
- 不修改后端或生产数据。
- 完工档案禁止再次提交日报、创建验收节点或发起验收。
- 保留工作区既有未提交改动，不自动提交 Git。

---

### Task 1: 收入入口与完工卡片

**Files:**
- Modify: `zhidi_app/lib/app/worker_app_state.dart`
- Modify: `zhidi_app/lib/pages/worker/worker_home_page.dart`
- Test: `zhidi_app/test/worker_bottom_navigation_test.dart`

**Interfaces:**
- Produces: `remoteSettleableAmountForBooking(String bookingId)`、`remoteWarrantyRetentionAmountForBooking(String bookingId)`。
- Consumes: `WorkerSettlementPage`、`OrderDetailPage(orderId: ...)`。

- [ ] **Step 1:** 新增收入栏显示“收入明细”提示、完成卡显示本单真实金额且可进入详情的失败测试。
- [ ] **Step 2:** 运行 `flutter test test/worker_bottom_navigation_test.dart`，确认旧实现因缺少入口和点击导航而失败。
- [ ] **Step 3:** 添加按预约聚合结算/质保金 getter，并升级收入栏和完成卡片。
- [ ] **Step 4:** 重跑聚焦测试并确认通过。

### Task 2: 只读完工档案

**Files:**
- Modify: `zhidi_app/lib/pages/worker/order_detail_page.dart`
- Modify: `zhidi_app/lib/pages/worker/daily_report_page.dart`
- Modify: `zhidi_app/lib/pages/worker/inspection_page.dart`
- Test: `zhidi_app/test/worker_order_detail_refresh_test.dart`
- Test: `zhidi_app/test/worker_daily_report_upload_test.dart`
- Test: `zhidi_app/test/worker_inspection_page_test.dart`

**Interfaces:**
- Produces: `DailyReportPage(readOnly: true)`、`InspectionPage(readOnly: true)`。
- Consumes: 完成状态 `WorkerOrderStatus.completed`。

- [ ] **Step 1:** 新增完成详情显示“完工档案/施工记录/验收记录/收入与质保金”和两个子页面只读的失败测试。
- [ ] **Step 2:** 运行三组聚焦测试，确认旧页面缺少只读能力而失败。
- [ ] **Step 3:** 为日报、验收增加只读参数，并在完成订单详情增加档案入口和收入操作。
- [ ] **Step 4:** 重跑三组聚焦测试并确认通过。

### Task 3: 构建与模拟器复验

**Files:**
- Modify: `PROJECT_STATUS.md`
- Create: `zhidi_app/output/apks/zhidi-worker-debug-20260802-completed-archive.apk`

- [ ] **Step 1:** 运行 `flutter analyze` 与 Flutter 全量测试。
- [ ] **Step 2:** 构建公网工人端 APK，覆盖安装到 `emulator-5556`。
- [ ] **Step 3:** 可视化验证收入入口、已完成卡片和完工档案。
- [ ] **Step 4:** 更新 `PROJECT_STATUS.md` 并执行最终差异与产物校验。

### Task 4: 完工后关闭直接联系

**Files:**
- Modify: `zhidi_app/lib/pages/worker/order_detail_page.dart`
- Test: `zhidi_app/test/worker_order_detail_refresh_test.dart`
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- Produces: 完成状态下脱敏的业主手机号和唯一通栏“查看收入明细”操作。
- Consumes: `WorkerOrderStatus.completed`、订单业主手机号。

- [ ] **Step 1:** 在完成订单详情测试中断言完整手机号和“联系业主”均不可见，脱敏号码及“查看收入明细”可见。
- [ ] **Step 2:** 运行 `flutter test test/worker_order_detail_refresh_test.dart --plain-name "completed order detail is a read-only completed archive"`，确认旧实现因仍显示完整手机号和联系入口而失败。
- [ ] **Step 3:** 完成状态下对手机号保留前三后四位并以四个星号遮挡中间数字，删除联系按钮，把收入按钮改为通栏；非完成状态保持原行为。
- [ ] **Step 4:** 重跑聚焦测试、静态检查和 Flutter 全量测试，构建公网工人端 APK并覆盖安装到 `emulator-5556`，可视化确认完工档案无联系入口。
