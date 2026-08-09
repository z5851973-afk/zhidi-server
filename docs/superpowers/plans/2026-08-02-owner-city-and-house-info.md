# 业主城市选择与房屋信息双端贯通 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将业主首次资料和编辑资料的所在城市统一为四川/甘肃受控选择，并让每个新装修需求必须携带建筑面积及室厅厨卫信息且在业主、工人两端一致展示。

**Architecture:** 省市选择复用现有 `OwnerServiceRegionCatalog`，抽为无键盘自由输入的共享组件。房屋信息作为 `service_requests` 的结构化字段落库，`BookingResponse` 通过 `serviceRequestId` 读取关联需求后带出字段，Flutter 使用统一 `HouseInfo`/格式化方法贯穿需求创建、候选、我的家、工人订单与报价页面。历史数据保留空值并显示“房屋信息未填写”，所有新建入口都必须经过相同校验。

**Tech Stack:** Flutter/Dart、Spring Boot 3.5、Java 21、JPA/Hibernate、MySQL 8、Flyway、JUnit 5/MockMvc/Testcontainers、Flutter Widget Test。

## Global Constraints

- 只开放四川省和甘肃省；个人资料 API 仍只保存正式城市名，不新增省份字段。
- 新需求建筑面积范围为 `1–9999㎡`，最多两位小数。
- 卧室 `1–20`、客厅 `0–10`、厨房 `0–10`、卫生间 `1–20`；界面默认 `3室2厅1厨2卫`。
- `service_requests` 新列必须可空以兼容历史数据；不得删除、重建或猜测回填历史记录。
- 新需求必须有完整房屋信息；历史空数据统一显示“房屋信息未填写”。
- Booking 不重复持久化房屋信息，以关联 `serviceRequestId` 为事实源。
- 网络失败时不做本地假成功，表单数据必须保留。
- 不改主页大框架，不引入新的第三方依赖，不处理四川/甘肃以外城市。
- 当前工作区包含大量用户已有未提交改动；每一步只编辑列出的文件，不还原无关文件。
- 未经用户明确要求，不执行 git commit、push 或创建 PR；各任务以测试结果作为检查点。

---

## File Structure

### 新建文件

- `zhidi_app/lib/pages/shared/owner_city_picker.dart`：共享省份/城市选择弹层、旧城市简称规范化与支持性判断。
- `zhidi_app/lib/models/house_info.dart`：房屋字段值对象、范围校验和统一显示格式。
- `zhidi_app/lib/pages/renovation/house_info_page.dart`：工种确定后填写面积、室厅厨卫并确认地址。
- `zhidi_app/test/owner_city_picker_test.dart`：城市规范化和选择器组件测试。
- `zhidi_app/test/house_info_test.dart`：房屋信息校验与格式测试。
- `zhidi_app/test/house_info_page_test.dart`：房屋信息表单和重复提交防护测试。
- `zhidi_server/src/main/resources/db/migration/V24__service_request_house_info.sql`：只为 `service_requests` 增加五个可空列，不改写历史数据。
- `zhidi_server/src/test/java/com/zhidi/server/migration/ServiceRequestHouseInfoMigrationTest.java`：V24 数据保留与新列验证。

### 修改文件

