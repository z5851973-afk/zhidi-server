# 知底 P1 单工种闭环稳固实施计划

> 目标：在 P0 已完成的真实订单隔离、真实资料、真实报价/验收/线下付款和应用内通知基础上，把单工种业务做到可连续复测、可追溯、可补救。全屋父项目、真实线上支付和系统级推送不混入本计划。

## 交付边界

- 候选：同一需求可移除、补位、原子替换；已分配/已取消需求禁止继续加人；取消后的“重新找”克隆新需求并保留旧审计。
- 到场：约定上门时间与实际到场时间独立保存、独立展示。
- 项目数据：`我的家`、`我的预约`、个人中心项目数使用同一份服务端需求/预约数据。
- 验收：业主必须主动选择结论；不通过必须填写整改意见；照片真实上传并保存；工人能查看整改证据并重新发起验收；多轮记录有顺序且不会覆盖。
- 日报：双方都能查看真实照片和错误状态；上传失败只重试失败项；提交与通知可追踪。
- 售后：必须绑定已完成业务订单；业主和工人都能看到；支持证据、追加说明、平台回复、处理时限和时间线。
- 通知：以不可丢的服务端业务事件作为源，前台仍可轮询；系统级推送留到后续资质/基础设施批次。

## 明确不在本批次

- `WholeHomeProject` 全屋父项目、跨工种依赖和总预算。
- 微信/支付宝真实收单、退款、分账和自动结算。
- FCM/厂商系统推送、对象存储私有签名 URL 的完整生产化。
- 未取得资质前的资金托管、银行监管、保险承诺。

---

## Task 1：候选移除、补位、原子替换和审计式重开

### 后端文件

- `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestController.java`
- `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestService.java`
- `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequest.java`
- `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestResponse.java`
- `zhidi_server/src/main/java/com/zhidi/server/booking/Booking.java`
- `zhidi_server/src/main/java/com/zhidi/server/booking/BookingRepository.java`
- `zhidi_server/src/test/java/com/zhidi/server/servicerequest/ServiceRequestServiceTest.java`
- 新增 `zhidi_server/src/test/java/com/zhidi/server/servicerequest/ServiceRequestCandidateLifecycleIntegrationTest.java`

### TDD 步骤

1. 先写失败测试：
   - 业主移除 `PENDING/ACCEPTED/VISIT_PROPOSED/VISIT_SCHEDULED/ARRIVAL_PENDING` 候选后，booking 变 `CANCELLED`，请求活跃数和 `OPEN/COMPARING` 同步。
   - `ON_SITE/HIRED/COMPLETED` 禁止移除。
   - 替换成功时旧候选结束、新候选创建；新师傅校验失败时事务回滚，旧候选不变。
   - `ASSIGNED/CANCELLED` 请求禁止补位或替换。
   - 并发添加/替换后活跃候选不超过 3。
   - 已取消请求“重新找”创建新 request，旧 request/booking 不被改写。
2. 实现接口：
   - `POST /api/v1/owners/me/service-requests/{requestId}/candidates/{bookingId}/remove`
   - `POST /api/v1/owners/me/service-requests/{requestId}/candidates/{bookingId}/replace`
   - `POST /api/v1/owners/me/service-requests/{requestId}/reopen`（克隆语义）
3. 响应返回：`activeCandidateCount`、`availableCandidateSlots`、`canAddCandidates`；候选返回 `canRemove/canReplace`。
4. 运行聚焦测试与完整后端测试。

### Flutter 文件

- `zhidi_app/lib/services/service_request_api_client.dart`
- `zhidi_app/lib/pages/home/worker/candidate_picker_page.dart`
- `zhidi_app/lib/pages/renovation/trade_select_page.dart`
- `zhidi_app/lib/pages/home/my_home_page.dart`
- `zhidi_app/test/candidate_picker_page_test.dart`
- `zhidi_app/test/my_home_minimal_page_test.dart`

### Flutter TDD 步骤

1. 失败测试覆盖：打开现有 request 时加载已有候选、显示剩余名额、移除、替换、补位；拒单后从同一需求继续选人；终态候选不可操作。
2. `CandidatePickerPage` 接受 `requestId`，加载当前 request，不重复新建需求。
3. “完成选择”在无候选时明确禁用原因；被拒/取消后显示“继续选师傅”。
4. 替换使用单个原子 API，不在客户端串行模拟成功。

---

## Task 2：约定上门时间与实际到场时间分离

### 后端文件

- 新增 `zhidi_server/src/main/resources/db/migration/V25__booking_scheduled_and_actual_visit_times.sql`
- `zhidi_server/src/main/java/com/zhidi/server/booking/Booking.java`
- `zhidi_server/src/main/java/com/zhidi/server/booking/BookingResponse.java`
- `zhidi_server/src/main/java/com/zhidi/server/booking/BookingService.java`
- `zhidi_server/src/test/java/com/zhidi/server/booking/VisitFlowIntegrationTest.java`

### TDD 步骤

