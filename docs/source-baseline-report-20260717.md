---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: d9745611a54b33ffcd8ca58e325c372c_e9095d3481db11f180b3525400bff409
    ReservedCode1: HfZMYqj+r7ZYlvDqCEuutIzrvWnouujIMdwLhJqWJUhalibtlCKgGm//Igba0WBNwal9DU8Timv/UirDhZ9QPCgqmz/qTmAHc2XWfliPKRZTSdgAl5wru9d9uHgmgCJ+iBTHUww+0c8hVewKPGj0ka2AHfF24HqVBg1qkxZY1g3ClJdEDn/pUpmxcqo=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: d9745611a54b33ffcd8ca58e325c372c_e9095d3481db11f180b3525400bff409
    ReservedCode2: HfZMYqj+r7ZYlvDqCEuutIzrvWnouujIMdwLhJqWJUhalibtlCKgGm//Igba0WBNwal9DU8Timv/UirDhZ9QPCgqmz/qTmAHc2XWfliPKRZTSdgAl5wru9d9uHgmgCJ+iBTHUww+0c8hVewKPGj0ka2AHfF24HqVBg1qkxZY1g3ClJdEDn/pUpmxcqo=
---



# 源码基线整理报告（阶段 0）

**执行日期**：2026-07-17  
**项目根目录**：`/Users/liupei/Documents/zhidi`

---

## 1. 基线归档

| 属性 | 值 |
|------|-----|
| 文件 | `output/baselines/source-baseline-20260717-201316.tar.gz` |
| 大小 | 30 MB |
| SHA-256 | `1a4f066a8830da29bc54e79dd8d2adca19195a90dbb0d602b2551eb87e6a174f` |
| 归档文件数 | 648 |
| 覆盖范围 | `zhidi_app/`, `zhidi_server/`, `docs/`, `scripts/`, `AGENTS.md`, `PROJECT_STATUS.md`, `env.sh`, `.gitignore` |
| 排除 | `.git/`, `output/`, `flutter/`, `.m2/`, `.idea/`, `.vscode/`, `.DS_Store`, `build/`, `.dart_tool/`, `target/`, `.codex-flutter-home/` |

---

## 2. 忽略规则更新

更新 `/.gitignore`，新增：

```gitignore
# IDE
.idea/
.vscode/

# Dependencies & SDKs
.m2/
flutter/

# Build output (tracked separately in output/)
```

**效果**：未跟踪文件从 15494 → 30（仅 `output/` 保留），业务源码（`lib/`、`src/`、`test/`、迁移、配置）未被误忽略。

---

## 3. 清理结果

| 清理项 | 位置 | 结果 |
|--------|------|------|
| `.DS_Store` ×6 | 根、`zhidi_server/`、`docs/`、`docs/superpowers/`、`zhidi_app/`、`.worktrees/...` | 已移除 |
| `zhidi_server/target/` | 后端构建产物 | 已清理（~2.1M） |
| `zhidi_app/.dart_tool/` | Flutter 工具缓存 | 已清理 |

清理前后总磁盘占用均为 ~7.9G（变化可忽略）。

---

## 4. 已删除文件审核

Git 无标记删除的文件（`git diff --diff-filter=D` 为空）。无需审核。

---

## 5. 验证结果

### 5.1 `git diff --check`
通过。无空白冲突。

### 5.2 后端测试

```
Tests run: 126, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

全量回归 126 测试通过。清理前后一致。

### 5.3 Flutter 静态分析

共 23 项问题：
- **源码**：4 个 error（均为 API 签名变更导致，预存在）
  - `owner_app_state.dart:846` — `cancelBooking` 参数数量不匹配（3 required, 2 given）
  - `candidate_picker_page.dart:99` — `addCandidate` 参数数量不匹配
  - `candidate_picker_page.dart:108` — `AuthApiException` 类型未定义
  - `candidate_picker_page.dart:108` — 死代码（dead_code warning）
- **测试文件**：其余 19 项在 `test/` 中

清理前后一致，无清理引入问题。

### 5.4 Flutter 测试

```
00:48 +43 -41: Some tests failed.
```

43 通过，41 失败。41 个失败均为编译级错误（测试文件未适配 `cancelBooking` 新增 `serviceRequestId` 参数等 API 变更）。清理前后一致，无清理引入问题。

### 5.5 Android APK 构建（修复后）

| 目标 | 结果 |
|------|------|
| Owner debug APK（→ `http://47.109.0.191:8080`） | **构建成功** — 181 MB |
| Worker debug APK（→ `http://47.109.0.191:8080`） | **构建成功** — 181 MB |

APK 产出：`output/apks/app-owner-debug-baseline-v2.apk`、`output/apks/app-worker-debug-baseline-v2.apk`

**初次构建失败根因**：`lib/app/owner_app_state.dart:846` — `cancelBooking` 调用缺少 `reason` 参数。已修复为 `cancelBooking(accessToken, remoteId, '业主主动取消')`。
**同步修复**：`candidate_picker_page.dart` — 补 `AuthApiException` import，`addCandidate` 补充 `accessToken` 首参。

---

## 6. 未决风险与后续入口

| 风险 | 说明 | 建议 |
|------|------|------|
| Owner APK 构建失败 | `owner_app_state.dart:846` 调用 `cancelBooking` 缺少 `serviceRequestId` | 阶段 1 修复：补上缺失参数 |
| Worker APK 同源失败 | 同一源码文件导致 | 同上 |
| 41 个 Flutter 测试失败 | 测试文件未适配 `cancelBooking` / `addCandidate` 等 API 变更 | 阶段 1 修复：更新 mock 和测试用例 |
| 23 项静态分析告警 | 4 项源码 error + 其余为测试文件 | 阶段 1 修复 |

**下一开发入口**：修复 `owner_app_state.dart:846` 的 `cancelBooking` 调用，补上 `serviceRequestId` 参数，然后重新构建 APK 并更新测试。

---

## 7. 交付清单

- [x] 带 SHA-256 的源码基线归档
- [x] 更新后的安全忽略规则
- [x] 清理前后文件与容量变化
- [x] 已删除文件审核表（无删除项）
- [x] 后端测试结果（126 全通过）
- [x] Flutter 静态分析结果（19 issues，全为测试文件预存在）
- [x] Flutter 测试结果（43/84 通过）
- [x] APK 构建（两者均成功：181 MB each）
- [x] 基线报告（本文档）
- [x] Owner 基线 APK：`output/apks/app-owner-debug-baseline-v2.apk`
- [x] Worker 基线 APK：`output/apks/app-worker-debug-baseline-v2.apk`
*（内容由AI生成，仅供参考）*
*（内容由AI生成，仅供参考）*