- `zhidi_app/lib/data/owner_service_regions.dart`：增加按正式名/安全简称定位省市的方法。
- `zhidi_app/lib/pages/auth/onboarding_page.dart`：自由文本城市改为共享选择器。
- `zhidi_app/lib/pages/profile/edit_profile_page.dart`：自由文本城市改为共享选择器并处理未开放旧值。
- `zhidi_app/lib/services/service_request_api_client.dart`：请求和响应模型增加五个房屋字段。
- `zhidi_app/lib/services/owner_booking_api_client.dart`：旧直接预约请求与业主预约响应增加五个房屋字段。
- `zhidi_app/lib/services/worker_booking_api_client.dart`：工人预约模型增加五个房屋字段。
- `zhidi_app/lib/pages/renovation/trade_select_page.dart`：选择工种后先进入房屋信息页，成功后才创建需求。
- `zhidi_app/lib/pages/home/worker/candidate_picker_page.dart`：候选页顶部展示房屋摘要。
- `zhidi_app/lib/pages/home/my_home_page.dart`：需求卡和需求详情展示房屋摘要。
- `zhidi_app/lib/app/worker_models.dart`：`WorkerOrder` 保存结构化房屋信息并兼容旧本地 JSON。
- `zhidi_app/lib/app/worker_app_state.dart`：远程预约映射时不再把面积写为空字符串。
- `zhidi_app/lib/pages/worker/worker_home_page.dart`：待接单卡片显示房屋摘要。
- `zhidi_app/lib/pages/worker/order_detail_page.dart`：需求详情分别展示面积和户型。
- `zhidi_app/lib/pages/worker/quotation_form_page.dart`：报价页顶部展示房屋摘要。
- `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequest.java`：映射五列并提供只读 getter。
- `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestCreateRequest.java`：新请求字段与 Bean Validation。
- `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestResponse.java`：响应增加可空房屋字段。
- `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestService.java`：保存并映射房屋信息。
- `zhidi_server/src/main/java/com/zhidi/server/booking/BookingResponse.java`：候选/预约响应增加可空房屋字段。
- `zhidi_server/src/main/java/com/zhidi/server/booking/BookingService.java`：按 `serviceRequestId` 读取房屋信息后生成响应。
- 相关现有测试：只更新构造参数和增加明确断言，不弱化已有断言。

---

### Task 1: 共享所在城市选择能力

**Files:**
- Create: `zhidi_app/lib/pages/shared/owner_city_picker.dart`
- Modify: `zhidi_app/lib/data/owner_service_regions.dart`
- Test: `zhidi_app/test/owner_city_picker_test.dart`
- Test: `zhidi_app/test/owner_service_regions_test.dart`

**Interfaces:**
- Produces: `OwnerCitySelection(province, city)`、`OwnerServiceRegionCatalog.resolveCity(String?)`、`Future<OwnerCitySelection?> showOwnerCityPicker(BuildContext, {String? currentCity})`。
- Consumes: `OwnerServiceRegionCatalog.provinces` 与 `citiesFor(province)`。

- [ ] **Step 1: 写城市解析失败测试**

```dart
test('resolves official names and safe abbreviations only', () {
  expect(OwnerServiceRegionCatalog.resolveCity('成都市')?.city, '成都市');
  expect(OwnerServiceRegionCatalog.resolveCity('成都')?.city, '成都市');
  expect(OwnerServiceRegionCatalog.resolveCity('兰州')?.province, '甘肃省');
  expect(OwnerServiceRegionCatalog.resolveCity('杭州'), isNull);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/owner_city_picker_test.dart test/owner_service_regions_test.dart`

Expected: FAIL，提示 `resolveCity` 或 `OwnerCitySelection` 不存在。

- [ ] **Step 3: 实现正式名称和安全简称解析**

```dart
final class OwnerCitySelection {
  const OwnerCitySelection({required this.province, required this.city});
  final String province;
  final String city;
}

static OwnerCitySelection? resolveCity(String? raw) {
  final value = raw?.trim() ?? '';
  for (final province in provinces) {
    for (final city in citiesFor(province)) {
      if (value == city || value == city.replaceFirst(RegExp(r'[市州]$'), '')) {
        return OwnerCitySelection(province: province, city: city);
      }
    }
  }
  return null;
}
```

将值对象放在 `owner_service_regions.dart`；选择弹层放在共享页面文件，显示四川省/甘肃省和所属城市，城市列表带本地关键词过滤，返回正式城市名。

- [ ] **Step 4: 增加 Widget 测试并验证选择结果**

