# 业主资料与地址簿完善 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 完成可从服务器恢复的业主个人资料和常用地址簿，并让新建装修需求默认使用业主选定的上门地址。

**Architecture:** 继续以 Spring Boot + MySQL 为唯一线上事实源，在 `owner_profiles` 上兼容新增账号资料字段，使用独立 `owner_addresses` 表承载多个地址。Flutter 将个人资料、地址簿和房屋需求解耦，所有写操作先成功写入服务器再更新本地状态。

**Tech Stack:** Java 21、Spring Boot 3.5、Spring Data JPA、Flyway、MySQL、Flutter、Dart、Widget Test。

## Global Constraints

- 不重建数据库、不删除或清空现有业主、地址、预约和项目数据。
- 保留 `owner_profiles.decoration_type/address/area` 兼容旧客户端，但新资料页不再编辑这些字段。
- 未接入第三方实名认证前只显示“手机号已验证”，不得显示“已实名认证”。
- 不新增 Mock、本地假保存或网络失败后的假成功。
- 地址及资料必须按当前 JWT 业主隔离，禁止跨账号读取和修改。
- 保留工作区既有未提交改动，不自动提交、推送或创建 PR。

---

### Task 1: 扩展业主资料数据契约

**Files:**
- Create: `zhidi_server/src/main/resources/db/migration/V23__owner_profile_and_addresses.sql`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfile.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileRequest.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileResponse.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerProfileService.java`
- Modify: `zhidi_server/src/test/java/com/zhidi/server/owner/OwnerProfileServiceIntegrationTest.java`
- Modify: `zhidi_server/src/test/java/com/zhidi/server/owner/OwnerProfileControllerTest.java`

**Interfaces:**
- Produces: `OwnerProfileRequest(name, city, decorationType, address, area, avatarUrl, gender)`。
- Produces: `OwnerProfileResponse(..., avatarUrl, gender, profileComplete)`；`profileComplete` 只要求非空 `name` 和 `city`。
- Consumes: 现有 `GET/PUT /api/v1/owners/me` 与 `/api/v1/storage/upload`。

- [x] **Step 1: 写失败测试**：断言新账号姓名和城市齐全即 `profileComplete=true`；头像路径和 `MALE/FEMALE/UNDISCLOSED` 可保存回读；外部 URL、非 `owner-avatar` 平台路径和非法性别返回 400。
- [x] **Step 2: 验证 RED**：运行 `cd zhidi_server && ./mvnw -q -Dtest=OwnerProfileServiceIntegrationTest,OwnerProfileControllerTest test`，确认因新字段和完成规则尚未实现而失败。
- [x] **Step 3: 最小实现**：迁移为 `owner_profiles` 增加 `avatar_url VARCHAR(500)` 与 `gender VARCHAR(20)`；实体、请求、响应和服务同步新增字段，头像仅允许 `/uploads/owner-avatar/`，空值规范为 `null`。
- [x] **Step 4: 验证 GREEN**：重跑两组测试，确认新规则通过且历史五字段请求仍能解析和保存。

### Task 2: 建立服务器地址簿

**Files:**
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerAddress.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerAddressRepository.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerAddressRequest.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerAddressResponse.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerAddressService.java`
- Create: `zhidi_server/src/main/java/com/zhidi/server/owner/OwnerAddressController.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/owner/OwnerAddressServiceIntegrationTest.java`
- Create: `zhidi_server/src/test/java/com/zhidi/server/owner/OwnerAddressControllerTest.java`
- Modify: `zhidi_server/src/main/resources/db/migration/V23__owner_profile_and_addresses.sql`

**Interfaces:**
- Produces: `GET/POST /api/v1/owners/me/addresses`。
- Produces: `PUT/DELETE /api/v1/owners/me/addresses/{addressId}`。
- Produces: `PUT /api/v1/owners/me/addresses/{addressId}/default`。
- Produces: `OwnerAddressResponse(id, recipient, phone, province, city, district, detail, isDefault, createdAt, updatedAt)`。

