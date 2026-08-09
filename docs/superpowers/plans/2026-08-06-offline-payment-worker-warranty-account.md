# 线下付款与工人履约质保金账户 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将新订单改为“业主全额支付工人工程款＋业主支付10%平台服务费＋工人独立循环质保金账户”，兼容旧订单，并预留未启用的微信支付渠道接口。

**Architecture:** 新付款订单使用 `OFFLINE_SPLIT_V2`，分别跟踪工程款和平台服务费，只有工人确认工程款且管理员核验服务费后才完成。工人质保金从付款订单剥离为账户、补充义务和不可覆盖流水；售后从工人账户扣减，余额不足时阻止接新单。旧订单继续使用 `LEGACY_OWNER_RETENTION`，不重算、不删除。

**Tech Stack:** Java 21、Spring Boot 3.5、Spring Data JPA、Flyway、MySQL、JUnit 5、Mockito、Flutter、Dart、Widget Test。

**完成状态（2026-08-06）：** 本计划已在独立 worktree 完成并通过后端 247 项、Flutter 260 项全量测试，3 项 Flutter 测试按既有条件跳过，`flutter analyze` 无问题，后端 JAR 与双端 debug APK 构建成功。尚未提交、推送或部署到 ECS。

## Global Constraints

- 新订单业主向工人支付报价总额100%，另向平台支付报价总额10%的服务费。
- 本单不从业主付款中冻结质保金，也不把平台描述为工程款托管方。
- 工人质保金按每笔报价10%补充，有效余额上限固定为10000元。
- 质保金出现待补充义务时，工人在补足并经管理员核验前不能接新单。
- 旧付款订单和旧 `warranty_retentions` 保持原金额与原展示口径。
- 微信配置未提供时，微信下单必须返回 `PAYMENT_PROVIDER_NOT_CONFIGURED`，不能返回假成功。
- 数据库迁移只新增表和字段，不删除、不重新初始化、不修改旧金额。
- 不覆盖工作区已有改动；未经用户再次明确要求，不提交、不推送、不部署。

---

### Task 1: 新资金模型数据库迁移

**Files:**
- Create: `zhidi_server/src/main/resources/db/migration/V24__split_offline_payment_worker_warranty_account.sql`
- Create: `zhidi_server/src/test/java/com/zhidi/server/migration/SplitPaymentWarrantyMigrationTest.java`

**Interfaces:**
- Produces: `payment_orders.funding_model`、两类付款状态与凭证字段、`worker_warranty_accounts`、`worker_warranty_contributions`、`worker_warranty_ledger_entries`。

- [x] **Step 1: 写迁移失败测试**

  使用 Testcontainers/MySQL 迁移测试断言 V24 后存在以下结果：旧订单 `funding_model='LEGACY_OWNER_RETENTION'` 且金额不变；三个新表存在；`worker_warranty_accounts.worker_user_id` 唯一；`worker_warranty_contributions.payment_order_id` 唯一。

  ```java
  assertThat(queryString("SELECT funding_model FROM payment_orders WHERE id=?", orderId))
      .isEqualTo("LEGACY_OWNER_RETENTION");
  assertThat(queryDecimal("SELECT amount FROM payment_orders WHERE id=?", orderId))
      .isEqualByComparingTo("110.00");
  assertThat(tableExists("worker_warranty_accounts")).isTrue();
  ```

- [x] **Step 2: 运行迁移测试并确认 RED**

  Run: `cd zhidi_server && ./mvnw -Dtest=SplitPaymentWarrantyMigrationTest test`

  Expected: FAIL，原因是 V24 和新表尚不存在。