测试点击“四川省”后选择“成都市”返回 `OwnerCitySelection(province: '四川省', city: '成都市')`；搜索“兰州”后只显示“兰州市”。

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/owner_city_picker_test.dart test/owner_service_regions_test.dart`

Expected: PASS。

### Task 2: 首次资料与编辑资料接入同一城市选择器

**Files:**
- Modify: `zhidi_app/lib/pages/auth/onboarding_page.dart`
- Modify: `zhidi_app/lib/pages/profile/edit_profile_page.dart`
- Test: `zhidi_app/test/onboarding_page_test.dart`
- Test: `zhidi_app/test/owner_profile_ui_sync_test.dart`

**Interfaces:**
- Consumes: `showOwnerCityPicker(...)`、`OwnerServiceRegionCatalog.resolveCity(...)`。
- Produces: 两处都只向现有 `completeOnboarding(city:)` / `updateProfile(city:)` 提交正式城市名称。

- [ ] **Step 1: 把自由输入测试改为受控选择行为并先确认失败**

```dart
expect(
  tester.widget<TextFormField>(find.byKey(const Key('profile-city-field')))
      .readOnly,
  isTrue,
);
await tester.tap(find.byKey(const Key('profile-city-field')));
await tester.pumpAndSettle();
await tester.tap(find.text('四川省'));
await tester.tap(find.text('成都市'));
await tester.tap(find.text('保存'));
expect(api.lastRequest.city, '成都市');
```

同时增加：`成都` 回显为 `成都市`；`杭州` 显示“当前城市暂未开放”且保存按钮不可提交；保存失败后选择仍为 `成都市`。

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/onboarding_page_test.dart test/owner_profile_ui_sync_test.dart`

Expected: FAIL，因为当前仍可自由输入。

- [ ] **Step 2: 替换两处城市字段**

保留现有 key，字段设为 `readOnly: true`，点击调用共享选择器；选中后设置 controller 为正式城市名。初始化时只规范化安全简称，未知旧值保留原文并设置 `_unsupportedCity = true`。

```dart
Future<void> _pickCity() async {
  final result = await showOwnerCityPicker(
    context,
    currentCity: _cityController.text,
  );
  if (result == null || !mounted) return;
  setState(() {
    _cityController.text = result.city;
    _unsupportedCity = false;
  });
}
```

- [ ] **Step 3: 验证资料测试**

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/onboarding_page_test.dart test/owner_profile_ui_sync_test.dart test/owner_profile_state_sync_test.dart`

Expected: PASS，且现有姓名、性别、头像、失败保留测试继续通过。

### Task 3: V24 数据库迁移与服务请求领域模型

**Files:**
- Create: `zhidi_server/src/main/resources/db/migration/V24__service_request_house_info.sql`
- Create: `zhidi_server/src/test/java/com/zhidi/server/migration/ServiceRequestHouseInfoMigrationTest.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/servicerequest/ServiceRequestPersistenceTest.java`

**Interfaces:**
- Produces: `ServiceRequest.create(..., BigDecimal areaSqm, Short bedroomCount, Short livingRoomCount, Short kitchenCount, Short bathroomCount, String remark)` 与五个 getter。
- Consumes: 现有 `service_requests` 表和 `BaseEntity`。

- [ ] **Step 1: 写迁移和持久化失败测试**

迁移测试先插入一条 V23 结构的需求，再执行 V24，断言旧记录仍存在且五列为 `NULL`。持久化测试保存 `98.50, 3, 2, 1, 2` 后重新读取并逐项相等。

Run: `cd zhidi_server && MAVEN_USER_HOME=../.m2 ./mvnw -Dtest=ServiceRequestHouseInfoMigrationTest,ServiceRequestPersistenceTest test -Dmaven.repo.local=../.m2/repository -s ../.m2/settings.xml`

Expected: FAIL，因为 V24 和实体字段尚不存在。

- [ ] **Step 2: 新增非破坏性迁移**

```sql
ALTER TABLE service_requests
  ADD COLUMN area_sqm DECIMAL(8,2) NULL,
  ADD COLUMN bedroom_count SMALLINT NULL,
  ADD COLUMN living_room_count SMALLINT NULL,
  ADD COLUMN kitchen_count SMALLINT NULL,
  ADD COLUMN bathroom_count SMALLINT NULL;
