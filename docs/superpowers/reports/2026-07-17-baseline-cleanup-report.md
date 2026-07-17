---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: d9745611a54b33ffcd8ca58e325c372c_5c3dbd0881b511f1bbe75254006c9bbf
    ReservedCode1: c5A3GaN4n141/zszYRK72D8m5Ilqa1AR2XZFvznC0llO0s5ku+ket526Sz0HvfsBg9vHgTt0eE7k/PjKC/kJ8YRFOdsoz4mIsfivv5lPuZJbNOAjwSfV9GQArSrnBeOl9UlSWGZBEvJHguWoeToFqaTS+4vI+F00FpQjI8y/RKZYS53U/9kDTtkEjHU=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: d9745611a54b33ffcd8ca58e325c372c_5c3dbd0881b511f1bbe75254006c9bbf
    ReservedCode2: c5A3GaN4n141/zszYRK72D8m5Ilqa1AR2XZFvznC0llO0s5ku+ket526Sz0HvfsBg9vHgTt0eE7k/PjKC/kJ8YRFOdsoz4mIsfivv5lPuZJbNOAjwSfV9GQArSrnBeOl9UlSWGZBEvJHguWoeToFqaTS+4vI+F00FpQjI8y/RKZYS53U/9kDTtkEjHU=
---

# 源码基线整理报告

**整理日期**：2026-07-17 15:49  
**归档编号**：20260717_154949  
**整理类型**：仅清理构建垃圾 / 补充忽略规则 / 不做业务变更

---

## 1. 归档产物

| 产物 | 路径 | 大小 |
|------|------|------|
| 源码基线归档 | `output/baselines/20260717_154949/source-baseline.tar.gz` | 135 MB |
| SHA-256 | `output/baselines/20260717_154949/source-baseline.tar.gz.sha256` | — |
| Git 状态快照 | `output/baselines/20260717_154949/git-status.txt` | 185 行 |
| Git diff 补丁 | `output/baselines/20260717_154949/git-diff.patch` | — |
| 未跟踪文件清单 | `output/baselines/20260717_154949/git-untracked.txt` | 23,812 行 |
| 已删除文件审核 | `output/baselines/20260717_154949/deleted-file-audit.md` | — |

归档包含：`zhidi_app/`、`zhidi_server/`、`docs/`、`scripts/`、`AGENTS.md`、`PROJECT_STATUS.md`、`env.sh`、`.gitignore`  
归档排除：`.git/`、`output/`、`flutter/`（仓库内 Flutter SDK）、`zhidi_app/build/`、`zhidi_app/.dart_tool/`、`zhidi_app/.codex-flutter-home/`、`zhidi_server/target/`、`.m2/`、`.DS_Store`

---

## 2. 清理前后对比

| 指标 | 清理前 | 清理后 | 变化 |
|------|--------|--------|------|
| 仓库磁盘占用（不含 .git/.m2） | 13 GB | 12 GB | -1 GB |
| Git 状态变更数 | 185 项 | 181 项 | -4 项 |
| .DS_Store 文件 | 14 个 | 0 个 | 全部清除 |

已删除内容：
- `zhidi_app/build/`（Flutter 构建产物，可重新生成）
- `zhidi_app/.dart_tool/`（Dart 工具缓存）
- `zhidi_app/.codex-flutter-home/`（临时 HOME 缓存）
- `zhidi_server/target/`（Maven 构建产物）
- 全部 `.DS_Store`

---

## 3. .gitignore 变更

### 根 `.gitignore` 新增
```
# System
**/.DS_Store

# Temporary caches
**/.codex-flutter-home/
**/.codex-audits/
```

### `zhidi_app/.gitignore` 新增
```
# Temporary caches
.codex-flutter-home/
```

已验证：`lib/`、`src/`、`test/`、数据库迁移和配置文件均未被误忽略。

---

## 4. 验证结果