- [x] **Step 3: 编写 V24 迁移**

  `payment_orders` 新增：

  ```sql
  funding_model VARCHAR(40) NOT NULL DEFAULT 'LEGACY_OWNER_RETENTION',
  quote_amount DECIMAL(12,2) NULL,
  construction_payment_status VARCHAR(32) NOT NULL DEFAULT 'NOT_REPORTED',
  platform_fee_status VARCHAR(32) NOT NULL DEFAULT 'NOT_REPORTED',
  construction_payment_channel VARCHAR(32) NULL,
  construction_payment_reference VARCHAR(128) NULL,
  construction_reported_at DATETIME(6) NULL,
  construction_confirmed_at DATETIME(6) NULL,
  platform_fee_channel VARCHAR(32) NULL,
  platform_fee_reference VARCHAR(128) NULL,
  platform_fee_reported_at DATETIME(6) NULL,
  platform_fee_verified_by BINARY(16) NULL,
  platform_fee_verified_at DATETIME(6) NULL,
  platform_fee_rejection_reason VARCHAR(300) NULL
  ```

  新表使用 `DECIMAL(12,2)`，补充义务以 `payment_order_id` 唯一保证幂等，流水包含 `entry_type`、`amount`、`balance_after`、`source_type`、`source_id`、`actor_user_id` 和 `created_at`。

- [x] **Step 4: 运行迁移测试并确认 GREEN**

  Run: `cd zhidi_server && ./mvnw -Dtest=SplitPaymentWarrantyMigrationTest test`

  Expected: PASS，旧金额和旧质保金记录不变。

---

### Task 2: 拆分付款订单领域状态

**Files:**
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentFundingModel.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentComponentStatus.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentOrderStatus.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentOrder.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentOrderResponse.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/payment/PaymentOrderOfflineFlowTest.java`

**Interfaces:**
- Produces: `PaymentOrder.createSplitOffline(...)`、`reportSplitOfflinePayments(...)`、`confirmConstructionReceipt()`、`verifyPlatformFee(...)`、`fundingModel()` 和独立组件状态。

- [x] **Step 1: 写领域失败测试**

  ```java
  PaymentOrder order = PaymentOrder.createSplitOffline(
      bookingId, ownerId, workerId, quoteId, new BigDecimal("10840.00"));
  assertThat(order.getQuoteAmount()).isEqualByComparingTo("10840.00");
  assertThat(order.getAmount()).isEqualByComparingTo("11924.00");
  assertThat(order.getWorkerSettlement()).isEqualByComparingTo("10840.00");
  assertThat(order.getWarrantyRetention()).isZero();
  assertThat(order.getFundingModel()).isEqualTo(PaymentFundingModel.OFFLINE_SPLIT_V2);
  ```

  再覆盖仅确认任一组件不完成订单、两项都确认才进入 `PAID`、重复确认幂等。

- [x] **Step 2: 运行领域测试并确认 RED**

  Run: `cd zhidi_server && ./mvnw -Dtest=PaymentOrderOfflineFlowTest test`

  Expected: FAIL，原因是新工厂方法和字段不存在。

- [x] **Step 3: 实现最小领域逻辑**

  ```java
  public void refreshOverallStatus() {
      if (constructionPaymentStatus == PaymentComponentStatus.CONFIRMED
          && platformFeeStatus == PaymentComponentStatus.VERIFIED) {
          status = PaymentOrderStatus.PAID;
          if (paidAt == null) paidAt = Instant.now();
      } else if (constructionPaymentStatus == PaymentComponentStatus.REPORTED
          && platformFeeStatus == PaymentComponentStatus.REPORTED) {
          status = PaymentOrderStatus.UNDER_REVIEW;
      } else if (constructionPaymentStatus != PaymentComponentStatus.NOT_REPORTED
          || platformFeeStatus != PaymentComponentStatus.NOT_REPORTED) {
          status = PaymentOrderStatus.PARTIALLY_REPORTED;
      }
  }
  ```

  `getWarrantyRetention()` 对 `OFFLINE_SPLIT_V2` 固定返回 `0.00`；旧模型保持原计算。

- [x] **Step 4: 运行领域测试并确认 GREEN**

  Run: `cd zhidi_server && ./mvnw -Dtest=PaymentOrderOfflineFlowTest test`

  Expected: PASS。

---

### Task 3: 双付款报告、工人确认和管理员核验 API

**Files:**
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentOrderService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/AdminPaymentController.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/PaymentOrderRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/OfflinePaymentProperties.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/OfflinePaymentInstructionsResponse.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/payment/PaymentOrderServiceOfflineTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/payment/PaymentControllerTest.java`