```

V24 只增加可空列，不添加 CHECK 和触发器；新数据范围由 Java Bean Validation 与领域构造器双重保证，避免 MySQL 版本差异影响生产迁移。

- [ ] **Step 3: 映射实体字段并验证**

使用 `BigDecimal` 映射 `area_sqm`，数量使用 `Short`；构造器允许全空仅用于历史/既有调用兼容，但公共新建工厂的完整重载校验五项必须同时存在且范围正确。

Run: `cd zhidi_server && MAVEN_USER_HOME=../.m2 ./mvnw -Dtest=ServiceRequestHouseInfoMigrationTest,ServiceRequestPersistenceTest test -Dmaven.repo.local=../.m2/repository -s ../.m2/settings.xml`

Expected: PASS。

### Task 4: 服务请求 API 校验、保存与预约响应传播

**Files:**
- Modify: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestCreateRequest.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestResponse.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/servicerequest/ServiceRequestService.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingResponse.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingService.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/servicerequest/ServiceRequestControllerTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/servicerequest/ServiceRequestIntegrationTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/servicerequest/ServiceRequestServiceTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/booking/BookingControllerTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/booking/BookingServiceIntegrationTest.java`

**Interfaces:**
- Produces: 创建 JSON 的 `areaSqm`, `bedroomCount`, `livingRoomCount`, `kitchenCount`, `bathroomCount`；服务请求与预约响应同名可空字段。
- Consumes: Task 3 的实体 getter 和 `ServiceRequestRepository.findById(UUID)`。

- [ ] **Step 1: 写 API 合同失败测试**

```java
new ServiceRequestCreateRequest(
  "painting", "成都市", "四川省成都市武侯区科华路1号",
  new BigDecimal("98.50"), (short) 3, (short) 2, (short) 1, (short) 2, null)
```

测试完整请求返回 201/200 并回显五项；缺面积、面积 0/10000、卧室 0、客厅 11、厨房 11、卫生间 0 均返回 400；旧库空字段读取仍为 200 和 JSON `null`。

Run: `cd zhidi_server && MAVEN_USER_HOME=../.m2 ./mvnw -Dtest=ServiceRequestControllerTest,ServiceRequestIntegrationTest test -Dmaven.repo.local=../.m2/repository -s ../.m2/settings.xml`

Expected: FAIL，当前请求/响应没有字段。

- [ ] **Step 2: 增加 Bean Validation 与响应字段**

```java
@NotNull @DecimalMin("1.00") @DecimalMax("9999.00") @Digits(integer = 4, fraction = 2)
BigDecimal areaSqm,
@NotNull @Min(1) @Max(20) Short bedroomCount,
@NotNull @Min(0) @Max(10) Short livingRoomCount,
@NotNull @Min(0) @Max(10) Short kitchenCount,
@NotNull @Min(1) @Max(20) Short bathroomCount
```

`ServiceRequestService.createRequest` 将字段传入实体；`toResponse` 原样返回。

- [ ] **Step 3: 预约响应从关联需求读取房屋信息**

在 `BookingService.toResponse` 和 `ServiceRequestService.bookingToResponse` 中读取同一 `ServiceRequest`；禁止给 bookings 表加房屋列。

```java
private ServiceRequest houseInfoSource(Booking booking) {
  return serviceRequests.findById(booking.getServiceRequestId()).orElse(null);
}
```

构造 `BookingResponse` 时，关联需求存在则映射五项；不存在或历史为空则返回 `null`。集成测试断言工人 `GET /api/v1/workers/me/bookings` 与业主候选响应得到相同数据。

- [ ] **Step 4: 运行后端聚焦测试**

