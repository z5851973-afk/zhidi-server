# 业主地址省市区三级联动 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将业主地址表单改为仅开放四川省、甘肃省的省市区三级联动选择，并保证两省正式县级行政区完整、组合合法且旧地址安全兼容。

**Architecture:** 新建独立的不可变行政区划目录，向页面提供按上级查询和组合校验；地址表单只保存选中的正式名称。选择交互由一个可复用的搜索底部面板完成，保存仍复用现有 `OwnerAddress` 和服务端 API，不改后端协议或数据库。

**Tech Stack:** Flutter、Dart、Material 3、`flutter_test`。

## Global Constraints

- 首期只开放四川省和甘肃省。
- 四川省必须包含 21 个市（州）、183 个县（市、区）。
- 甘肃省必须包含 14 个市（州）、86 个县（市、区）。
- 不把开发区、高新区、园区或兰州新区作为县级行政区重复加入。
- 不修改后端 JSON、数据库结构或历史地址记录。
- 网络保存失败必须保留表单状态，不允许本地假成功。
- 当前工作区已有大量用户改动；只修改本计划列出的文件，不回退其他改动，不自动提交。

---

### Task 1: 两省行政区划目录与合法性验证

**Files:**
- Create: `zhidi_app/lib/data/owner_service_regions.dart`
- Create: `zhidi_app/test/owner_service_regions_test.dart`

**Interfaces:**
- Produces: `OwnerServiceRegionCatalog.provinces`、`citiesFor(String province)`、`districtsFor(String province, String city)`、`contains(String province, String city, String district)`。
- Consumes: 无；目录是纯 Dart 不可变数据。

- [ ] **Step 1: 写目录失败测试**

```dart
test('only opens Sichuan and Gansu with complete official counts', () {
  expect(OwnerServiceRegionCatalog.provinces, ['四川省', '甘肃省']);
  expect(OwnerServiceRegionCatalog.citiesFor('四川省'), hasLength(21));
  expect(
    OwnerServiceRegionCatalog.citiesFor('四川省')
        .expand((city) => OwnerServiceRegionCatalog.districtsFor('四川省', city))
        .length,
    183,
  );
  expect(OwnerServiceRegionCatalog.citiesFor('甘肃省'), hasLength(14));
  expect(
    OwnerServiceRegionCatalog.citiesFor('甘肃省')
        .expand((city) => OwnerServiceRegionCatalog.districtsFor('甘肃省', city))
        .length,
    86,
  );
});

test('rejects cross-province and non-administrative combinations', () {
  expect(OwnerServiceRegionCatalog.contains('四川省', '成都市', '武侯区'), isTrue);
  expect(OwnerServiceRegionCatalog.contains('甘肃省', '兰州市', '城关区'), isTrue);
  expect(OwnerServiceRegionCatalog.contains('四川省', '兰州市', '城关区'), isFalse);
  expect(OwnerServiceRegionCatalog.contains('甘肃省', '兰州市', '兰州新区'), isFalse);
});
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `cd zhidi_app && flutter test test/owner_service_regions_test.dart`

Expected: FAIL，提示 `owner_service_regions.dart` 或 `OwnerServiceRegionCatalog` 不存在。

- [ ] **Step 3: 实现不可变目录**

```dart
abstract final class OwnerServiceRegionCatalog {
  static const provinces = ['四川省', '甘肃省'];

  static List<String> citiesFor(String province) =>
      List.unmodifiable(_regions[province]?.keys ?? const <String>[]);

  static List<String> districtsFor(String province, String city) =>
      List.unmodifiable(_regions[province]?[city] ?? const <String>[]);

  static bool contains(String province, String city, String district) =>
      _regions[province]?[city]?.contains(district) ?? false;