- [x] **Step 1: 写失败测试**：覆盖首次新增自动默认、第二条不抢默认、显式切换默认、编辑、删除默认后自动补位、删除最后一条、字段校验和跨业主 404。
- [x] **Step 2: 验证 RED**：运行 `cd zhidi_server && ./mvnw -q -Dtest=OwnerAddressServiceIntegrationTest,OwnerAddressControllerTest test`，确认地址表和接口尚不存在。
- [x] **Step 3: 最小实现**：在 V23 创建 `owner_addresses`；服务层所有写操作加事务，通过 `owner_user_id + id` 查询，切换默认前先清除当前业主其他默认地址，列表按默认优先和更新时间倒序返回。
- [x] **Step 4: 验证 GREEN**：重跑地址测试并运行 `./mvnw -q -DskipTests compile`，确认实体与迁移契约一致。

### Task 3: Flutter 资料与地址 API 状态层

**Files:**
- Modify: `zhidi_app/lib/app/owner_models.dart`
- Modify: `zhidi_app/lib/services/owner_profile_api_client.dart`
- Create: `zhidi_app/lib/services/owner_address_api_client.dart`
- Modify: `zhidi_app/lib/app/owner_app_state.dart`
- Modify: `zhidi_app/test/owner_profile_api_client_test.dart`
- Modify: `zhidi_app/test/owner_profile_state_sync_test.dart`
- Create: `zhidi_app/test/owner_address_api_client_test.dart`

**Interfaces:**
- Produces: `OwnerProfile.avatarUrl`、`OwnerProfile.gender`。
- Produces: `OwnerAddressApi.list/create/update/delete/setDefault`。
- Produces: `OwnerAppState.refreshOwnerAddresses()` 和服务器驱动的 `addAddress/updateAddress/deleteAddress/setDefaultAddress`。
- Consumes: Task 1、Task 2 的 JSON 契约。

- [x] **Step 1: 写失败测试**：资料 JSON 新字段正确解析/发送；地址五个请求路径、鉴权、中文错误、超时和非法响应正确处理；重新登录能用服务器地址覆盖本地旧缓存。
- [x] **Step 2: 验证 RED**：运行 `cd zhidi_app && /Users/liupei/Documents/zhidi/flutter/bin/flutter test test/owner_profile_api_client_test.dart test/owner_profile_state_sync_test.dart test/owner_address_api_client_test.dart`，确认缺少新模型与地址 API。
- [x] **Step 3: 最小实现**：扩展不可变模型和 `copyWith/toJson/fromJson`，新增地址 client；登录恢复与资料刷新后加载地址，写操作只采用服务器响应更新 `_addresses`，401 继续统一清理会话。
- [x] **Step 4: 验证 GREEN**：重跑三组测试，确认没有离线假成功，默认地址顺序与服务器一致。

### Task 4: 首次资料和个人中心体验

**Files:**
- Modify: `zhidi_app/lib/pages/auth/onboarding_page.dart`
- Modify: `zhidi_app/lib/pages/profile/profile_page.dart`
- Modify: `zhidi_app/lib/pages/profile/edit_profile_page.dart`
- Modify: `zhidi_app/lib/app/owner_app_state.dart`
- Modify: `zhidi_app/test/onboarding_page_test.dart`
- Modify: `zhidi_app/test/owner_profile_ui_sync_test.dart`

**Interfaces:**
- Consumes: `OwnerProfile(name, city, phone, avatarUrl, gender)` 与 `UploadApiClient.uploadImage(category: 'owner-avatar')`。
- Produces: 只要求姓名与城市的首次资料提交；个人中心“手机号已验证”；可编辑头像、姓名、性别和城市的资料页。

- [x] **Step 1: 写失败测试**：首次页不再要求房屋地址/装修类型/面积，手机号只读；个人中心不出现“已实名认证”；编辑页上传头像后发送平台 URL，保存失败不退出页面且保留输入。
- [x] **Step 2: 验证 RED**：运行 `cd zhidi_app && /Users/liupei/Documents/zhidi/flutter/bin/flutter test test/onboarding_page_test.dart test/owner_profile_ui_sync_test.dart`，确认旧页面字段和文案导致失败。
- [x] **Step 3: 最小实现**：重排首次资料；个人中心头像支持 URL/占位图并显示资料状态；编辑页加入性别选择、手机号只读和可选头像上传，所有保存通过 `OwnerAppState.updateProfile`。
- [x] **Step 4: 验证 GREEN**：重跑两组测试，检查 320px 窄屏和大字体下无溢出。

### Task 5: 地址管理真实闭环

**Files:**
- Modify: `zhidi_app/lib/pages/profile/address_page.dart`
- Modify: `zhidi_app/lib/pages/profile/profile_page.dart`
- Modify: `zhidi_app/test/address_page_test.dart`
- Modify: `zhidi_app/test/owner_profile_ui_sync_test.dart`