Run: `cd zhidi_server && MAVEN_USER_HOME=../.m2 ./mvnw -Dtest=ServiceRequestControllerTest,ServiceRequestIntegrationTest,ServiceRequestServiceTest,BookingControllerTest,BookingServiceIntegrationTest test -Dmaven.repo.local=../.m2/repository -s ../.m2/settings.xml`

Expected: PASS。

### Task 5: Flutter 房屋值对象与网络模型

**Files:**
- Create: `zhidi_app/lib/models/house_info.dart`
- Modify: `zhidi_app/lib/services/service_request_api_client.dart`
- Modify: `zhidi_app/lib/services/owner_booking_api_client.dart`
- Modify: `zhidi_app/lib/services/worker_booking_api_client.dart`
- Test: `zhidi_app/test/house_info_test.dart`
- Test: `zhidi_app/test/owner_booking_api_client_test.dart`
- Test: `zhidi_app/test/owner_booking_state_sync_test.dart`
- Test: `zhidi_app/test/worker_booking_api_client_test.dart`

**Interfaces:**
- Produces: `HouseInfo(areaSqm, bedroomCount, livingRoomCount, kitchenCount, bathroomCount)`、`HouseInfo? houseInfo` getters、`areaLabel`、`layoutLabel`、`summaryLabel`。
- Consumes: 后端 Task 4 的同名 JSON 字段。

- [ ] **Step 1: 写值对象和 JSON 合同失败测试**

```dart
const info = HouseInfo(
  areaSqm: 98.5,
  bedroomCount: 3,
  livingRoomCount: 2,
  kitchenCount: 1,
  bathroomCount: 2,
);
expect(info.areaLabel, '98.5㎡');
expect(info.layoutLabel, '3室2厅1厨2卫');
expect(info.summaryLabel, '98.5㎡ · 3室2厅1厨2卫');
```

并断言 `ServiceRequestDraft.toJson()` 五项齐全，`RemoteServiceRequest`、`RemoteOwnerBooking`、`RemoteWorkerBooking` 缺字段时 `houseInfo == null`。

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/house_info_test.dart test/owner_booking_api_client_test.dart test/owner_booking_state_sync_test.dart test/worker_booking_api_client_test.dart`

Expected: FAIL，模型尚不存在。

- [ ] **Step 2: 实现值对象与解析**

`HouseInfo.tryFromJson` 只在五项都合法时返回对象；五项全空返回 `null`；部分缺失也返回 `null`，避免向用户展示不完整户型。`ServiceRequestDraft` 新建构造函数要求 `houseInfo`；三个远程响应模型都使用可空 `houseInfo`。

- [ ] **Step 3: 运行网络模型测试**

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/house_info_test.dart test/owner_booking_api_client_test.dart test/owner_booking_state_sync_test.dart test/worker_booking_api_client_test.dart`

Expected: PASS。

### Task 6: 房屋信息表单与创建需求顺序

**Files:**
- Create: `zhidi_app/lib/pages/renovation/house_info_page.dart`
- Modify: `zhidi_app/lib/pages/renovation/trade_select_page.dart`
- Test: `zhidi_app/test/house_info_page_test.dart`
- Test: `zhidi_app/test/trade_select_page_visual_test.dart`

**Interfaces:**
- Produces: `HouseInfoPageResult(HouseInfo houseInfo)`；成功创建后的 `RemoteServiceRequest` 继续交给 `CandidatePickerPage`。
- Consumes: `OwnerAddress.fullAddress`、Task 5 的 `HouseInfo` 和 `ServiceRequestDraft.houseInfo`。

- [ ] **Step 1: 写流程失败测试**