  static const Map<String, Map<String, List<String>>> _regions = {
    // 按官方正式名称列出四川、甘肃全量市州和县级行政区。
  };
}
```

录入后逐市核对，确保没有重复县区名称、空列表和开发区类条目。

- [ ] **Step 4: 运行目录测试确认 GREEN**

Run: `cd zhidi_app && flutter test test/owner_service_regions_test.dart`

Expected: PASS，四川 `21/183`、甘肃 `14/86`，合法与非法组合断言全部通过。

- [ ] **Step 5: 复核目录完整性**

Run: `cd zhidi_app && dart format lib/data/owner_service_regions.dart test/owner_service_regions_test.dart && flutter analyze lib/data/owner_service_regions.dart test/owner_service_regions_test.dart`

Expected: 格式化完成且 `No issues found!`。

---

### Task 2: 地址表单三级联动与搜索选择面板

**Files:**
- Modify: `zhidi_app/lib/pages/profile/address_page.dart:319-478`
- Modify: `zhidi_app/test/address_page_test.dart`

**Interfaces:**
- Consumes: Task 1 的 `OwnerServiceRegionCatalog` 四个公开接口。
- Produces: key 为 `address-province`、`address-city`、`address-district` 的只读选择控件，以及 key 为 `region-search` 的搜索框。

- [ ] **Step 1: 写联动与搜索失败测试**

```dart
testWidgets('selects province city district without text keyboard', (tester) async {
  final state = await buildState(FakeAddressApi([]));
  await pumpAddressPage(tester, state);
  await tester.tap(find.text('新增地址'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('address-province')));
  await tester.pumpAndSettle();
  expect(find.text('四川省'), findsOneWidget);
  expect(find.text('甘肃省'), findsOneWidget);
  await tester.tap(find.text('四川省'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('address-city')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('region-search')), '成都');
  await tester.pump();
  expect(find.text('成都市'), findsOneWidget);
  await tester.tap(find.text('成都市'));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('address-district')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('武侯区'));
  await tester.pumpAndSettle();
  expect(find.text('武侯区'), findsOneWidget);
});