**Interfaces:**
- Consumes: `OwnerAppState.addresses` 与 `addAddress/updateAddress/deleteAddress/setDefaultAddress`。
- Produces: 省、市、区、详细地址表单；默认地址选择；列表手机号脱敏函数。

- [x] **Step 1: 写失败测试**：真实加载、空状态、新增、编辑、切换默认、删除确认、失败保留表单、列表手机号 `133****4758` 脱敏和个人中心地址数量提示。
- [x] **Step 2: 验证 RED**：运行 `cd zhidi_app && /Users/liupei/Documents/zhidi/flutter/bin/flutter test test/address_page_test.dart test/owner_profile_ui_sync_test.dart`，确认当前本地地址页缺少服务器状态和省份字段。
- [x] **Step 3: 最小实现**：页面初始化刷新服务器地址；新增省份字段和明确校验；保存期间防重复点击；删除/设默认使用服务端结果；地址列表正文使用脱敏手机号。
- [x] **Step 4: 验证 GREEN**：重跑两组测试，确认错误提示为中文且网络失败不会丢失输入。

### Task 6: 新建需求自动带入默认地址

**Files:**
- Modify: `zhidi_app/lib/pages/renovation/trade_select_page.dart`
- Modify: `zhidi_app/lib/app/owner_app_state.dart`
- Modify: `zhidi_app/test/trade_select_page_visual_test.dart`
- Modify: `zhidi_app/test/owner_booking_state_sync_test.dart`

**Interfaces:**
- Consumes: `OwnerAppState.defaultAddress`，由 `addresses.firstWhere(isDefault)` 计算，没有默认地址时为 `null`。
- Produces: `ServiceRequestDraft.serviceCity/serviceAddress` 和 `OwnerBookingCreateRequest.serviceCity/serviceAddress` 均优先使用默认地址。

- [x] **Step 1: 写失败测试**：有默认地址时需求和直接预约使用该城市及完整地址；无地址时提示“请先添加上门地址”并可进入地址管理；不得回退到历史 `profile.address`。
- [x] **Step 2: 验证 RED**：运行 `cd zhidi_app && /Users/liupei/Documents/zhidi/flutter/bin/flutter test test/trade_select_page_visual_test.dart test/owner_booking_state_sync_test.dart`，确认旧逻辑仍读取 `profile.address`。
- [x] **Step 3: 最小实现**：增加 `defaultAddress` getter 和完整地址拼接；创建需求/预约前检查默认地址，返回地址页后刷新并继续当前流程；本次请求只传快照，不修改地址簿。
- [x] **Step 4: 验证 GREEN**：重跑两组测试，确认默认地址切换后新请求使用新地址，历史预约仍保留旧快照。

### Task 7: 全量验证、部署与模拟器闭环

**Files:**
- Modify: `PROJECT_STATUS.md`
- Create: `zhidi_app/output/apks/zhidi-owner-debug-20260802-owner-profile.apk`
- Create: `zhidi_app/output/evidence/owner-profile-*.png`

**Interfaces:**
- Consumes: Tasks 1–6 的最终接口与页面。
- Produces: 可部署后端 jar、业主端 APK、模拟器证据和项目状态记录。

- [x] **Step 1: 全量自动验证**：运行后端相关测试及全量测试、`flutter analyze` 和 Flutter 全量测试；任何失败先定位并修复，不能用跳过代替。
- [x] **Step 2: 安全部署后端**：构建 jar，先备份 `/opt/zhidi/zhidi-server.jar`，部署并重启 `zhidi.service`；检查 Flyway 到 V23、健康接口、资料 GET/PUT 和地址 CRUD，禁止初始化数据库。
- [x] **Step 3: 构建安装**：使用 `API_BASE_URL=http://47.109.0.191:8080` 构建 owner flavor APK，安装到 `emulator-5554`。
- [x] **Step 4: 可视化闭环**：新业主登录 → 填姓名和城市 → 上传/跳过头像 → 新增默认地址 → 强停重启 → 编辑资料 → 找工种并确认默认地址自动带入；保存截图并检查运行日志无 Flutter 异常、红屏或溢出。
- [x] **Step 5: 状态交接**：更新 `PROJECT_STATUS.md`，记录已完成能力、真实验证结果、APK 路径和仍需营业执照/第三方资质的实名认证缺口；最后核对 `git diff --check` 和工作区差异范围。
