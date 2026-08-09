# 报价数量空值输入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 工人删除报价数量的最后一个数字后，输入框保持空白、展开和可继续输入，同时金额按零计算。

**Architecture:** 将目录项目的“是否选中”与“数值数量”解耦。父页面单独保存选中项目集合和有效数量，数量输入框保留自己的编辑文本，使空字符串可以作为合法的临时编辑状态存在。

**Tech Stack:** Flutter、Dart、flutter_test

## Global Constraints

- 删除最后一个字符后不自动补 `0`，不自动失焦。
- 空白数量按 `0` 参与小计和总价计算。
- 数量为空时项目保持勾选，只有明确取消勾选才收起数量输入框。
- 没有大于 `0` 的数量时禁止提交报价。
- 不修改后端接口和价格目录数据结构。
- 未经用户明确要求不创建 Git 提交。

---

### Task 1: 解耦报价项目选择与数量编辑状态

**Files:**
- Modify: `zhidi_app/lib/pages/worker/quotation_form_page.dart`
- Test: `zhidi_app/test/worker_quotation_form_page_test.dart`
- Modify: `PROJECT_STATUS.md`

**Interfaces:**
- Consumes: `CatalogItem.name`、`CatalogItem.unitPrice` 和现有 `ValueChanged<double>` 金额更新路径。
- Produces: 目录行显式的选中状态；数量输入框允许空字符串但向金额层提供 `0`。

- [ ] **Step 1: 写入失败的 Widget 回归测试**

  在 `worker_quotation_form_page_test.dart` 增加测试：勾选“门套安装”，将 `quote-qty-门套安装` 输入改为空字符串，断言输入框仍存在且文本为空、合计为 `¥0`、提交按钮禁用；再输入 `5`，断言输入框文本为 `5`、总价为 `¥1000`。

- [ ] **Step 2: 运行测试并确认按预期失败**

  Run: `flutter test test/worker_quotation_form_page_test.dart --plain-name "quantity input stays open and blank after deleting the last digit"`

  Expected: FAIL，因为当前空字符串触发数量归零，目录行被判定为未选中，输入框随即从组件树移除。

- [ ] **Step 3: 实现独立的选中状态和空值编辑状态**

  在报价页状态中增加选中项目集合；勾选时加入集合并将数量设为 `1`，取消勾选时同时移除集合和数量。目录行依据选中集合决定是否展开，数量变化允许保存 `0`。将 `_QtyStepper` 改为持有 `TextEditingController` 和 `FocusNode` 的有状态控件：空字符串时回调数量 `0` 但保留原始空文本；外部加减按钮更新控制器文本；非编辑状态的外部数值变化才同步到输入框。

- [ ] **Step 4: 运行聚焦测试并确认通过**

  Run: `flutter test test/worker_quotation_form_page_test.dart`

  Expected: 全部 PASS。

- [ ] **Step 5: 运行静态检查和相关回归测试**

  Run: `flutter analyze`

  Expected: 无新增 error 或 warning。

- [ ] **Step 6: 在工人模拟器复验**

  打开报价页，勾选一个项目，删除数量最后一个字符，确认输入框保持空白和焦点；输入新数量后确认小计、总价和提交按钮同步恢复。

- [ ] **Step 7: 更新项目状态**

  在 `PROJECT_STATUS.md` 仅记录已验证的数量空值编辑行为、测试结果和模拟器验证结果，不记录临时调试过程。