测试选择油漆工种后：没有默认地址先去地址管理；有地址时先看到“房屋面积与户型”；未填写面积时 API 调用数为 0；填写 `98.5`、确认默认 `3/2/1/2` 后 API 调用恰好 1 次；API 失败时仍停在表单且面积未清空；快速双击只创建一次需求。

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/house_info_page_test.dart test/trade_select_page_visual_test.dart`

Expected: FAIL，当前选择工种后直接创建需求。

- [ ] **Step 2: 实现房屋信息页面**

面积使用带 `FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}(\.\d{0,2})?'))` 的数字输入；四项使用带上下限的步进按钮。页面固定显示所选工种、默认上门地址和按钮“确认并选择师傅”。

```dart
final result = await Navigator.push<HouseInfoPageResult>(
  context,
  MaterialPageRoute(
    builder: (_) => HouseInfoPage(tradeLabel: label, address: address),
  ),
);
if (result == null) return;
final draft = ServiceRequestDraft(
  trade: apiTrade,
  serviceCity: address.city,
  serviceAddress: address.fullAddress,
  houseInfo: result.houseInfo,
);
```

- [ ] **Step 3: 将创建请求的加载状态放在房屋页面**

通过 `HouseInfoPage` 接受 `Future<void> Function(HouseInfo)` 提交回调，按钮等待服务器成功后才返回；异常在本页显示“创建需求失败，请重试”，保证字段不丢失且不会重复提交。

- [ ] **Step 4: 验证流程测试**

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/house_info_page_test.dart test/trade_select_page_visual_test.dart test/candidate_picker_page_test.dart`

Expected: PASS。

### Task 7: 业主候选与“我的家”显示一致房屋信息

**Files:**
- Modify: `zhidi_app/lib/pages/home/worker/candidate_picker_page.dart`
- Modify: `zhidi_app/lib/pages/home/my_home_page.dart`
- Test: `zhidi_app/test/candidate_picker_page_test.dart`
- Test: `zhidi_app/test/my_home_minimal_page_test.dart`

**Interfaces:**
- Consumes: `RemoteServiceRequest.houseInfo` 或显式传入的 `HouseInfo?`。
- Produces: 候选页头部、需求卡、需求详情统一使用 `houseInfo?.summaryLabel ?? '房屋信息未填写'`。

- [ ] **Step 1: 写业主展示失败测试**

候选页面传入 `98.5㎡ · 3室2厅1厨2卫` 后断言只显示一次；“我的家”同一远程需求卡和详情均显示该摘要；历史空字段显示“房屋信息未填写”。

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/candidate_picker_page_test.dart test/my_home_minimal_page_test.dart`

Expected: FAIL，页面尚未展示。

- [ ] **Step 2: 修改候选页构造参数与头部**

`CandidatePickerPage` 新增 `HouseInfo? houseInfo`，在工种/城市摘要下显示一行房屋摘要，不挤压现有筛选排序按钮；320px 宽度下使用 `Wrap`/`Expanded` 防溢出。

- [ ] **Step 3: 修改“我的家”卡片与详情**

所有展示从 `RemoteServiceRequest.houseInfo` 读取；工种去重逻辑保持不变，不把默认户型写入历史需求。

- [ ] **Step 4: 验证业主页面测试**

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/candidate_picker_page_test.dart test/my_home_minimal_page_test.dart`

Expected: PASS。

### Task 8: 工人订单模型、待接单、详情与报价页面贯通

**Files:**
- Modify: `zhidi_app/lib/app/worker_models.dart`
- Modify: `zhidi_app/lib/app/worker_app_state.dart`
- Modify: `zhidi_app/lib/pages/worker/worker_home_page.dart`
- Modify: `zhidi_app/lib/pages/worker/order_detail_page.dart`
- Modify: `zhidi_app/lib/pages/worker/quotation_form_page.dart`
- Test: `zhidi_app/test/worker_booking_flow_test.dart`
- Test: `zhidi_app/test/worker_order_detail_refresh_test.dart`
- Test: `zhidi_app/test/worker_quotation_form_page_test.dart`
- Test: `zhidi_app/test/worker_session_state_test.dart`

**Interfaces:**
- Consumes: `RemoteWorkerBooking.houseInfo`。
- Produces: `WorkerOrder.houseInfo` 与 `houseSummary`，本地旧 JSON 没有该字段时保持可读取。

- [ ] **Step 1: 写远程映射和三页展示失败测试**

构造带 `HouseInfo(98.5, 3, 2, 1, 2)` 的远程预约，断言映射后的订单摘要为 `98.5㎡ · 3室2厅1厨2卫`；待接单卡、订单详情、报价页均显示；历史空字段显示“房屋信息未填写”，不显示空的“面积：”行。

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/worker_booking_flow_test.dart test/worker_order_detail_refresh_test.dart test/worker_quotation_form_page_test.dart test/worker_session_state_test.dart`