**Interfaces:**
- Produces:
  - `POST /api/v1/payment/orders/{id}/offline-split-report`
  - `POST /api/v1/payment/orders/{id}/construction-receipt-confirmation`
  - `GET /api/v1/admin/payment-orders?platformFeeStatus=REPORTED`
  - `POST /api/v1/admin/payment-orders/{id}/platform-fee-verification`
  - `GET /api/v1/payment/offline-instructions`（已登录业主可读取公司服务费账户；工人工程款只返回订单工人姓名和联系入口，不返回未验证的银行卡）

- [x] **Step 1: 写服务和控制器失败测试**

  请求体固定为：

  ```json
  {
    "constructionChannel": "银行卡转账",
    "constructionReference": "worker-bank-001",
    "platformFeeChannel": "对公转账",
    "platformFeeReference": "company-bank-001",
    "note": "两笔均已转账"
  }
  ```

  测试业主不能确认工程款、工人不能核验服务费、普通用户访问管理员接口返回 403、相同参考号用于不同订单返回 `PAYMENT_REFERENCE_ALREADY_USED`。

- [x] **Step 2: 运行测试并确认 RED**

  Run: `cd zhidi_server && ./mvnw -Dtest=PaymentOrderServiceOfflineTest,PaymentControllerTest test`

  Expected: FAIL，新接口不存在。

- [x] **Step 3: 实现接口与幂等规则**

  新订单由 `createOrder()` 调用 `PaymentOrder.createSplitOffline(...)`。管理员核验请求固定为：

  ```java
  public record VerifyPlatformFeeRequest(
      @NotNull Boolean approved,
      @Size(max = 300) String reason) {}
  ```

  `approved=true` 写入管理员和时间；`approved=false` 将服务费组件设为 `REJECTED` 并保存原因。重复的同结果请求返回当前状态，不重复写账务结果。每次管理员核验还要写 `OperationLog`，动作分别为 `ADMIN_PLATFORM_FEE_APPROVE` 或 `ADMIN_PLATFORM_FEE_REJECT`，详情只保存订单号、金额和原因，不保存完整银行账号。

  公司服务费账户只从服务器环境变量读取：

  ```properties
  PAYMENT_COMPANY_ACCOUNT_NAME=
  PAYMENT_COMPANY_BANK_NAME=
  PAYMENT_COMPANY_BANK_ACCOUNT=
  ```

  三项任一缺失时，指引接口返回 503 `OFFLINE_PAYMENT_INSTRUCTIONS_NOT_CONFIGURED`，客户端不得展示付款成功入口。配置值不得写入 Git、日志或操作审计详情。

- [x] **Step 4: 保留旧接口但限制资金模型**

  `/offline-payment-report` 和 `/receipt-confirmation` 仅允许 `LEGACY_OWNER_RETENTION`。新订单调用旧接口返回 409 `PAYMENT_FLOW_MISMATCH`，避免新旧状态串用。

- [x] **Step 5: 运行测试并确认 GREEN**

  Run: `cd zhidi_server && ./mvnw -Dtest=PaymentOrderServiceOfflineTest,PaymentControllerTest test`

  Expected: PASS。

---

### Task 4: 工人履约质保金账户、补充义务和流水

**Files:**
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/WorkerWarrantyAccount.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/WorkerWarrantyAccountStatus.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/WorkerWarrantyContribution.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/WorkerWarrantyContributionStatus.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/WorkerWarrantyLedgerEntry.java`
- Create: repositories and response records for the three entities in `zhidi_server/src/main/java/com/zhidi/server/payment/`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/WorkerWarrantyAccountService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/WorkerWarrantyAccountController.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/AdminWorkerWarrantyController.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/payment/WorkerWarrantyAccountServiceTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/payment/WorkerWarrantyAccountControllerTest.java`

