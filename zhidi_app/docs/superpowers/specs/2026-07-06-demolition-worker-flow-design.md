---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: d9745611a54b33ffcd8ca58e325c372c_4f54559d790b11f1a7da5254006c9bbf
    ReservedCode1: lY/XvzGlN/qfVO8e6DsErAOzUcEr2z147Yrabt8ENurJ5hxUH7m3gORSm/cr8o8O43eQnzbN9YJXPrElo91k309UEq/UT/keiKm7J5IO/idMXayFp2wD+AWDCQR4viDbm8lHJV7iuiGv5sNYn+Y7ETM1Y3eIbsfJ1TGkDA2RTukKty8JEnoYRMMji14=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: d9745611a54b33ffcd8ca58e325c372c_4f54559d790b11f1a7da5254006c9bbf
    ReservedCode2: lY/XvzGlN/qfVO8e6DsErAOzUcEr2z147Yrabt8ENurJ5hxUH7m3gORSm/cr8o8O43eQnzbN9YJXPrElo91k309UEq/UT/keiKm7J5IO/idMXayFp2wD+AWDCQR4viDbm8lHJV7iuiGv5sNYn+Y7ETM1Y3eIbsfJ1TGkDA2RTukKty8JEnoYRMMji14=
---

# 拆除工卡片 → 师傅列表 → 师傅主页 流程设计

**日期**：2026-07-06
**版本**：v1.0

---

## 1. 背景

找师傅页点击工种卡片后，需要进入该工种的**师傅列表页**，点击师傅进入**师傅主页**。当前代码中 `_onTradeTap` 仅处理了"局部改造"跳转，其他工种为 TODO 占位。

本次设计覆盖**拆除工**（作为第一个实现），后续水电工、泥瓦工等按相同模式扩展。

---

## 2. 流程概览

```
找师傅页（工种卡片） → 点击拆除工 → 拆除师傅列表页 → 点击师傅卡片 → 师傅主页
                                                    ↓
                                               收藏 / 立即预约 → 聊天/下单
```

---

## 3. 页面1：拆除工师傅列表页

### 3.1 路由

`from trade_select_page.dart → Navigator.push → DemolitionWorkerListPage`

路由参数：
- `trade`：`Trade.demolition`（后续扩展为 `Trade.plumbing` 等）
- `serviceType`：`'demolition'`（传给列表页驱动标题、筛选标签、数据过滤）

### 3.2 页面结构

| # | 区块 | 内容 | 交互 |
|---|---|---|---|
| 1 | 导航栏 | 标题「拆除师傅」+ 返回按钮 | 返回找师傅页 |
| 2 | 筛选栏 | 排序标签：「综合排序」「评分最高」「离我最近」「接单最多」 | 切换排序方式 |
| 3 | 师傅卡片列表 | 每张卡片：头像 + 姓名 + 信用标签 + 星级 + 经验 + 完工数 + 擅长标签 + 工地实拍 + 评价摘要 + 收藏 + 查看详情 | 点击卡片 → 师傅主页 |
| 4 | 底部信任栏 | 平台保障 / 服务保障 / 投诉保障 / 资金保障 | 无交互（展示） |

### 3.3 复用策略

**直接复用** `home/worker/worker_list_page.dart`（53KB），通过 `serviceType` 参数注入：

```
WorkerListPage(serviceType: 'demolition', title: '拆除师傅')
```

WorkerListPage 内部已有 `serviceType` 驱动的动态逻辑：
- `_title` getter：按 serviceType 返回标题
- `_sorted` getter：按 serviceType 过滤工人数据
- `_SearchFilterBar`：接收外部 filterTags

### 3.4 数据要求

`worker_models.dart` 中需存在 `DemolitionWorker` 类型或通过 `Trade` 字段过滤。当前 Mock 数据路径：`_allWorkers` 列表中追加拆除工数据项。

---

## 4. 页面2：拆除工师傅主页

### 4.1 路由

`from DemolitionWorkerListPage → Navigator.push → WorkerDetailPage`

