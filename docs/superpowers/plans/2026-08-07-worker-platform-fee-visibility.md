# 工人端隐藏平台服务费 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在所有新旧资金模型的工人端入口隐藏业主支付给平台的服务费，只保留工程款、结算和工人履约质保信息。

**Architecture:** 后端继续保留完整支付数据，业主端和管理端继续使用平台服务费字段；Flutter 工人端在展示层和本地付款通知层执行统一的角色可见性规则。现有 `PaymentOrderModel` 与 API 契约不变，只收紧工人可见文案。

**Tech Stack:** Flutter、Dart、Widget Test。

## Global Constraints

- 工人端不得展示“平台服务费”、服务费比例或服务费金额。
- 新订单工人端只展示本单应收工程款、到账状态和独立履约质保账户。
- 历史订单仍展示报价总价、可结算金额和历史质保金，但隐藏业主的平台服务费。
- 不修改业主端、管理端、后端金额字段、状态机、数据库或支付规则。
- 不提交、不推送、不部署后端；只重建 worker debug APK。

---

### Task 1: 用回归测试锁定工人端资金可见性

**Files:**
- Modify: `zhidi_app/test/worker_bottom_navigation_test.dart`
- Modify: `zhidi_app/test/worker_session_state_test.dart`

**Interfaces:**
- Consumes: `WorkerSettlementPage`、`WorkerAppState.fetchRemotePayments()`。
- Produces: 新旧支付页面及付款消息不得泄露平台服务费的回归约束。

- [x] **Step 1: 修改历史订单页面断言**

在 `payment notice opens the matching receipt details` 中保留以下断言：

```dart
expect(find.text('报价清单总价'), findsOneWidget);
expect(find.text('可结算 90%'), findsOneWidget);
expect(find.text('质保金冻结 10%'), findsOneWidget);
expect(find.textContaining('平台服务费'), findsNothing);
```

不再用平台费 `¥580.00` 参与组件数量断言；只验证报价、可结算金额、历史质保金和报价明细入口仍存在。

- [x] **Step 2: 修改新订单页面断言**

在 `split payment shows full construction receipt and independent warranty account` 中改为：

```dart
expect(find.text('本单应收 ¥10840.00'), findsOneWidget);
expect(find.textContaining('平台服务费'), findsNothing);
expect(find.text('履约质保金账户'), findsOneWidget);
expect(find.text('本单待补充'), findsOneWidget);
```

- [x] **Step 3: 增加付款通知隐私断言**

在 `split construction payment creates one full receipt message` 中增加：

```dart
expect(messages.single.content, contains('¥10840'));
expect(messages.single.content, isNot(contains('平台服务费')));
```

- [x] **Step 4: 运行测试并确认 RED**

Run:

```bash
cd zhidi_app
HOME=$PWD/.codex-flutter-home /Users/liupei/Documents/zhidi/flutter/bin/flutter test \
  test/worker_bottom_navigation_test.dart \
  test/worker_session_state_test.dart
```

Expected: FAIL，现有结算页和新订单通知仍包含“平台服务费”。

---

### Task 2: 清除工人端所有平台服务费展示

**Files:**
- Modify: `zhidi_app/lib/pages/worker/worker_settlement_page.dart`
- Modify: `zhidi_app/lib/app/worker_app_state.dart`

**Interfaces:**
- Consumes: `PaymentOrderModel.isSplitOfflineV2`、`quoteAmount`、`workerSettlement`、`warrantyRetention`。
- Produces: 只包含工人相关资金信息的结算页、确认弹窗、成功提示和付款通知。

- [x] **Step 1: 修改新订单确认弹窗和反馈**

新订单确认弹窗文案固定为：

```dart
'请先核对报价明细和实际到账。本单工程款应全额收到 '
'¥${order.quoteAmount.toStringAsFixed(2)}，确认后将记录工程款到账状态。'
```

确认成功提示固定为：

```dart
'已确认工程款到账，付款状态核验中'
```

- [x] **Step 2: 修改新订单结算卡**

说明文案只保留：

```dart
'业主已报告通过${_channelLabel(order.constructionPaymentChannel)}支付工程款，请核对实际到账。'
```

费用明细只显示 `报价清单总价` 与 `本单工程款应收`，删除平台服务费行。

- [x] **Step 3: 修改历史订单结算卡**

历史订单继续显示：

```dart
_detailRow('报价清单总价', '¥${quoteTotal.toStringAsFixed(2)}')
_detailRow('可结算 90%', '¥${order.workerSettlement.toStringAsFixed(2)}')
_detailRow('质保金冻结 10%', '¥${order.warrantyRetention.toStringAsFixed(2)}')
```

删除 `平台服务费（10%）` 行，不改变任何金额计算。

- [x] **Step 4: 修改工人付款通知**

新订单通知正文改为：

```dart
'本单工程款 ¥${order.quoteAmount.toStringAsFixed(0)}，请核对实际到账后确认。'
```

- [x] **Step 5: 运行聚焦测试并确认 GREEN**

Run:

```bash
cd zhidi_app
HOME=$PWD/.codex-flutter-home /Users/liupei/Documents/zhidi/flutter/bin/flutter test \
  test/worker_bottom_navigation_test.dart \
  test/worker_session_state_test.dart \
  test/worker_order_detail_refresh_test.dart
```

Expected: PASS。

---

### Task 3: 全量验证、文档同步和工人 APK 构建

**Files:**
- Modify: `PROJECT_STATUS.md`
- Modify: `docs/superpowers/plans/2026-08-07-worker-platform-fee-visibility.md`

**Interfaces:**
- Produces: 可复核的测试证据和新版 worker debug APK；不部署后端。

- [x] **Step 1: 检查工人端源码无服务费文案**

Run:

```bash
rg -n "平台服务费" \
  zhidi_app/lib/pages/worker \
  zhidi_app/lib/app/worker_app_state.dart
```

Expected: 无匹配结果。

- [x] **Step 2: 运行 Flutter 静态检查和全量测试**

Run:

```bash
cd zhidi_app
HOME=$PWD/.codex-flutter-home /Users/liupei/Documents/zhidi/flutter/bin/flutter analyze
HOME=$PWD/.codex-flutter-home /Users/liupei/Documents/zhidi/flutter/bin/flutter test --reporter compact
```

Expected: `flutter analyze` 无问题；全量测试通过。

- [x] **Step 3: 构建工人 APK**

Run:

```bash
cd zhidi_app
HOME=$PWD/.codex-flutter-home /Users/liupei/Documents/zhidi/flutter/bin/flutter build apk \
  --debug \
  --flavor worker \
  --dart-define=API_BASE_URL=http://47.109.0.191:8080
```

Expected: `build/app/outputs/flutter-apk/app-worker-debug.apk` 构建成功。

- [x] **Step 4: 更新项目状态与计划勾选**

在 `PROJECT_STATUS.md` 记录工人端已隐藏平台服务费、验证结果、APK 路径以及未部署事实；将本计划已完成步骤改为 `[x]`。

- [x] **Step 5: 最终范围检查**

Run:

```bash
git diff --check
git status --short
```

Expected: 无空白错误；保留工作区既有未提交改动，不提交、不推送、不部署。