1. 失败测试：接受提议后固化 `scheduledVisitAt`；双方确认后写 `actualOnSiteAt`；实际时间不覆盖计划时间；拒绝后重新提议只采用最新被接受提议；重复到场幂等。
2. 数据迁移新增 `scheduled_visit_at`，现有 `on_site_at` 作为实际到场；API 新增清晰字段，并暂时保留 `proposedTime/onSiteAt` 兼容一版。
3. `acceptVisit` 固化约定时间；进入 `ON_SITE` 仅写实际到场时间。

### Flutter 文件

- `zhidi_app/lib/services/service_request_api_client.dart`
- `zhidi_app/lib/services/worker_booking_api_client.dart`
- `zhidi_app/lib/app/worker_models.dart`
- `zhidi_app/lib/app/worker_app_state.dart`
- `zhidi_app/lib/app/owner_app_state.dart`
- `zhidi_app/lib/pages/home/my_home_page.dart`
- `zhidi_app/lib/pages/order/my_orders_page.dart`
- `zhidi_app/lib/pages/worker/order_detail_page.dart`
- 相关 model/page tests

### Flutter TDD 步骤

1. model 新旧字段兼容测试。
2. 双端同时显示“约定上门时间”和“实际到场时间”；未到场显示“待到场”。
3. 删除 `actual ?? scheduled` 的覆盖式展示，不再把到场时间写成“开工时间”。

---

## Task 3：业主项目服务端同源与精确详情入口

### 文件

- `zhidi_app/lib/app/owner_app_state.dart`
- `zhidi_app/lib/pages/home/my_home_page.dart`
- `zhidi_app/lib/pages/order/my_orders_page.dart`
- `zhidi_app/lib/pages/profile/profile_page.dart`
- 新增或提取 `zhidi_app/lib/pages/home/owner_booking_detail_page.dart`
- `zhidi_app/test/owner_booking_state_sync_test.dart`
- `zhidi_app/test/my_orders_dismiss_test.dart`
- `zhidi_app/test/owner_profile_ui_sync_test.dart`
- `zhidi_app/test/my_home_minimal_page_test.dart`

### TDD 步骤

1. 失败测试：同一服务端 request/booking 在三处显示相同数量、状态、师傅、计划/实际时间；刷新失败保留最后成功快照并显示可重试；账号切换后不串数据。
2. `OwnerAppState` 持久化 `RemoteServiceRequest` 快照与最后同步状态；`MyHomePage` 不再维护第二份独立请求缓存。
3. 个人中心项目数来自服务端 request（按 requestId 去重），点击进入项目列表。
4. 我的预约卡可进入精确 booking 详情；不存在/已失效时显示明确空态，不 fallback 到其他订单。
5. 本地旧 `OwnerProject` 仅用于尚未迁移的全屋原型，不参与真实项目统计。

---

## Task 4：验收证据与多轮整改复验

### 后端文件

- 新增 `zhidi_server/src/main/resources/db/migration/V26__inspection_submissions_and_record_version.sql`
- `zhidi_server/src/main/java/com/zhidi/server/inspection/InspectionNode.java`
- `zhidi_server/src/main/java/com/zhidi/server/inspection/InspectionRecord.java`
- `zhidi_server/src/main/java/com/zhidi/server/inspection/InspectionService.java`
- `zhidi_server/src/main/java/com/zhidi/server/inspection/InspectionController.java`
- 新增 `InspectionSubmission`、repository、timeline response
- `zhidi_server/src/test/java/com/zhidi/server/inspection/InspectionIntegrationTest.java`

### TDD 步骤

1. 失败测试：
   - `FAIL` 无整改意见返回 400。
   - 工人首次发起与整改复验均保存说明和照片。
   - 业主判定保存说明、照片和唯一递增版本。
   - 两轮失败再通过的 timeline 完整且有序。
   - 并发判定不产生重复版本；跨工种和重复节点拒绝。
2. 发起验收接口接收 `{note, photos}`；新增 timeline 查询。
3. 记录必须校验图片数量、URL 来源与 booking/node 归属。

### Flutter 文件

- `zhidi_app/lib/pages/home/owner_inspection_page.dart`
- `zhidi_app/lib/pages/worker/inspection_page.dart`
- `zhidi_app/lib/services/inspection_api_client.dart`
- `zhidi_app/lib/services/upload_api_client.dart`
- `zhidi_app/test/owner_inspection_page_remote_test.dart`
- `zhidi_app/test/worker_inspection_page_test.dart`

### Flutter TDD 步骤

1. 验收结论默认 `null`，未选择时按钮不可提交。
2. 选择“不通过”后整改意见必填。
3. 业主可选最多 9 张照片、逐张上传、删除；上传失败不提交验收且可重试。
4. 工人发起/复验可附说明和照片，能查看业主整改图文。
5. timeline 展示提交、判定、整改、复验的时间、角色和图片。

---

## Task 5：日报可靠上传、双方时间线和可重试错误

### 文件

- `zhidi_app/lib/pages/worker/daily_report_page.dart`
- `zhidi_app/lib/pages/home/my_home_page.dart`
- `zhidi_app/lib/services/daily_report_api_client.dart`
- `zhidi_app/lib/services/upload_api_client.dart`
- `zhidi_app/test/worker_daily_report_upload_test.dart`
- 新增 owner daily report tests
- 后端 `dailyreport/*` 与相应测试

