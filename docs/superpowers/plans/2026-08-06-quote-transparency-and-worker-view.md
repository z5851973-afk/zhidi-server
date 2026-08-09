# 双端报价透明展示 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 业主在选人前看到完整报价和10%平台服务费，师傅在订单详情查看服务器真实已提交报价。

**Architecture:** 业主报价卡继续使用 `RemoteQuote` 的真实项目数据，按人工/材料分组后增加展示用服务费与应付合计；支付订单仍以服务器金额为准。工人订单详情的报价卡从预约报价接口加载最新一张真实报价，并复用共享 `QuoteDetailPage` 展示，不复制报价详情 UI。

**Tech Stack:** Flutter、Dart、flutter_test、现有 REST API

## Global Constraints

- 业主端必须展示人工和材料的项目名称、单价、数量、单位和小计。
- 平台服务费等于工人报价总额的 10%，由业主额外支付，不从工人报价中扣除。
- 业主应付合计等于工人报价总额加平台服务费。
- 多人比价仍按工人报价总额排序。
- 师傅端不展示平台服务费。
- 支付订单中的 `platformFee` 和 `amount` 仍以服务器响应为最终事实来源。
- 不修改支付接口、报价提交接口或数据库结构。
- 未经用户明确要求不创建 Git 提交。

---

### Task 1: 业主报价明细与服务费展示

**Files:**
- Modify: `zhidi_app/lib/pages/home/owner_quote_compare_page.dart`
- Test: `zhidi_app/test/owner_quote_confirmation_test.dart`

**Interfaces:**
- Consumes: `RemoteQuote.items`、`RemoteQuoteItem.isMaterial`、`RemoteQuote.totalPrice`。
- Produces: 报价卡和确认弹窗中的人工明细、材料明细、工人报价、平台服务费和应付合计。

- [ ] **Step 1: 写入失败的业主报价卡回归测试**

  构造包含一条人工项目 `吊顶安装 ¥120/平米 × 30` 和一条材料项目 `板材材料 ¥180/张 × 38` 的服务器响应，断言页面显示“人工明细”“材料明细”、两项单价与数量、“工人报价总额 ¥10440.00”“平台服务费（10%）¥1044.00”和“应付合计 ¥11484.00”。

- [ ] **Step 2: 运行测试并确认失败**

  Run: `flutter test test/owner_quote_confirmation_test.dart --plain-name "owner sees itemized quote plus platform fee before selection"`

  Expected: FAIL，因为当前报价卡只有扁平项目表和工人报价合计，没有人工/材料标题、服务费和应付合计。

- [ ] **Step 3: 实现业主报价卡费用结构**

  在 `_QuoteCard` 内将 `quote.items` 按 `isMaterial` 分成两组，分别渲染带“项目/单价/数量/小计”表头的明细；增加金额汇总区域。展示服务费使用 `double.parse((quote.totalPrice * 0.10).toStringAsFixed(2))`，应付合计为工人报价加服务费，并增加“平台服务费由业主另外支付，不从师傅报价中扣除”说明。

- [ ] **Step 4: 写入失败的确认弹窗金额测试**

  打开 `QuoteSelectionConfirmationDialog(workerName: '张师傅', totalPrice: 10840)`，断言显示工人报价 `¥10840.00`、平台服务费 `¥1084.00`、应付合计 `¥11924.00` 和服务费说明，同时保留核对勾选与长按按钮。

- [ ] **Step 5: 运行确认弹窗测试并确认失败**

  Run: `flutter test test/owner_quote_confirmation_test.dart --plain-name "confirmation repeats quote fee and owner payable total"`

  Expected: FAIL，因为当前弹窗仅显示原始报价。

- [ ] **Step 6: 实现确认弹窗金额复核**

  在 `QuoteSelectionConfirmationDialog` 使用与报价卡相同的两位小数计算规则，展示三项金额与服务费说明，不改变现有核对勾选和长按两秒确认逻辑。

- [ ] **Step 7: 运行业主报价测试**

  Run: `flutter test test/owner_quote_confirmation_test.dart`

  Expected: 全部 PASS。

---

### Task 2: 师傅查看服务器已提交报价

**Files:**
- Modify: `zhidi_app/lib/pages/worker/order_detail_page.dart`
- Reuse: `zhidi_app/lib/pages/shared/quote_detail_page.dart`
- Test: `zhidi_app/test/worker_order_detail_refresh_test.dart`
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- Consumes: `WorkerQuoteApiClient.listQuotesForBooking(String accessToken, String bookingId)` 返回的 `List<RemoteQuote>`。
- Produces: `OrderDetailPage` 可注入的 `WorkerQuoteApiClient? quoteApi`；真实报价摘要卡和 `QuoteDetailPage` 导航。

- [ ] **Step 1: 写入失败的工人真实报价查看测试**

  构造状态为 `QUOTE_PENDING` 的预约和返回人工、材料项目的报价接口；断言订单详情显示“查看已提交报价单”，点击后进入“报价明细”，并显示人工明细、材料明细、单价、数量和报价清单总价。

- [ ] **Step 2: 运行测试并确认失败**

  Run: `flutter test test/worker_order_detail_refresh_test.dart --plain-name "worker opens submitted remote quote from order detail"`

  Expected: FAIL，因为当前远程订单没有报价查看入口，也没有读取预约报价接口。

- [ ] **Step 3: 实现远程报价摘要卡**

  为 `OrderDetailPage` 增加可选 `quoteApi` 注入；将 `_QuotationCard` 扩展为有状态组件，使用工人令牌调用 `listQuotesForBooking`，按 `updatedAt` 选择最新报价。加载成功时显示“查看已提交报价单”卡片，点击后导航到 `QuoteDetailPage(quote: quote)`；`QUOTE_PENDING` 及后续订单均可查看。

- [ ] **Step 4: 写入并实现报价加载失败测试**

  让报价接口返回业务错误，断言订单详情仍存在并显示“报价加载失败，请重试”；点击重试重新调用接口，不弹出空白详情页。

- [ ] **Step 5: 运行工人订单详情测试**

  Run: `flutter test test/worker_order_detail_refresh_test.dart`

  Expected: 全部 PASS。

- [ ] **Step 6: 运行相关回归与静态检查**

  Run: `flutter test test/owner_quote_confirmation_test.dart test/worker_order_detail_refresh_test.dart test/worker_quotation_form_page_test.dart`

  Run: `flutter analyze`

  Expected: 测试全部 PASS，静态检查无 issue。

- [ ] **Step 7: 双模拟器真实报价复验**

  在工人模拟器从 `QUOTE_PENDING` 订单打开已提交报价，核对人工/材料明细；在业主模拟器打开同一预约报价，核对项目、单价、数量、小计一致，并确认业主端额外显示10%平台服务费和应付合计。不得再次提交报价或修改生产订单状态。

- [ ] **Step 8: 更新项目状态**

  在 `PROJECT_STATUS.md` 记录已验证的双端报价查看能力、测试结果和模拟器复验结果，不写临时调试过程。