| 检查项 | 清理前 | 清理后 | 结论 |
|--------|--------|--------|------|
| `git diff --check` | PASS | PASS | 一致 |
| Flutter analyze | No issues | No issues | 一致 |
| Flutter 全量测试 (133) | All passed | All passed | 一致 |
| 后端全量测试 (106) | 1 failure, 33 errors | 1 failure, 33 errors | 一致（**梳理前后无新增问题**） |
| Owner APK 构建 (ECS:47.109.0.191) | 通过 | 通过 | 一致 |
| Worker APK 构建 (ECS:47.109.0.191) | 通过 | 通过 | 一致 |

### 后端测试失败明细（梳理前后相同）

| 测试类 | 失败数 | 错误数 | 类型 |
|--------|--------|--------|------|
| OwnerProfileControllerTest | 0 | 6 | 上下文加载 |
| AuthControllerTest | 0 | 9 | 上下文加载 |
| JwtSecurityIntegrationTest | 0 | 7 | 上下文加载 |
| SmokeApiTest | 0 | 2 | 上下文加载 |
| WorkerProfileControllerTest | 0 | 6 | 上下文加载 |
| WorkerDirectoryControllerTest | 0 | 2 | 上下文加载 |
| ZhidiServerApplicationTests | 0 | 1 | 上下文加载 |
| WorkerProfileServiceIntegrationTest | 1 | 0 | 集成测试 |
| **合计** | **1** | **33** | |

所有 Controller/Integration 错误均与 Spring 上下文加载相关（需要 Docker 环境），非业务代码缺陷。WorkerProfileServiceIntegrationTest 为已知集成测试缺陷，非本次整理引入。

---

## 5. 已删除文件审核摘要

审核 10 个 Git 标记删除的文件：
- **7 项合理删除**：功能已迁移/测试已重组/模板无业务价值
- **3 项待用户决定**：`message_page_test.dart`、`my_home_page_visual_test.dart`、`order_and_favorite_test.dart`（存在测试覆盖缺口）

详见：`output/baselines/20260717_154949/deleted-file-audit.md`

---

## 6. 基线 APK

| 文件 | 路径 | 大小 |
|------|------|------|
| Owner 基线 APK | `output/apks/app-owner-debug-baseline.apk` | 114 MB |
| Worker 基线 APK | `output/apks/app-worker-debug-baseline.apk` | 114 MB |

均指向 `http://47.109.0.191:8080`。

---

## 7. 已验证能力

| 能力 | 状态 |
|------|------|
| Owner APK 构建并运行 | 可用（本次产出 APK 可安装） |
| Worker APK 构建并运行 | 可用（本次产出 APK 可安装） |
| 双端全部 Flutter 单元测试 / Widget 测试通过 | 可用（133/133） |
| Flutter 静态分析零告警 | 可用 |
| 后端单元测试（非 Docker 依赖）通过 | 可用 |
| 后端 Spring 上下文加载测试 | 待修复（需 Docker 环境，非整理引入） |
| 源码源码归档可恢复 | 可用 |

---

## 8. 未决风险和下一开发入口

### 已知但未修复（非本次整理引入）
1. 后端 33 个上下文加载错误 — 需 Docker Compose（PostgreSQL）环境才能通过
2. WorkerProfileServiceIntegrationTest 1 个集成测试失败
3. `message_page_test.dart`、`my_home_page_visual_test.dart`、`order_and_favorite_test.dart` 测试覆盖缺口

### 适用于当前基线继续开发的入口
- 工作区现有 181 项变更可直接继续使用
- 构建缓存已清除，下次构建会自动重新生成
- APK 构建循环已验证闭合（清理 → 构建 → 产出 → 通过）

### 保护提醒
- 未执行 `git add`、`git commit`、`git push`
- 未恢复任何已删除文件
- 未修改生产数据库或服务器部署
*（内容由AI生成，仅供参考）*
