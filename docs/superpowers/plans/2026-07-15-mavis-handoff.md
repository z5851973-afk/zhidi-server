# 知底项目交接给马维斯

更新日期：2026-07-15

这份文档给马维斯继续开发用。先说大白话结论：现在项目已经不是纯原型了，业主端 Android 已经能连真实 Spring Boot 后端，能登录、保存业主资料、看到真实工匠、并真实提交预约落库。但闭环还没完整跑完，下一步最该做的是工人端看到预约并接单/拒单。

## 1. 当前项目做到了什么

### 1.1 后端已经有的真实能力

后端是 `zhidi_server`，Java 21 + Spring Boot + MySQL + Flyway。

已经完成：

- 手机号验证码注册/登录。
- 业主登录、工人登录。
- JWT 认证，受保护接口会识别当前用户身份。
- 业主资料持久化：
  - `GET /api/v1/owners/me`
  - `PUT /api/v1/owners/me`
- 工人资料持久化：
  - `GET /api/v1/workers/me`
  - `PUT /api/v1/workers/me`
- 公开工人列表和详情：
  - `GET /api/v1/workers`
  - `GET /api/v1/workers/{userId}`
- 预约最小后端闭环：
  - `POST /api/v1/bookings`
  - `GET /api/v1/owners/me/bookings`
  - `GET /api/v1/workers/me/bookings`
  - `POST /api/v1/workers/me/bookings/{id}/accept`
  - `POST /api/v1/workers/me/bookings/{id}/reject`

后端预约数据库迁移：

- `zhidi_server/src/main/resources/db/migration/V5__bookings.sql`

预约相关代码：

- `zhidi_server/src/main/java/com/zhidi/server/booking/`
- `zhidi_server/src/test/java/com/zhidi/server/booking/`

后端全量测试之前已经通过过。最近一次重点验证是预约链路与 Flutter 联调。

### 1.2 业主端 Android 已经跑通的真实链路

Flutter 工程是 `zhidi_app`。

当前只按 Android 作为交付目标，不做 iOS 系统。iOS 目录只是 Flutter 默认工程结构，现阶段不要把 iOS 当作验收范围。

业主端已经真实接入 Spring Boot 的部分：

- 手机号登录。
- JWT 保存到安全存储。
- 首次资料引导保存到后端。
- 重启后能读取后端业主资料，不再回到首次引导。
- 工人列表优先从 `GET /api/v1/workers` 读取。
- 工人详情能展示后端真实资料。
- 真实工人详情页点击“立即预约师傅”会调用 `POST /api/v1/bookings`。
- 预约成功后，本地“我的家/我的预约”也会同步一份状态。
- Android 模拟器 + 本地 Spring Boot + MySQL 已经验证真实落库。

最近一次真实联调结果：

- 模拟器：Android Pixel_9。
- 后端：本地 `localhost:8080`，Flutter 模拟器访问 `http://10.0.2.2:8080`。
- 测试工人：`预约联调周师傅`。
- 点击业主端“立即预约师傅”后，MySQL `bookings` 表新增记录。
- 新预约状态是 `PENDING`。
- 成功页文案已经从“师傅已接单”改成“预约已提交 / 待确认”，避免误导。

业主端预约相关 Flutter 文件：

- `zhidi_app/lib/services/owner_booking_api_client.dart`
- `zhidi_app/lib/app/owner_app_state.dart`
- `zhidi_app/lib/pages/renovation/worker_detail_page.dart`
- `zhidi_app/lib/pages/renovation/booking_success_page.dart`

相关测试：

- `zhidi_app/test/owner_booking_api_client_test.dart`
- `zhidi_app/test/owner_booking_state_sync_test.dart`
- `zhidi_app/test/worker_detail_remote_booking_test.dart`
- `zhidi_app/test/booking_success_page_status_test.dart`