**Interfaces:**
- Produces:
  - `GET /api/v1/worker-warranty/account`
  - `GET /api/v1/worker-warranty/contributions`
  - `POST /api/v1/worker-warranty/contributions/{id}/report`
  - `GET /api/v1/admin/worker-warranty/contributions?status=REPORTED`
  - `POST /api/v1/admin/worker-warranty/contributions/{id}/verification`
  - `POST /api/v1/admin/worker-warranty/accounts/{id}/release`
  - `GET /api/v1/worker-warranty/payment-instructions`

- [x] **Step 1: 写金额和权限失败测试**

  ```java
  assertThat(service.calculateDue(workerId, new BigDecimal("10840")))
      .isEqualByComparingTo("1084.00");
  account.credit(new BigDecimal("9500.00"));
  assertThat(service.calculateDue(workerId, new BigDecimal("10840")))
      .isEqualByComparingTo("500.00");
  ```

  覆盖余额10000时增量为0、重复付款订单只创建一条义务、管理员核验后账户入账一次、驳回不入账、非管理员403；释放接口在仍有进行中订单、未关闭售后或工人仍可接单时返回409。

- [x] **Step 2: 运行测试并确认 RED**

  Run: `cd zhidi_server && ./mvnw -Dtest=WorkerWarrantyAccountServiceTest,WorkerWarrantyAccountControllerTest test`

  Expected: FAIL，新账户类型不存在。

- [x] **Step 3: 实现账户和补充义务**

  ```java
  BigDecimal available = CAP.subtract(account.getEffectiveBalance())
      .max(BigDecimal.ZERO.setScale(2));
  BigDecimal orderTenPercent = quoteAmount.multiply(new BigDecimal("0.10"))
      .setScale(2, RoundingMode.HALF_UP);
  BigDecimal due = orderTenPercent.min(available);
  ```

  付款订单首次进入 `PAID` 时调用 `createContributionDue(paymentOrder)`；使用 `payment_order_id` 唯一约束和事务保证幂等。

  工人质保金账户与平台服务费账户使用不同环境配置：

  ```properties
  PAYMENT_WARRANTY_ACCOUNT_NAME=
  PAYMENT_WARRANTY_BANK_NAME=
  PAYMENT_WARRANTY_BANK_ACCOUNT=
  ```

  缺少任一项时返回 503 `WARRANTY_PAYMENT_INSTRUCTIONS_NOT_CONFIGURED`，不能让工人提交已转账状态。

- [x] **Step 4: 实现管理员核验和不可覆盖流水**

  管理员通过时以数据库锁读取账户，增加余额并写 `CONTRIBUTION` 流水；售后扣减写 `DEDUCTION`；退出释放写 `RELEASE`。每条流水保存操作后余额。核验、驳回、扣减和释放均写 `OperationLog`；释放服务必须查询工人接单开关、进行中预约及未关闭售后，任一不满足都不能释放。

- [x] **Step 5: 运行测试并确认 GREEN**

  Run: `cd zhidi_server && ./mvnw -Dtest=WorkerWarrantyAccountServiceTest,WorkerWarrantyAccountControllerTest test`

  Expected: PASS。

---

### Task 5: 售后扣减与接单资格联动

**Files:**
- Modify: `zhidi_server/src/main/java/com/zhidi/server/payment/AfterSaleService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingService.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/payment/AfterSaleServiceTest.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/booking/BookingWarrantyEligibilityTest.java`

**Interfaces:**
- Consumes: `WorkerWarrantyAccountService.hasOutstandingContribution(UUID)`、`deductForAfterSale(...)`。
- Produces: 新资金模型售后从工人账户扣减；待补足工人接单返回 409 `WORKER_WARRANTY_TOP_UP_REQUIRED`。