路由参数：
- `worker`：`Worker` 对象（从列表页传递）

### 4.2 页面结构

| # | 区块 | 内容 | 交互 |
|---|---|---|---|
| 1 | 导航栏 | 标题「师傅详情」+ 返回 + 收藏 + 分享 | 收藏切换、分享 |
| 2 | 头部区 | 头像 + 姓名 + 金牌标签 + 「拆除工 · 8年 · 广州」+ 认证徽章 | 无交互 |
| 3 | 四宫格 | 评分 4.9 / 完工 326单 / 好评 98% / 服务 5年 | 无交互 |
| 4 | 推荐语 | 「该师傅经业主评价排名靠前」 | 无交互 |
| 5 | 擅长技能 | 标签：墙体拆除 / 旧装修拆除 / 铲墙皮 / 垃圾清运 / 地面破除 / 门窗拆除 | 点击「全部技能」 |
| 6 | 师傅介绍 | 文案 + 完工/好评/回头客/投诉四宫格 | 无交互 |
| 7 | 工价详情 | 拆墙 ¥35-50/㎡ / 铲墙皮 ¥8-12/㎡ / 拆地砖 ¥15-25/㎡ / 清运 ¥300-500/车 … | 点击单项展开详情 |
| 8 | 施工案例 | 4张横向滑动缩略图 + 「查看更多」 | 点击进入图片查看器 |
| 9 | 业主评价 | 评价总数 + 2条评价卡片 + 「全部评价」 | 点击「全部评价」 |
| 10 | 底部固定 | 「收藏」+ 「立即预约」 | 收藏切换 / 跳转创建订单 |

### 4.3 复用策略

**直接复用** `renovation/worker_detail_page.dart`（44.7KB），调整数据注入：

- 头部：`name`, `trade`, `experience`, `city`, `certifications`
- 技能标签：按 `trade='demolition'` 加载拆除工专属标签列表
- 工价表：按 `trade='demolition'` 加载拆除工价数据
- 案例图片：按 `worker.id` 加载对应案例

### 4.4 数据要求

`worker_detail_page.dart` 当前已支持多工种（通过 `trade` 参数区分），拆除工需要在：
- `_SkillsSection`：新增 `case Trade.demolition` 分支，返回拆除工技能标签
- `_PriceDetailSection`：`_priceListForTrade` 中新增 `case Trade.demolition`
- `_AboutSection`：新增拆除工介绍文案
- `_workerRoleText`：新增拆除工角色文本

---

## 5. 数据模型扩展

### 5.1 Trade 枚举

`renovation.dart` 或 `worker_models.dart` 中确认 `Trade.demolition` 枚举值存在。

### 5.2 Worker 类型

`worker_models.dart` 中 `Worker` 类的 `trade` 字段应能赋值 `Trade.demolition`。

---

## 6. 实现步骤

| 步骤 | 内容 | 涉及文件 |
|---|---|---|
| 1 | 在 `worker_models.dart` 中新增拆除工 Mock 数据 | `worker_models.dart` |
| 2 | 在 `trade_select_page.dart` 中 `_onTradeTap` 添加拆除工跳转 | `trade_select_page.dart` |
| 3 | 在 `worker_detail_page.dart` 中补齐拆除工分支 | `worker_detail_page.dart` |
| 4 | 调试：找师傅页 → 列表页 → 主页 全链路跑通 | — |
| 5 | 扩展：水电工/泥瓦工/防水工等按相同模式接入 | `trade_select_page.dart` |

---

## 7. 验收标准

- 点击「拆除工」卡片 → 进入拆除师傅列表页
- 列表页标题为「拆除师傅」，仅显示拆除工师傅
- 点击师傅卡片 → 进入师傅主页，头部显示拆除工相关信息
- 技能标签、工价、案例均为拆除工专属数据
- 「立即预约」按钮可点击（后续对接订单系统）
- 后续工种（水电工/泥瓦工/…）按同样方式可接入
*（内容由AI生成，仅供参考）*