testWidgets('changing a parent clears invalid child selections', (tester) async {
  // 先选择四川省/成都市/武侯区，再把省份改为甘肃省。
  // 表单必须显示甘肃省，城市和区县恢复为“请选择”。
});
```

- [ ] **Step 2: 运行两个 Widget 测试确认 RED**

Run: `cd zhidi_app && flutter test test/address_page_test.dart --plain-name 'selects province city district without text keyboard'`

Expected: FAIL，因为三个字段仍是自由输入框，没有选择面板。

- [ ] **Step 3: 实现只读选择框**

将 `_province/_city/_district` 改为可空字符串状态；联系人、电话和详细地址仍使用控制器。增加 `_regionField`：

```dart
Widget _regionField({
  required Key key,
  required String label,
  required String? value,
  required VoidCallback? onTap,
  String? supportingText,
}) => FormField<String>(
  key: key,
  initialValue: value,
  validator: (_) => value == null || value.isEmpty ? '请选择$label' : null,
  builder: (field) => InkWell(
    onTap: _saving ? null : onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        errorText: field.errorText,
        helperText: supportingText,
        suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
      ),
      child: Text(value?.isNotEmpty == true ? value! : '请选择$label'),
    ),
  ),
);
```

省份变化执行 `_city = null; _district = null;`，城市变化执行 `_district = null;`。未选省份或城市点击下级时显示中文 SnackBar。

- [ ] **Step 4: 实现可搜索底部选择面板**

```dart
Future<String?> _showRegionPicker({
  required String title,
  required List<String> options,
  String? selected,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _RegionPickerSheet(
    title: title,
    options: options,
    selected: selected,
  ),
);
```

`_RegionPickerSheet` 内部持有搜索控制器，按 `option.contains(keyword.trim())` 筛选；当前项显示 `Icons.check_rounded`，空结果显示“没有匹配的地区”。

- [ ] **Step 5: 更新现有填表助手并跑测试确认 GREEN**

`fillAddressForm` 改为点击并选择“四川省 → 成都市 → 武侯区”，不再向省市区 `enterText`。

Run: `cd zhidi_app && flutter test test/address_page_test.dart`

Expected: 地址新增、失败保留、默认地址、删除和新增联动测试全部 PASS。

---

### Task 3: 旧地址兼容与提交前强校验

**Files:**
- Modify: `zhidi_app/lib/pages/profile/address_page.dart:319-478`
- Modify: `zhidi_app/test/address_page_test.dart`

**Interfaces:**
- Consumes: `OwnerServiceRegionCatalog.contains(...)`。
- Produces: 合法旧地址自动回显；未开放/错配旧地址显示原值和“当前地区暂未开放”，且不能提交。

- [ ] **Step 1: 写旧地址失败测试**

```dart
testWidgets('shows but blocks an out-of-scope legacy address', (tester) async {
  final api = FakeAddressApi([
    remoteAddress(
      id: 'legacy',
      isDefault: true,
      province: '广东省',
      city: '深圳市',
      district: '南山区',
    ),
  ]);
  final state = await buildState(api);
  await pumpAddressPage(tester, state);
  await tester.tap(find.byKey(const Key('edit-legacy')));
  await tester.pumpAndSettle();
  expect(find.text('广东省'), findsOneWidget);
  expect(find.text('当前地区暂未开放'), findsOneWidget);
  await tester.tap(find.widgetWithText(FilledButton, '保存地址'));
  await tester.pump();
  expect(api.updates, isEmpty);
});
```

- [ ] **Step 2: 运行测试确认 RED**

Run: `cd zhidi_app && flutter test test/address_page_test.dart --plain-name 'shows but blocks an out-of-scope legacy address'`

Expected: FAIL，因为现有页面不会标记未开放地址，Fake API 也尚未记录 update。

- [ ] **Step 3: 实现旧地址状态和最终组合校验**

初始化时保留旧省市区文字，并用 `contains` 计算 `_legacyRegionUnsupported`。用户重新选择省份后清除该标记；`_save` 在构造 `OwnerAddress` 前再次检查 `contains`，不合法时显示“请选择已开放且匹配的省市区”并返回。

- [ ] **Step 4: 扩展 Fake API 并确认 GREEN**

给 `FakeAddressApi` 增加 `final List<OwnerAddressDraft> updates = [];`，在 `update` 中记录传入草稿，使测试验证真实提交边界而不是页面私有状态。

Run: `cd zhidi_app && flutter test test/address_page_test.dart`

Expected: 合法编辑可提交，未开放旧地址不可提交，失败重试仍保留所有字段。

---

### Task 4: 全量验证、模拟器复验与项目状态更新

**Files:**
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- Consumes: Tasks 1-3 的完整功能。
- Produces: 可复验的测试结果和项目状态说明。

- [ ] **Step 1: 格式化并静态检查**

Run: `cd zhidi_app && dart format lib/data/owner_service_regions.dart lib/pages/profile/address_page.dart test/owner_service_regions_test.dart test/address_page_test.dart && flutter analyze`

Expected: `No issues found!`。

- [ ] **Step 2: 运行 Flutter 全量测试**

Run: `cd zhidi_app && flutter test`

Expected: 所有非显式跳过测试 PASS，无新增失败。

- [ ] **Step 3: 构建并安装业主端调试 APK**

Run: `cd zhidi_app && flutter build apk --debug`

Expected: 生成 `build/app/outputs/flutter-apk/app-debug.apk`；安装至业主模拟器后可启动。

- [ ] **Step 4: 模拟器手工复验两条地址**

四川路径：`四川省 → 成都市 → 武侯区`；甘肃路径：`甘肃省 → 兰州市 → 城关区`。分别验证选择、搜索、保存失败保留、窄屏无溢出、无红屏和无 Flutter 异常。

- [ ] **Step 5: 更新项目现状**

在 `PROJECT_STATUS.md` 只记录已通过验证的能力：业主地址支持四川/甘肃三级联动、目录数量、旧地址兼容策略、测试命令和验证结果；不记录临时调试过程。

---

## Self-Review

- Spec coverage: 两省范围、完整数量、受控选择、搜索、父级清空、旧地址、保存校验、失败保留、模拟器验证均有对应任务。
- Placeholder scan: 无 TBD/TODO；全量行政区名称由 Task 1 按官方资料录入，并由固定数量和代表性组合测试锁定。
- Type consistency: 所有任务统一使用 `OwnerServiceRegionCatalog`、`citiesFor`、`districtsFor`、`contains`；Widget key 与测试一致。
- Mutation check: 删除县区、错误跨省归属、漏清子级、允许旧地址提交、搜索不生效、网络失败清空状态都会触发至少一项测试失败。