### TDD 步骤

1. 失败测试：3 张图第 2 张失败后，重试只上传失败图；成功 URL 不重复上传；页面重建保留成功上传结果。
2. 每张图片保存 `localPath/remoteUrl/progress/error`，提交前只补传失败项。
3. 工人与业主历史均显示照片、提交时间和明确错误；失败不能静默成空列表。
4. 日报修订不再覆盖审计记录：新增 revision 或 append-only 版本；同日期最新展示但历史可追溯。

---

## Task 6：售后订单上下文、证据、双方追加和处理时间线

### 后端文件

- 新增 `zhidi_server/src/main/resources/db/migration/V28__after_sale_collaboration.sql`
- `zhidi_server/src/main/java/com/zhidi/server/payment/AfterSale.java`
- `zhidi_server/src/main/java/com/zhidi/server/payment/AfterSaleService.java`
- `zhidi_server/src/main/java/com/zhidi/server/payment/AfterSaleController.java`
- `zhidi_server/src/main/java/com/zhidi/server/payment/AfterSaleRepository.java`
- 新增 `AfterSaleEvent`、repository、detail/timeline DTO
- `zhidi_server/src/test/java/com/zhidi/server/payment/AfterSaleServiceTest.java`
- `zhidi_server/src/test/java/com/zhidi/server/payment/PaymentControllerTest.java`

### TDD 步骤

1. 创建只允许已选工、已完工且存在已确认付款记录的 booking；修复空 workerId 时参与方检查 NPE。
2. `after_sales` 增 `worker_user_id/accepted_at/due_at/resolved_at/closed_at/last_activity_at`。
3. `after_sale_events` 只追加，记录角色、类型、文字、证据、幂等键、时间。
4. 工人列表按 booking 参与方可发现；非参与者 404/403；OPEN 重复申请有明确规则。
5. 管理端拆成受理、回复、解决、关闭，不再 OPEN 直接跳最终态。
6. detail 返回订单、工种、双方、报价、付款、验收摘要、SLA 与完整 timeline。

### Flutter 文件

- `zhidi_app/lib/models/payment_models.dart`
- `zhidi_app/lib/services/payment_api_client.dart`
- `zhidi_app/lib/pages/home/owner_after_sale_page.dart`
- 新增 `zhidi_app/lib/pages/worker/worker_after_sale_page.dart`
- `zhidi_app/lib/pages/profile/support_page.dart`
- `zhidi_app/lib/pages/worker/worker_home_page.dart`
- 相关 widget/API tests

### Flutter TDD 步骤

1. 业主从精确 booking 进入，先看到订单、师傅、工种、付款和验收摘要，再选择问题类型。
2. 支持文字与图片证据、追加说明、平台回复、处理时限、状态时间线。
3. 工人可看到与自己 booking 关联的售后并回复/补证据。
4. 个人中心“保障与售后”收口到服务器售后页，移除本地第二套假记录。

---

## Task 7：不可丢业务事件流与多轮通知

### 后端文件

- 新增 `zhidi_server/src/main/resources/db/migration/V29__business_events.sql`
- 新增 `notification/BusinessEvent.java`、repository、service、controller、response
- 日报、验收、售后服务在原事务中写事件
- 相应 integration tests

### TDD 步骤

1. 每个事件有唯一 eventId；幂等键为实际动作/版本，不以 `bookingId + eventType` 粗粒度去重。
2. 两轮整改分别生成两条消息；同一 booking 的两个售后 ticket 不碰撞；首次登录不会吞掉已有未读。
3. API：`GET /api/v1/notifications?after=<cursor>&size=`、`PUT /api/v1/notifications/{id}/read`。
4. Flutter 双端继续前台轮询，但读取事件游标并持久化；深链校验精确 aggregateId。

---

## Task 8：验证、视觉复验和状态文档

1. 后端完整测试：`./mvnw test`。
2. Flutter：聚焦测试、`flutter test`、`flutter analyze`、`dart format --output=none --set-exit-if-changed`。
3. 双模拟器从新账号跑：找工人 → 候选移除/替换/补位 → 接单 → 约定上门 → 实际到场 → 报价 → 选人 → 日报 → 两轮整改复验 → 付款报备 → 工人确认 → 售后追加/回复。
4. 同时验证两个不同工种、两个不同地址和同工种连续第二单不串数据。
5. 使用同一 viewport 截图对比候选、我的家、验收、售后关键页，修复溢出、禁用原因、加载/错误/空态。
6. 更新 `PROJECT_STATUS.md`，明确本地完成、未部署、未上线能力和剩余外部条件。

## 完成标准

- 所有状态变更都来自服务器明确动作，不由 Flutter 猜测。
- 所有页面按 `serviceRequestId + bookingId` 精确定位。
- 所有证据都有真实 URL、角色、时间和版本；失败可重试，不出现本地假成功。
- 三个业主入口显示同一份服务端项目事实。
- 后端/Flutter 全量测试通过，静态分析通过，工作区无新增格式错误。
- 未经用户单独要求，不部署、不清库、不提交 Git。