最近已通过的 Flutter 聚焦测试：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
HOME=$PWD/.codex-flutter-home \
ANDROID_HOME=/Users/liupei/Library/Android/sdk \
ANDROID_SDK_ROOT=/Users/liupei/Library/Android/sdk \
../flutter/bin/flutter test \
  test/owner_booking_api_client_test.dart \
  test/owner_booking_state_sync_test.dart \
  test/worker_detail_remote_booking_test.dart \
  test/booking_success_page_status_test.dart \
  test/worker_directory_api_client_test.dart \
  test/owner_construction_state_test.dart
```

结果：15 个测试通过。

最近已通过的静态检查：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
HOME=$PWD/.codex-flutter-home \
ANDROID_HOME=/Users/liupei/Library/Android/sdk \
ANDROID_SDK_ROOT=/Users/liupei/Library/Android/sdk \
../flutter/bin/dart analyze \
  lib/services/owner_booking_api_client.dart \
  lib/app/owner_app_state.dart \
  lib/pages/renovation/worker_detail_page.dart \
  lib/pages/renovation/booking_success_page.dart \
  test/owner_booking_api_client_test.dart \
  test/owner_booking_state_sync_test.dart \
  test/worker_detail_remote_booking_test.dart \
  test/booking_success_page_status_test.dart
```

结果：无问题。

## 2. 现在还没有做完什么

### 2.1 最关键没做完：工人端真实接单闭环

后端接口已经有了，但 Flutter 工人端还没有完整接入。

要做的是：

1. 工人登录后，调用 `GET /api/v1/workers/me/bookings`。
2. 在工人端订单/首页展示业主提交过来的预约。
3. 对 `PENDING` 预约显示“接单”和“拒单”。
4. 点击接单调用：
   - `POST /api/v1/workers/me/bookings/{id}/accept`
5. 点击拒单调用：
   - `POST /api/v1/workers/me/bookings/{id}/reject`
6. 接单后页面状态要变成已接单，拒单后变成已拒单。
7. 用 Android 模拟器真实跑一遍：
   - 业主提交预约。
   - 工人端看到预约。
   - 工人接单。
   - MySQL 里预约状态从 `PENDING` 变成 `ACCEPTED`。

这是马维斯最推荐先做的一步。做完以后，小范围试验的核心闭环会变成：

业主登录 → 看真实工人 → 发起预约 → 工人登录 → 看到预约 → 接单/拒单。

### 2.2 业主端还没做完的真实接口

这些目前多数还是本地状态、Mock、或部分 Firestore 桥接：

- 业主查看自己的真实预约列表：后端有 `GET /api/v1/owners/me/bookings`，Flutter 还没系统接入。
- 预约取消、改约、状态历史：后端也还不完整。
- 报价单：目前主要是本地页面和本地状态。
- 施工项目/施工阶段：目前主要是本地状态。
- 施工日报、图片、验收整改：未接真实 Spring Boot。
- 聊天、消息、通知：未形成真实后端闭环。
- 文件上传：未做生产对象存储。
- 支付、退款、结算：未做。
- 收藏、评价、举报、售后：未做完整真实后端。
- 地址簿、头像、实名认证：未做。

### 2.3 后端还没做完的业务能力

后端现在只算“最小骨架 + 最小预约闭环”，不是完整平台。

未完成：

- 真实短信供应商。
- Refresh Token、登出撤销、设备管理、账号注销。
- 工人认证审核。
- 工人可接单状态。
- 更完整的工人筛选/排序。
- 派单。
- 预约取消、改约、状态历史。
- 报价单、报价版本、报价明细、业主确认。
- 施工项目、阶段、施工日报、图片、节点验收、整改。
- 聊天、消息、通知、客服协同。
- 文件上传与对象存储。
- 支付、退款、结算、对账、资金托管。
- 管理后台。
- Docker/Nginx/生产部署、监控、告警、备份。

### 2.4 当前工作区注意事项

当前主工作区有大量未提交改动，有些是之前分步骤做的草稿，不要一上来清理或删除。

马维斯接手前必须先做：

```bash
cd /Users/liupei/Documents/zhidi
sed -n '1,260p' PROJECT_STATUS.md
git status --short
```

不要自动提交、推送、删文件。只有用户明确说“提交”再提交。

