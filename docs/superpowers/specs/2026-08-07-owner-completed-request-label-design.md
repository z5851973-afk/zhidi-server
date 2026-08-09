# 业主端已完工需求状态设计

## 目标

当“我的装修需求”中的已选师傅订单已经进入 `COMPLETED`，对应工种卡片的状态由“已选定”改为“已完成”。

## 判定规则

- 卡片仍以服务端 `RemoteServiceRequest` 和候选订单为唯一数据来源。
- 若候选列表中存在 `COMPLETED` 订单，卡片展示状态按 `COMPLETED` 处理。
- 否则继续展示服务需求自身状态，不改变待匹配、比价中、已选定等现有文案。
- 仅改变业主端展示，不修改服务器状态、数据库或业务流转。

## 视觉规则

- “已完成”沿用成功绿色的图标、浅色背景和标签文字。
- 卡片标题、候选数量、邀请次数及点击行为保持不变。

## 验证

- Widget 回归覆盖 `WORKER_SELECTED + COMPLETED candidate => 已完成`。
- 现有 `HIRED`/未完成候选继续显示“已选定”。
- 通过 `my_home_minimal_page_test.dart`、`flutter analyze`、APK 构建和模拟器现场复验。