- [x] **Step 1: 写联动失败测试**

  ```java
  when(warrantyAccounts.hasOutstandingContribution(workerId)).thenReturn(true);
  assertThatThrownBy(() -> bookingService.accept(workerId, bookingId))
      .isInstanceOfSatisfying(BusinessException.class,
          ex -> assertThat(ex.code()).isEqualTo("WORKER_WARRANTY_TOP_UP_REQUIRED"));
  ```

  售后测试分别覆盖新模型扣账户、旧模型继续扣 `warranty_retentions`。

- [x] **Step 2: 运行测试并确认 RED**

  Run: `cd zhidi_server && ./mvnw -Dtest=AfterSaleServiceTest,BookingWarrantyEligibilityTest test`

  Expected: FAIL，尚未联动。

- [x] **Step 3: 实现最小联动**

  只在 `BookingService.accept()` 前检查已到期且未核验的补充义务；工人仍可查看、完成已有订单。售后通过付款订单 `fundingModel` 决定旧质保记录或新账户。

- [x] **Step 4: 运行测试并确认 GREEN**

  Run: `cd zhidi_server && ./mvnw -Dtest=AfterSaleServiceTest,BookingWarrantyEligibilityTest test`

  Expected: PASS。

---

### Task 6: 微信支付渠道接口预留