## 3. 马维斯下一步建议怎么做

### 推荐任务：工人端真实预约列表与接单/拒单

目标一句话：

让工人端能看到业主刚提交的真实预约，并能真实接单或拒单。

建议拆成小步：

1. 先只读相关文件，不要全项目乱翻：
   - `zhidi_app/lib/app/worker_app_state.dart`
   - `zhidi_app/lib/app/worker_app_scope.dart`
   - `zhidi_app/lib/pages/worker/`
   - `zhidi_app/lib/main.dart`
   - `zhidi_server/src/main/java/com/zhidi/server/booking/`
2. 新增工人端预约 API client，例如：
   - `zhidi_app/lib/services/worker_booking_api_client.dart`
3. 给工人端状态层接入：
   - 拉取我的预约列表。
   - 接单。
   - 拒单。
   - 401 时清理登录态或提示重新登录。
4. 找到工人端当前订单列表/首页入口，把 Mock 预约替换或优先合并真实预约。
5. 加 Flutter 测试：
   - client 会带 Bearer token。
   - 能解析预约列表。
   - 接单/拒单会调用正确接口。
   - 工人端页面能展示 `PENDING` 预约并触发动作。
6. Android 模拟器真实联调：
   - 后端启动。
   - 业主端提交一条预约。
   - 工人端登录同一个工人账号。
   - 工人端看到该预约。
   - 点接单。
   - 查数据库状态变成 `ACCEPTED`。

## 4. 本地运行命令

启动后端：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw spring-boot:run \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

启动业主端 Android：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
HOME=$PWD/.codex-flutter-home \
ANDROID_HOME=/Users/liupei/Library/Android/sdk \
ANDROID_SDK_ROOT=/Users/liupei/Library/Android/sdk \
../flutter/bin/flutter run \
  -d emulator-5554 \
  --flavor owner \
  --dart-define=ZHIDI_APP_FLAVOR=owner \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

启动工人端 Android：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
HOME=$PWD/.codex-flutter-home \
ANDROID_HOME=/Users/liupei/Library/Android/sdk \
ANDROID_SDK_ROOT=/Users/liupei/Library/Android/sdk \
../flutter/bin/flutter run \
  -d emulator-5554 \
  --dart-define=ZHIDI_APP_FLAVOR=worker \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

如果 Flutter 看不到 Android SDK，重点确认这两个环境变量：

```bash
ANDROID_HOME=/Users/liupei/Library/Android/sdk
ANDROID_SDK_ROOT=/Users/liupei/Library/Android/sdk
```

ADB 路径：

```bash
/Users/liupei/Library/Android/sdk/platform-tools/adb
```

Emulator 路径：

```bash
/Users/liupei/Library/Android/sdk/emulator/emulator
```

## 5. 做完下一步的验收标准

工人端接单这一步做到下面这些，才算完成：

- Flutter 测试通过。
- Dart analyze 对新增/修改文件无问题。
- Android 模拟器真实操作通过。
- MySQL 预约状态真实改变：
  - 新建预约后是 `PENDING`
  - 工人接单后是 `ACCEPTED`
  - 工人拒单后是 `REJECTED`
- `PROJECT_STATUS.md` 更新：
  - 把“工人端真实预约列表与接单/拒单待联调”改成已完成。
  - 下一步再写派单、取消/改约、状态历史。

## 6. 不要误判的地方

- 页面很多，不代表真实后端都接好了。
- 目前 Android 是交付目标，先别把 iOS 当任务。
- Firestore 桥接不是最终 Spring Boot 闭环，需要后面慢慢替换或明确保留边界。
- 本地 Mock 能跑不等于小范围试验能跑。
- 小范围试验最核心不是页面多，而是下面这条链路真实可用：

```text
业主注册/登录
  -> 完善资料
  -> 浏览真实工人
  -> 提交真实预约
  -> 工人登录
  -> 看到真实预约
  -> 接单/拒单
  -> 双方看到状态变化
```

当前已经做到“提交真实预约”，下一刀就砍“工人看到并处理预约”。