Expected: FAIL，当前远程映射把 `area` 写为 `''`。

- [ ] **Step 2: 为 WorkerOrder 增加兼容字段**

新增 `HouseInfo? houseInfo`；`toJson` 写入 `houseInfo?.toJson()`，`fromJson` 缺少时读取旧 `area` 文本但不伪造室厅厨卫。保留旧 `area` getter/构造参数到现有调用迁移完毕，避免破坏大量本地测试数据。

- [ ] **Step 3: 修改远程映射和页面**

`_remoteBookingToOrder` 直接传入 `rb.houseInfo`。待接单卡显示“需要油漆师傅”并在下一行显示摘要；订单详情将“面积”和“户型”分两行；报价页标题下显示摘要及“请按现场实际情况报价”。

- [ ] **Step 4: 验证工人页面测试**

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/worker_booking_flow_test.dart test/worker_order_detail_refresh_test.dart test/worker_quotation_form_page_test.dart test/worker_session_state_test.dart`

Expected: PASS。

### Task 9: 兼容旧直接预约入口，杜绝无房屋信息的新订单

**Files:**
- Modify: `zhidi_app/lib/app/owner_app_state.dart`
- Modify: `zhidi_app/lib/pages/renovation/worker_detail_page.dart`
- Modify: `zhidi_app/lib/services/owner_booking_api_client.dart`
- Modify: `zhidi_app/test/worker_detail_remote_booking_test.dart`
- Modify: `zhidi_app/test/owner_booking_api_client_test.dart`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingRequest.java`
- Modify: `zhidi_server/src/main/java/com/zhidi/server/booking/BookingService.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/booking/BookingControllerTest.java`
- Test: `zhidi_server/src/test/java/com/zhidi/server/booking/BookingServiceIntegrationTest.java`

**Interfaces:**
- Consumes: Task 6 的房屋信息页面和 Task 3 的完整 `ServiceRequest.create`。
- Produces: 旧 `/api/v1/bookings` 新建入口也要求五项房屋字段，避免旧客户端或详情页生成无户型的新需求。

- [ ] **Step 1: 写直接预约失败测试**

Flutter 测试断言详情页点击“立即预约”后先出现房屋信息页，未填写不调用预约 API；后端测试断言缺任一房屋字段返回 400，完整字段创建的 service request 与 booking 响应均带相同房屋信息。

- [ ] **Step 2: 扩展 BookingRequest 与业主请求模型**

使用与 `ServiceRequestCreateRequest` 完全相同的 Bean Validation 范围；Flutter `OwnerBookingCreateRequest` 序列化同名五字段。

- [ ] **Step 3: 详情页复用房屋信息页面**

从当前默认地址和师傅工种进入同一个 `HouseInfoPage`；把结果传入 `OwnerAppState.bookWorker(..., houseInfo:)`。`BookingService.create` 自动创建 service request 时必须传入五项；复用已有 OPEN 请求前校验其房屋信息完整且与本次输入一致，否则创建新请求，避免把不同房屋需求错误合并。

- [ ] **Step 4: 验证直接预约入口**