**Files:**
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/provider/PaymentProvider.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/provider/PaymentIntent.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/provider/PaymentCallbackResult.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/provider/UnconfiguredWechatPaymentProvider.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/payment/WechatPaymentController.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/payment/WechatPaymentControllerTest.java`

**Interfaces:**
- Produces: `POST /api/v1/payment/orders/{id}/wechat-intent` 和未来微信专用回调边界。

- [x] **Step 1: 写未配置渠道失败测试**

  ```java
  mockMvc.perform(post("/api/v1/payment/orders/{id}/wechat-intent", orderId)
      .with(jwtOwner(ownerId)))
      .andExpect(status().isServiceUnavailable())
      .andExpect(jsonPath("$.code").value("PAYMENT_PROVIDER_NOT_CONFIGURED"));
  ```

- [x] **Step 2: 运行测试并确认 RED**

  Run: `cd zhidi_server && ./mvnw -Dtest=WechatPaymentControllerTest test`

  Expected: FAIL，接口不存在。

- [x] **Step 3: 实现不可伪造的未配置实现**

  `UnconfiguredWechatPaymentProvider` 的下单、退款、分账全部抛出同一明确业务错误。通用 `/api/v1/payment/callback` 保持关闭；未来微信回调只能由验签后的 `PaymentCallbackResult` 驱动。

- [x] **Step 4: 运行测试并确认 GREEN**

  Run: `cd zhidi_server && ./mvnw -Dtest=WechatPaymentControllerTest test`

  Expected: PASS，响应中没有模拟 `transactionId`。

---

### Task 7: Flutter 模型和 API 客户端兼容新旧资金模型

**Files:**
- Modify: `zhidi_app/lib/models/payment_models.dart`
- Modify: `zhidi_app/lib/services/payment_api_client.dart`
- Test: `zhidi_app/test/payment_models_test.dart`
- Test: `zhidi_app/test/payment_api_client_test.dart`

**Interfaces:**
- Produces: `PaymentOrderModel.fundingModel`、`quoteAmount`、两组件状态、`isSplitOfflineV2`；`WorkerWarrantyAccountModel`、`WorkerWarrantyContributionModel`；新报告与确认 API 方法。

- [x] **Step 1: 写解析和请求失败测试**

  新模型 JSON 断言：

  ```dart
  expect(order.fundingModel, 'OFFLINE_SPLIT_V2');
  expect(order.quoteAmount, 10840);
  expect(order.warrantyRetention, 0);
  expect(order.constructionPaymentStatus, 'REPORTED');
  expect(order.platformFeeStatus, 'REPORTED');
  ```

  旧 JSON 缺少 `fundingModel` 时必须默认为 `LEGACY_OWNER_RETENTION`。

- [x] **Step 2: 运行测试并确认 RED**

  Run: `cd zhidi_app && ../flutter/bin/flutter test test/payment_models_test.dart test/payment_api_client_test.dart`

  Expected: FAIL，新字段与方法不存在。

- [x] **Step 3: 实现模型和客户端**

  新客户端方法：

  ```dart
  Future<PaymentOrderModel> reportSplitOfflinePayments(...)
  Future<PaymentOrderModel> confirmConstructionReceipt(...)
  Future<WorkerWarrantyAccountModel> getWorkerWarrantyAccount(...)
  Future<List<WorkerWarrantyContributionModel>> listWorkerWarrantyContributions(...)
  Future<WorkerWarrantyContributionModel> reportWarrantyContribution(...)
  Future<void> createWechatIntent(...) // 未配置时透出明确错误
  ```

- [x] **Step 4: 运行测试并确认 GREEN**

  Run: `cd zhidi_app && ../flutter/bin/flutter test test/payment_models_test.dart test/payment_api_client_test.dart`

  Expected: PASS。

---

### Task 8: 业主端两步付款、一次提交页面

**Files:**
- Modify: `zhidi_app/lib/pages/home/owner_payment_page.dart`
- Test: `zhidi_app/test/owner_payment_page_test.dart`
- Test: `zhidi_app/test/my_home_minimal_page_test.dart`

**Interfaces:**
- Consumes: `PaymentOrderModel.isSplitOfflineV2` 和 `reportSplitOfflinePayments(...)`。
- Produces: 同页两笔付款向导及组件级等待状态。

- [x] **Step 1: 写页面失败测试**

  对新订单断言页面显示“支付工程款给工人 ¥10840.00”“支付平台服务费给知底 ¥1084.00”“应付合计 ¥11924.00”，且不显示“工人可结算90%”“质保金冻结10%”“我已线下付款 ¥11924.00”。

- [x] **Step 2: 运行测试并确认 RED**

  Run: `cd zhidi_app && ../flutter/bin/flutter test test/owner_payment_page_test.dart test/my_home_minimal_page_test.dart`

  Expected: FAIL，旧页面只有单笔线下付款。

- [x] **Step 3: 实现两步付款表单**

  两个步骤分别显示只读金额和收款对象，各自填写渠道及交易参考号，底部只有一个“提交付款核验”按钮。提交成功按组件状态显示“等待工人确认工程款”和“等待平台核验服务费”。旧订单继续走原页面分支。

  工程款步骤显示工人姓名及“联系工人确认收款方式”，不在平台保存或展示未经核验的工人银行卡。平台服务费步骤读取服务器返回的公司对公账户；服务端未配置时禁用统一提交并显示“平台收款账户配置中，请稍后再试”。

- [x] **Step 4: 防误触与错误文案**

  提交前二次核对两笔收款对象和金额；服务器错误映射为中文，不在网络失败时改变本地付款状态。

- [x] **Step 5: 运行测试并确认 GREEN**

  Run: `cd zhidi_app && ../flutter/bin/flutter test test/owner_payment_page_test.dart test/my_home_minimal_page_test.dart`

  Expected: PASS。

---

### Task 9: 工人端全额工程款与独立质保金账户

**Files:**
- Modify: `zhidi_app/lib/pages/worker/worker_settlement_page.dart`
- Modify: `zhidi_app/lib/pages/worker/worker_home_page.dart`
- Modify: `zhidi_app/lib/pages/worker/order_detail_page.dart`
- Modify: `zhidi_app/lib/app/worker_app_state.dart`
- Test: `zhidi_app/test/worker_bottom_navigation_test.dart`
- Test: `zhidi_app/test/worker_order_detail_refresh_test.dart`
- Test: `zhidi_app/test/worker_session_state_test.dart`

**Interfaces:**
- Consumes: 新付款和质保金账户 API。
- Produces: 本单应收100%、工程款确认、质保金余额/补足入口、待补足接单提示。

- [x] **Step 1: 写工人端失败测试**

  对新订单断言“本单应收 ¥10840”“平台服务费由业主另付”“履约质保金余额 ¥3084”“本单待补充 ¥1084”；不得显示“本单可结算90%”或“从本单冻结10%”。

- [x] **Step 2: 运行测试并确认 RED**

  Run: `cd zhidi_app && ../flutter/bin/flutter test test/worker_bottom_navigation_test.dart test/worker_order_detail_refresh_test.dart test/worker_session_state_test.dart`

  Expected: FAIL，仍按旧质保扣款展示。

- [x] **Step 3: 实现新旧页面分支**

  新订单的确认按钮调用 `confirmConstructionReceipt`；工人首页顶部收入使用新订单报价总额，不从中减质保金。质保卡读取账户和补充义务；旧订单继续读取 `workerSettlement/warrantyRetention`。

- [x] **Step 4: 处理待补足接单错误**

  后端返回 `WORKER_WARRANTY_TOP_UP_REQUIRED` 时，工人端显示“履约质保金待补足，完成核验后可继续接单”，并提供进入质保金详情页的入口，不显示通用 internal server error。

- [x] **Step 5: 运行测试并确认 GREEN**

  Run: `cd zhidi_app && ../flutter/bin/flutter test test/worker_bottom_navigation_test.dart test/worker_order_detail_refresh_test.dart test/worker_session_state_test.dart`

  Expected: PASS。

---

### Task 10: 全量回归、文档同步和部署前检查

**Files:**
- Modify: `PROJECT_STATUS.md`
- Modify: `docs/superpowers/plans/2026-08-06-offline-payment-worker-warranty-account.md`

**Interfaces:**
- Produces: 自动化验证证据、待部署状态说明；不自动部署。

- [x] **Step 1: 运行后端支付、预约、售后和迁移测试**

  Run:

  ```bash
  cd zhidi_server
  ./mvnw -Dtest='com.zhidi.server.payment.*,com.zhidi.server.booking.*,com.zhidi.server.migration.*' test
  ./mvnw -DskipTests package
  ```

  Expected: BUILD SUCCESS，0 failures，Flyway V24 迁移测试通过。

- [x] **Step 2: 运行 Flutter 聚焦与全量验证**

  Run:

  ```bash
  cd zhidi_app
  ../flutter/bin/flutter test test/payment_models_test.dart test/payment_api_client_test.dart test/owner_payment_page_test.dart test/my_home_minimal_page_test.dart test/worker_bottom_navigation_test.dart test/worker_order_detail_refresh_test.dart test/worker_session_state_test.dart
  ../flutter/bin/flutter analyze
  ../flutter/bin/flutter test
  ```

  Expected: 全部 PASS，`flutter analyze` 无 error。

- [x] **Step 3: 检查旧数据兼容和新接口契约**

  用隔离测试库分别创建旧订单和新订单，确认旧订单金额/质保金未变化，新订单 `warrantyRetention=0`、`workerSettlement=quoteAmount`，普通用户不能调用管理员核验。

- [x] **Step 4: 构建双端 APK 但不部署服务器**

  Run:

  ```bash
  cd zhidi_app
  ../flutter/bin/flutter build apk --debug --flavor owner --dart-define=API_BASE_URL=http://47.109.0.191:8080
  ../flutter/bin/flutter build apk --debug --flavor worker --dart-define=API_BASE_URL=http://47.109.0.191:8080
  ```

  Expected: owner/worker APK 构建成功。因后端尚未部署，新 APK 不安装到用于公网闭环的模拟器。

- [x] **Step 5: 更新项目状态和计划勾选**

  在 `PROJECT_STATUS.md` 只记录已通过验证的能力、旧数据兼容结论、尚未部署以及微信支付仍未配置；不写临时调试过程。

- [x] **Step 6: 人工审查改动范围**

  Run: `git status --short && git diff --check && git diff --stat`

  Expected: 本计划新增改动只涉及支付、质保金、预约资格检查、Flutter 页面/测试、迁移和文档；当前 worktree 在本计划开始前已经包含用户批准保留的其他未提交改动。无空白错误，等待用户明确批准后再提交或部署。
