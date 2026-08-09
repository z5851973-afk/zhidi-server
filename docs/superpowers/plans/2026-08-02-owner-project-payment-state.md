# 业主项目卡片付款状态同步 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让业主端“我的家”顶部项目卡片按服务器最新支付单显示真实付款状态。

**Architecture:** `MyHomePage` 已持有按预约聚合的最新支付单；把当前预约对应的支付单传入 `_ProjectWorkbenchCard`，由卡片统一派生按钮文案、图标和颜色。付款详情页和后端接口保持不变。

**Tech Stack:** Flutter、Dart、Widget Test。

## Global Constraints

- 不新增本地假支付状态。
- 不修改后端或生产数据。
- 保留现有统一付款详情入口。
- 不覆盖工作区既有未提交改动，不自动提交 Git。

---

### Task 1: 顶部项目卡片同步支付状态

**Files:**
- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`
- Test: `zhidi_app/test/my_home_minimal_page_test.dart`
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- Consumes: `Map<String, PaymentOrderModel> _paymentOrdersByBookingId`。
- Produces: `_ProjectWorkbenchCard.paymentOrder` 及真实状态按钮文案。

- [x] **Step 1:** 在 `my_home_minimal_page_test.dart` 新增完成订单已有 `PAID` 支付单时，顶部卡片不显示“去支付”而显示“已支付 · 查看记录”的失败测试。
- [x] **Step 2:** 运行 `flutter test test/my_home_minimal_page_test.dart --plain-name 'completed featured project shows paid payment status'`，确认旧实现因仍显示“去支付”而失败。
- [x] **Step 3:** 将 `_paymentOrdersByBookingId[featuredCandidate.id]` 传入 `_ProjectWorkbenchCard`，按 `isAwaitingWorkerReceipt/isPaid` 派生文案、图标和颜色。
- [x] **Step 4:** 新增 `OWNER_REPORTED_PAID` 状态覆盖并运行 `flutter test test/my_home_minimal_page_test.dart`，确认全部通过。
- [x] **Step 5:** 运行 Flutter 全量测试、`flutter analyze`、构建业主端 APK，并安装到业主模拟器截图复验。
- [x] **Step 6:** 更新 `PROJECT_STATUS.md`，记录本次真实支付状态同步和验证结果。