Run: `cd zhidi_server && MAVEN_USER_HOME=../.m2 ./mvnw -Dtest=BookingControllerTest,BookingServiceIntegrationTest test -Dmaven.repo.local=../.m2/repository -s ../.m2/settings.xml`

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test test/worker_detail_remote_booking_test.dart`

Expected: 两组均 PASS。

### Task 10: 全量回归、项目状态、构建与双模拟器验收

**Files:**
- Modify: `PROJECT_STATUS.md`
- Output: `zhidi_app/output/apks/zhidi-owner-debug-20260802-house-info.apk`
- Output: `zhidi_app/output/apks/zhidi-worker-debug-20260802-house-info.apk`
- Evidence: `zhidi_app/output/evidence/owner-house-info-flow-20260802.png`
- Evidence: `zhidi_app/output/evidence/worker-house-info-order-20260802.png`

**Interfaces:**
- Consumes: Tasks 1–9 的完整功能。
- Produces: 可复验 APK、测试结果和精简项目状态记录。

- [ ] **Step 1: 运行后端全量测试**

Run: `cd zhidi_server && MAVEN_USER_HOME=../.m2 ./mvnw test -Dmaven.repo.local=../.m2/repository -s ../.m2/settings.xml`

Expected: `BUILD SUCCESS`，0 failures，0 errors。

- [ ] **Step 2: 运行 Flutter 静态检查和全量测试**

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter analyze`

Expected: `No issues found!`

Run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test --reporter compact`

Expected: All tests passed；项目原有明确 skip 保持原状。

- [ ] **Step 3: 更新 PROJECT_STATUS.md**

只记录已经由测试验证的事实：两处城市选择器、V24 房屋字段、双端展示、历史兼容和最新测试数字；仍未部署/未真机验证的内容不得写成已完成。

- [ ] **Step 4: 备份并部署后端**

在 ECS 部署前分别备份当前 `/opt/zhidi/zhidi-server.jar` 和 MySQL 数据库；确认备份文件非空后才替换 JAR。重启后检查 `/actuator/health`、`/v3/api-docs` 和真实创建/读取接口；若任一步失败，恢复备份 JAR，不删除数据库数据。

- [ ] **Step 5: 构建双端 APK**

Owner run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter build apk --debug --flavor owner --dart-define=ZHIDI_APP_FLAVOR=owner --dart-define=API_BASE_URL=http://47.109.0.191:8080`

Worker run: `cd zhidi_app && HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter build apk --debug --dart-define=ZHIDI_APP_FLAVOR=worker --dart-define=API_BASE_URL=http://47.109.0.191:8080`

复制成计划指定的两个输出文件，并记录 SHA-256。

- [ ] **Step 6: 双模拟器真实闭环验收**

业主端选择“成都市”，选择油漆工种，填写 `98.5㎡、3室2厅1厨2卫`，创建需求并邀请测试工人；工人端必须在待接单卡、订单详情和报价页看到完全相同信息。业主候选页和“我的家”也必须显示相同摘要；保存两张证据截图。

- [ ] **Step 7: 精确清理本轮测试数据**

只删除本轮记录下来的测试手机号、service request ID、booking ID 及其从属报价/消息数据；执行前后分别查询并记录数量，不使用全表清空，不影响其他账号。

---

## Self-Review Result

- Spec coverage: 城市受控选择、简称/未知旧值、房屋字段校验、V24、服务请求/预约响应、业主三处展示、工人三处展示、历史兼容、失败保留、部署与清理均有对应任务。
- Placeholder scan: 文档无 `TBD`、`TODO`、“类似 Task N”或未定义接口；部署步骤明确以现有 ECS 备份/健康/实际 API 为门槛。
- Type consistency: 服务端与 Flutter 均固定使用 `areaSqm`, `bedroomCount`, `livingRoomCount`, `kitchenCount`, `bathroomCount`；Flutter 页面和响应统一使用 `HouseInfo`。
- Additional path audit: 已单列 Task 9 覆盖旧 `/api/v1/bookings` 直接预约入口，避免主流程修复后仍产生缺房屋信息的新订单。
