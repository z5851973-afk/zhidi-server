# 知底项目状态

> Codex 快速上下文。最近核对：2026-07-29（业主端截图第 4-8 页闭环 UI 调整与 Flutter 验证）。开始任务时先读本文件；只有任务涉及的部分才继续读取源码或 `docs/superpowers/` 下的设计与计划。

## 1. 产品是什么

“知底”是装修服务平台，核心目标是让业主直接找到可信工匠/工长，并围绕预约、报价、施工、验收和售后形成闭环。

当前 Flutter 工程同时包含两个应用角色：

- 业主端：浏览装修服务和工匠、预约、查看报价与项目进度、沟通、验收、管理个人资料。
- 工匠端：登录、维护资料、接单、报价、提交施工日报与验收、查看收入和消息。

较早的 MVP 产品设计强调“业主直连工长、平台客服派单、施工过程留痕”；后续 Spring Boot 设计扩大到报价、项目、支付和文件服务。实际开发时以当前用户任务和源码为准，不要把设计文档里的规划误判为已实现功能。

## 2. 仓库结构

```text
zhidi/
├── zhidi_app/       Flutter 应用，业主端和工匠端共用一个工程
├── zhidi_server/    Java 21 + Spring Boot 3.5 后端
├── flutter/         仓库内 Flutter SDK，不是业务应用
├── docs/superpowers/specs/  产品/功能设计文档
├── docs/superpowers/plans/  实施计划；计划存在不代表已经完成
└── .worktrees/      其他隔离工作树，不属于当前主工作目录
```

重要入口：

- Flutter 启动：`zhidi_app/lib/main.dart`
- 业主状态：`zhidi_app/lib/app/owner_app_state.dart`
- 工匠状态：`zhidi_app/lib/app/worker_app_state.dart`
- 后端启动：`zhidi_server/src/main/java/com/zhidi/server/ZhidiServerApplication.java`
- 后端迁移：`zhidi_server/src/main/resources/db/migration/`

## 3. 当前已完成

### Flutter 应用

- 当前业务交付只保留 Android 为完成标准；2026-07-17 已按用户要求删除未开发且未被 Git 跟踪的 `zhidi_app/ios/` Flutter 脚手架目录。Web、macOS、Windows 和 Linux 工程结构仍在工作区，但不作为当前交付目标。
- Android 通过 `--flavor owner` 启动业主端；未指定时默认启动工匠端。
- 两端共用设计主题和中文本地化。
- 业主端已有启动页、手机号登录、首次资料引导、首页、工匠列表/详情、预约与订单、透明价格、装修项目、消息、聊天、个人中心、地址、收藏、设置、售后等页面或交互原型。
- 工匠端已有登录、首页、订单详情、报价、施工日报、验收、收入、资料等页面或交互原型。
- 业主端手机号验证码登录已接入 Spring Boot；JWT 使用平台安全存储保存。
- 业主资料 GET/PUT 接入和首次引导保存已在 Android 模拟器完成端到端验证：登录后读取服务端默认资料，首次引导提交资料落库，强停重启后不再回到首次引导。后端 API、Flutter API client、会话/资料状态同步、登录页、首次引导页、业主端 app shell 路由、设置退出、个人中心基础 UI token 化、报价收藏、报价页保存入口、工人详情报价入口、完整工种工价数据映射、透明工价列表页、施工中师傅/阶段完成状态底座、“我的家”最小施工进度页、工人详情预约写入施工进度链路、工人列表进入详情预约链路、本地验收申请/通过/驳回闭环、验收通过自动归档展示和材料估算确认采购已整理提交；剩余地址扩展等能力仍在主工作区未提交改动中。
- 业主端工匠列表/详情已接入 Spring Boot 公开工匠 API：列表优先读取 `GET /api/v1/workers`，按当前工种筛选，后端失败或无匹配数据时回退本地 Mock；详情页可展示服务端返回的姓名、工种、经验、城市、日薪和简介。该链路已通过 Flutter 聚焦测试，并已在 Android 模拟器使用本地 Spring Boot + MySQL 真实工匠资料完成联调。
- 业主端真实工匠详情页“立即预约师傅”已接入 Spring Boot 预约 API：服务端工匠会先调用 `POST /api/v1/bookings`，成功后再同步本地“我的家/我的预约”状态；本地 Mock 工匠仍保留原本本地预约路径。该链路已通过 Flutter 聚焦测试，并已在 Android 模拟器使用本地 Spring Boot + MySQL 真实落库验证，预约初始状态为 `PENDING`，成功页文案已调整为“预约已提交/待确认”。
- 生产预约闭环已通过公网 API 和 Android Studio Pixel 9 模拟器验证：测试工人发布完整资料后出现在业主端工人目录；测试业主创建预约后，工人端可登录真实账号并看到云端真实预约卡片；工人端在模拟器 UI 点击“立即接单”后，待接单列表清空，业主预约列表通过 API 回读为 `ACCEPTED`。业主端和工人端 debug APK 已使用 `API_BASE_URL=http://47.109.0.191:8080` 构建成功。模拟器验证使用订单 `1090709c-5c6d-442c-8183-e33c82821787`，工人 `19817313015`，业主 `19917334870`。
- 业主端消息反馈已接入真实预约状态同步：`fetchRemoteBookings()` 拉到远程 `ACCEPTED` 预约时，会生成去重的“工人已接单”预约通知；切换到底部“消息”Tab 时会主动刷新远程预约，避免只显示旧 Mock/本地通知。该逻辑已通过 Flutter 聚焦测试和 `flutter analyze`；能力已包含在当前 `output/apks/app-owner-debug-20260716-worker-cases.apk`。本机已手动安装 Android 35 ARM64 稳定系统镜像并创建 `Zhidi_API35` AVD，业主端登录测试账号后已在消息页看到 2 条来自远程已接单预约的“工人已接单”通知，截图证据为 `output/evidence/owner-message-feedback-20260716.png`。
- 工人端登录错误提示已补齐中文映射：`SMS_CODE_INVALID`、`SMS_CODE_EXPIRED`、`SMS_CODE_ATTEMPTS_EXCEEDED`、网络错误和工匠权限错误不再直接透出后端英文 message；已通过 `test/worker_login_page_test.dart` 覆盖。工人端登录资料同步也已修正：登录成功后读取 `GET /api/v1/workers/me` 并用服务器资料覆盖本地缓存，且不再把本地旧资料（例如历史残留的 Bill）自动上传覆盖服务器。生产测试工人 `19817313015` 曾被旧流程污染为 Bill，已通过 `PUT /api/v1/workers/me` 修回“模拟器闭环工人”；能力已包含在当前 `output/apks/app-worker-debug-20260716-worker-cases.apk`。
- 工人首次资料完善已接入真实后端：服务器资料缺少真实姓名、服务城市、工种、工龄、日薪或自我介绍时，工人端强制进入“完善工人资料”，手机号只读；保存会先 `PUT /api/v1/workers/me`，再 GET 回读成功结果，本地状态不会在服务器失败时假保存。该链路通过 8 个 Flutter 聚焦测试、`flutter analyze`、后端纯单元测试与生产 API 回读；ECS 已于 `20260716213046` 备份并发布，健康检查为 `UP`。该能力已包含在当前 `output/apks/app-worker-debug-20260716-worker-cases.apk`，模拟器页面证据为 `output/evidence/worker-profile-onboarding-real-app-20260716.png`。
- Android 双模拟器真实 UI 闭环复验完成：工人端 `Zhidi_Worker_API35` 恢复真实登录态后从 ECS REST API 看到云端预约“两个模拟器联通测试 3 栋 303”，在工人端 UI 点击“立即接单”后待接单列表清空；业主端 `Zhidi_API35` 切到消息页后刷新出对应“工人已接单”反馈。证据截图为 `output/evidence/worker-home-restored-cloud-booking-20260716.png`、`output/evidence/worker-ui-accepted-cleared-20260716.png`、`output/evidence/owner-message-after-worker-ui-accept-20260716.png`。
- 2026-07-18 双模拟器公网复验新增修复：工人端恢复安全登录态时会同步 `GET /api/v1/workers/me`，避免服务器资料完整但本地空资料导致重启后仍卡“完善工人资料”；业主端“找师傅”工种卡片会调用 `GET /api/v1/workers` 统计真实可接单人数，不再全部显示 0；业主创建候选需求时使用业主资料城市/地址，不再硬编码“北京市”；业主候选页、接单消息和工人端远程订单卡片会把 `carpentry/plumbing` 等后端工种值展示为中文；新装/空状态工人端远程预约同步列表已改为可变列表，避免云端有单但本地不显示。已通过 `flutter analyze`、`test/worker_session_state_test.dart`、`test/trade_select_page_visual_test.dart`、`test/owner_booking_state_sync_test.dart`、`test/candidate_picker_page_test.dart`，并重新构建安装当前双端 debug APK。
- 工匠施工案例已形成真实 ECS/MySQL 双端闭环：工人端个人资料可新增、编辑、删除 1–6 张图的施工案例，图片通过工人 JWT 上传到 `/opt/zhidi/uploads/cases`；业主端真实工人详情只读取公开案例 API，并提供加载、空、失败重试状态，不再为远程工人伪造 Picsum 案例。生产测试工人“模拟器闭环工人”已上传并创建“水电改造施工案例”，工人端案例管理和业主端详情均显示同一条记录。聚焦验证为后端 9 项、Flutter 20 项测试及 `flutter analyze` 无问题；正常 APK 为 `output/apks/app-worker-debug-20260716-worker-cases.apk`、`output/apks/app-owner-debug-20260716-worker-cases.apk`，证据为 `output/evidence/worker-profile-with-cases-20260716.png`、`output/evidence/owner-worker-detail-name-20260716.png`、`output/evidence/owner-worker-case-detail-20260716.png`。
- 2026-07-18 已修正马维斯 Android 正式上线路线实现中的关键问题：业主端多候选预约恢复为一个服务请求下最多三名候选工人；工人接单不再提前淘汰其他候选；只有业主最终选择报价才完成最终选人；未上门前可取消；报价确认增加确认勾选和 2 秒长按，降低误触；支付/退款 UI 明确显示渠道未开通，不再伪造支付成功。后端已部署到 ECS，业主端和工人端 debug APK 已构建，仍需安装到手机进行完整 UI 复验。
- 2026-07-18 继续修通生产公网预约后半段闭环：后端 `BookingService` 与 `ServiceRequestService` 已返回可见上门时间，业主端可看到工人建议时间并确认；工人端远程订单会覆盖同 ID 本地旧状态，进行中列表包含上门/到场/报价/已选中状态，订单详情停留时会定时刷新远程状态；工人端报价页修复初始化卡住问题，可加载服务端固定价格目录并提交报价；业主端“我的家”可看到报价明细、用勾选+长按二次确认最终选人，成功后刷新为“已选定”。双模拟器已用订单 `98a34fe9-0952-4c9d-a22d-4718007406e9` 从上门确认、双方到场、提交报价、业主选人跑到生产库 `bookings.HIRED` / `quotes.ACCEPTED`；当前后续真实施工/支付仍按未完成项推进。
- 2026-07-18 已继续打通 `HIRED` 后的施工留痕：工人端已选中订单详情显示“提交日报/发起验收/联系业主/查看结算”，工人提交施工日报写入生产库后，业主端“我的家”已能显示同一条日报；工人端节点验收页修复初始化加载，可创建默认验收节点并发起木工验收；业主端节点验收页修复初始化加载，可看到“木工验收/验收中”，并在 UI 提交通过后生产库 `inspection_nodes` 变为 `PASSED`，工人端回读也显示“已通过”。
- 2026-07-18 已修复工人端新预约提示不实时的问题：工人首页进入/回前台后会拉取远程预约，并每 8 秒轮询一次；新 `PENDING` 云端预约会生成去重的未读“新的预约待接单”消息，底部“接单中心/消息”显示红点数量。生产库 GT 工人 `13111111111` 已验证可看到 2 张云端待接单卡片，修正版工人端 APK 为 `output/apks/app-worker-debug-20260718-gt-pending-refresh.apk`。
- 2026-07-18 已修复业主端预约提交后无反馈的问题：`PENDING` 远程预约同步后会生成去重的未读“预约已提交”订单通知，消息页和底部 Tab 显示红点；创建预约时本地文案从“预约已确认”改为“预约已提交/等待师傅接单”，避免误导。生产库业主 `13555555555` 已验证可看到 GT 的待接单预约反馈，修正版业主端 APK 为 `output/apks/app-owner-debug-20260718-pending-booking-feedback.apk`。
- 2026-07-18 已修复业主端“我的家”真实预约不可见与列表陈旧问题：每次进入“我的家”都会重新拉取服务请求和业主预约，从找师傅流程返回后也会刷新；服务请求接口暂未返回数据时，会用真实业主预约展示 GT 等待接单/接单状态，不再错误显示“还没有装修需求”。并发刷新使用序号防止旧响应覆盖新结果，相关 Widget、预约同步和状态标签测试通过。
- 2026-07-19 已修复业主端多人报价对比页的真实加载与选人后刷新：页面改在依赖可用后读取业主登录态并加载服务请求下全部服务器报价，支持测试注入；最终选人成功会把变更结果逐级返回候选详情和“我的家”，触发服务器状态刷新，不再停留在旧的“比价中/待确认报价”。服务器报价加载、最低价展示、误触保护和成功返回均有 Widget 测试覆盖。
- 2026-07-19 已启动 `Zhidi_API35` 与 `Zhidi_Worker_API35` 双模拟器复验公网真实数据：业主“我的家”显示 3 个服务器水电需求，其中比价中需求有 GT、打多少两位候选；报价对比页正常打开并如实显示该需求当前“暂无报价”；工人端显示同一业主 `kkkkk` 的 2 张云端待接单卡片。复验同时发现并修复 Android 三键导航栏覆盖业主端底部 Tab 的问题，底栏现使用系统安全区，正常点击“我的家”可进入页面；截图保存在 `output/evidence/owner-my-home-safe-area-20260719.png`、`owner-candidates-20260719.png`、`owner-quote-compare-empty-20260719.png`、`worker-pending-20260719.png`。
- 2026-07-19 可见双模拟器继续复验时确认工人端底部 Tab 同样被 Android 三键导航栏覆盖；现已为工人底栏加入系统安全区并通过专门 Widget 回归测试，重新构建安装到 `Zhidi_Worker_API35` 后语义边界位于系统导航栏上方。Frontend Developer 只读审查同时确认拒价重报剩余 P0：工人端尚未读取/展示服务器 `rejectReason`，业主拒价后旧报价缓存未失效，下一步按此修复。
- 2026-07-29 已按业主端闭环流程图调整截图第 4-8 页相关 Flutter UI：`home/worker/worker_detail_page.dart` 增加信任型服务范围、平台施工标准入口和平台统一工价展示，底部主操作统一为“立即预约”；真实候选列表进入的 `renovation/worker_detail_page.dart` 也已补齐服务范围、施工标准、平台统一工价前置信息，并将 `plumbing` 等服务端工种值转为中文；`order/create_order_page.dart` 改为“预约师傅上门”的师傅摘要、服务/时间/地址/备注表单和平台保障提示，并跳转到待确认成功页；`renovation/booking_success_page.dart` 压缩为“已提交预约，等待师傅确认”的待确认状态；`owner_quote_compare_page.dart` 改为“报价清单 + 平台托管确认”，保留勾选协议与长按 2 秒确认；`my_home_page.dart` 将真实服务请求中最活跃项目提升为“我的家”项目工作台，串联报价、施工记录、验收与付款入口。已通过 `flutter analyze` 及相关 Widget 测试，并构建安装业主端 debug APK 到 Android 模拟器完成真实详情页可视化核对。
- 2026-07-29 继续修复业主端候选师傅真实选择断点：当 `POST /api/v1/owners/me/service-requests/{requestId}/candidates` 返回“该工匠已经是候选”类冲突时，候选页不再显示“添加失败”，而是把该师傅同步为“已选”并启用“完成选择”；候选页顶部也会把 `plumbing` 等后端工种值显示成中文。已通过新增 Widget 回归测试、`test/candidate_picker_page_test.dart`、`test/worker_detail_remote_booking_test.dart` 和 `flutter analyze`，并重新构建安装业主端公网 debug APK 到 `emulator-5554`。公网 UI 复验证据为 `output/evidence/owner-candidate-after-add-conflict-fix-20260729.png` 与 `output/evidence/owner-after-complete-candidate-selection-20260729.png`；同时确认对应 rhhhm 既有候选在服务器已处于 `ARRIVAL_PENDING`，因此工人端显示在“进行中”而非“待接单”，证据为 `output/evidence/worker-in-progress-after-owner-selection-20260729.png`。
- 2026-07-29 已按用户要求清空生产测试账号和测试业务数据：ECS MySQL 清理前备份为 `/opt/zhidi/backups/zhidi-before-test-cleanup.sql`，清理后仅保留管理员 `13800000000/ADMIN`，业主/工人资料、服务需求、预约、报价、日报、验收、支付和验证码表均为 0。随后用干净账号 `19672900201`（业主）与 `19772900201`（工人）重新跑公网双模拟器真实 UI：业主登录验证码自动填入、找水电师傅、添加 `UI闭环水电师傅` 候选、完成选择后“我的家”显示待接单；工人端登录后真实显示待接单卡片，点击“立即接单”后服务器状态为 `ACCEPTED`，业主消息页出现“工人已接单”，我的家变为“待上门”；工人端提出 2026-07-30 09:00 上门时间后服务器状态为 `VISIT_PROPOSED`，业主候选详情“确认时间”后状态为 `VISIT_SCHEDULED`。证据截图包括 `output/evidence/owner-clean-candidate-list-20260729.png`、`owner-clean-my-home-after-complete-20260729.png`、`worker-clean-pending-after-login-20260729.png`、`owner-clean-message-after-worker-accept-20260729.png`、`worker-clean-after-propose-visit-20260729.png`、`owner-clean-after-confirm-visit-20260729.png`。该测试账号暂保留用于继续验证双方到达、报价、验收和付款；完成后需再次清理。
- 2026-07-29 已继续跑完干净账号公网双模拟器后半段闭环：工人端“我已到达”后服务器进入 `ARRIVAL_PENDING`，业主端确认师傅到场后进入 `ON_SITE`；工人端加载服务端固定水电价目并提交 `水管检修 + 电路检修` 报价 ¥160，业主端“我的家”显示 `报价待确认/¥160`，勾选协议并二次长按确认后服务器 `bookings.HIRED`、`quotes.ACCEPTED`；工人端提交施工日报后业主候选详情可看到同一条日报；工人端发起水电节点验收，业主端 UI 通过第一个节点，其余同接口节点通过后支付页成功生成线下付款订单，业主上报已付款、工人确认实际收款后 `payment_orders.status=WORKER_CONFIRMED_RECEIVED`、工人结算 ¥160。同步修复本轮复验发现的 3 个业主端问题：`ARRIVAL_PENDING` 时“我的家”项目工作台直接显示“确认师傅已到场”并调用真实接口；报价清单在 quote 缺少 `workerName` 时使用候选工人名，不再显示“未知师傅/该师傅”；支付页不再在 `initState` 读取 `OwnerAppScope` 导致生命周期错误。验证命令包括 `flutter test test/owner_quote_confirmation_test.dart test/my_home_minimal_page_test.dart test/owner_payment_page_test.dart`、`flutter analyze`、业主端公网 debug APK 构建安装，以及生产 API 回查报价、日报、验收、支付订单状态。复验完成后已按要求再次清理测试账号 `19672900201`、`19772900201` 及关联业务数据，清理前备份位于 `/opt/zhidi/backups/20260729-clean-ui-final/zhidi-before-clean-ui-final.sql`，回查测试用户、资料、预约、服务需求和支付订单均为 0。
- 2026-07-29 继续修复清理测试账号后模拟器旧登录态导致的真实接口 401：聊天 API 现在会保留后端 `UNAUTHORIZED/access token invalid` 等真实 code/message，不再统一包装成 `CHAT_ROOM_FAILED`；业主端创建需求和业主/工人聊天入口遇到 401 会清除本地登录态并提示“登录已过期，请重新登录”，避免旧账号已从服务器删除但本地仍显示旧订单、点击后报技术错误。已重新构建安装业主端 APK，并清除 `emulator-5554` 旧本地数据，当前业主端回到无旧登录态的干净首页。
- 2026-07-29 已修复工人端验证码登录重复点击问题：`WorkerLoginPage` 在登录请求 pending 时会立即忽略后续点击，并用 `finally` 可靠复位 loading，避免同一验证码被连续提交后端、第一次成功/处理中但后续请求返回“验证码不正确”。新增 Widget 回归测试 `worker login ignores repeated taps while request is pending`，已通过 `flutter test test/worker_login_page_test.dart` 与 `flutter analyze`；已重新构建公网工人端 debug APK 并安装到 `emulator-5556`，清空本地旧状态后用临时工人号真实 UI 连续点击登录，结果直接进入“完善工人资料”，未再出现验证码无效；临时测试号 `19772900301` 及验证码已从生产库清理为 0。
- 2026-07-29 已修复工人端“完善工人资料”保存失败只显示泛化错误的问题：`PUT /api/v1/workers/me` 现在会保留后端错误 envelope（如 `UNAUTHORIZED/access token invalid`），资料页遇到 401 会清除工人端本地登录态并提示“登录已过期，请重新登录”，避免已删除测试账号的旧 token 继续卡在资料页。新增 `auth_api_client_test.dart` 与 `worker_profile_onboarding_test.dart` 回归，连同 `worker_session_state_test.dart` 和 `flutter analyze` 通过；已重新构建公网工人端 debug APK，安装到 `emulator-5556` 并清空旧本地状态，当前工人端回到干净登录页。
- 2026-07-29 已同步修复业主端验证码登录重复点击问题：`LoginPage` 在登录请求 pending 时会立即忽略后续点击，避免同一验证码被连续提交。新增 Widget 回归测试 `repeated login taps send only one owner login request`，与工人端登录测试一起通过；`flutter analyze` 无问题。已重新构建公网业主端 debug APK，安装到 `emulator-5554` 并清空业主端本地旧状态。
- 2026-07-29 已按“业主直连工人、平台只做保障”的产品初心微调业主端“找师傅”页：保留现有沉浸式照片工种卡，不改成平台派单/分配模式；顶部说明从“平台马上匹配”改为“看资料、看案例、看工价，自己选师傅”；工种卡可用状态从“X位可接单/0位可接单”调整为“X位可预约/暂无可约 · 先看工价”，弱化平台分配感并降低 0 人状态的挫败感。已通过 `test/trade_select_page_visual_test.dart`、双端登录回归测试与 `flutter analyze`，并重新构建安装业主端公网 debug APK 到 `emulator-5554`。
- 大量业务状态已能在本地持久化，并带有 Mock 示例数据。
- 部分业主/工匠订单和工匠资料使用 Firestore 桥接；这不是完整正式后端。
- 已存在 Flutter 单元/Widget 测试，覆盖认证、启动、引导、退出以及若干重点页面。

### Spring Boot 后端

- 基础框架：Java 21、Spring Boot 3.5、Maven、Spring MVC、Spring Data JPA、Spring Security、Flyway、MySQL、OpenAPI、Actuator。
- 已有统一 API 响应、trace ID、全局异常处理和基础审计表。
- 2026-07-22 已修复生产环境不存在路径被全局兜底错误包装为 500、未知异常不记录堆栈的问题：`/` 和随机不存在路径现在统一返回 404 `NOT_FOUND`，真正的未知异常会记录 traceId 和完整堆栈。ECS 已清除手工 `nohup` 与 systemd 双实例冲突，修正 `/opt/zhidi/.env` 的正式凭据并收紧为 `600`，当前仅由 `zhidi.service` 托管；公网健康、Swagger、数据库查询、鉴权和 404 已复验。
- 已完成用户、角色和短信验证码数据模型及 Flyway 迁移。
- 已完成业主/工匠验证码请求、注册、统一登录和 30 天 JWT 签发。
- 已完成 JWT 入站认证：受保护 API 回查数据库用户状态与角色，并统一返回 JSON 401/403 错误。
- 已实现验证码哈希保存、5 分钟有效期、错误次数限制，以及手机号/IP 发送频率限制。
- 已有服务、控制器、JWT、仓库和 MySQL Testcontainers 测试。
- 业主资料 MySQL 持久化、`GET /api/v1/owners/me`、`PUT /api/v1/owners/me` 已同步到主工作区，并通过后端全测试。
- 工匠资料 MySQL 持久化、`GET /api/v1/workers/me`、`PUT /api/v1/workers/me` 已同步到主工作区，并通过对应后端测试。
- 工匠公开列表和详情 `GET /api/v1/workers`、`GET /api/v1/workers/{userId}` 已同步到主工作区，仅展示资料完整工匠。
- 预约最小后端闭环已同步到主工作区：业主可为资料完整工匠创建预约，业主/工匠可分别查看自己的预约，工匠可接单或拒单；已通过后端全量测试。
- 2026-07-18 后端 V10-V16 整改已通过全量测试并部署到 ECS：服务请求多候选、双方取消、上门时间协商、到场确认、服务端固定价报价、拒绝重报、多人比价、最终选人、施工日报、节点验收/整改、聊天房间参与人校验、支付/结算/售后占位接口均保持真实鉴权边界。生产 Flyway 已到 V16，`zhidi.service` 运行在 `http://47.109.0.191:8080` 且健康检查 `UP`。
- 腾讯短信、腾讯 COS、支付回调和退款默认显式关闭；未配置并验证真实供应商时，接口不会假装成功。
- 生产 ECS 的 systemd `zhidi.service` 健康检查为 `UP`，Hibernate 生产配置为 `ddl-auto=validate`。此前 V8 已补齐预约业主快照字段、删除生产库遗留的 `worker_profiles(name, primary_trade)` 唯一索引，并验证两个同名同工种工人资料可同时保存；对应备份位于 `/opt/zhidi/backups/20260716151927/` 与 `/opt/zhidi/backups/20260716153533/`。
- 工匠案例表、案例 CRUD、公开读取和受保护图片上传已发布到生产；Flyway 当前为 V9 `worker cases`，生产文件目录为 `/opt/zhidi/uploads/cases`。公开案例路径的 JWT 过滤器遗漏曾在真实联调中表现为 401，已用回归测试修复并重新发布；发布备份位于 `/opt/zhidi/backups/20260716223307/` 与 `/opt/zhidi/backups/20260716225101/`，健康检查、公开案例 JSON 和 PNG 下载均已复验。

当前主工作区真实后端 API 包括：

```text
POST /api/v1/auth/sms-codes
POST /api/v1/auth/register
POST /api/v1/auth/login
POST /api/v1/auth/workers/register
POST /api/v1/auth/workers/login
GET /api/v1/owners/me
PUT /api/v1/owners/me
GET /api/v1/workers
GET /api/v1/workers/{userId}
GET /api/v1/workers/me
PUT /api/v1/workers/me
GET /api/v1/workers/{userId}/cases
GET /api/v1/workers/me/cases
POST /api/v1/workers/me/cases
PUT /api/v1/workers/me/cases/{caseId}
DELETE /api/v1/workers/me/cases/{caseId}
POST /api/v1/workers/me/case-images
POST /api/v1/bookings
GET /api/v1/owners/me/bookings
GET /api/v1/workers/me/bookings
POST /api/v1/workers/me/bookings/{id}/accept
POST /api/v1/workers/me/bookings/{id}/reject
POST /api/v1/owners/me/bookings/{id}/cancel
POST /api/v1/workers/me/bookings/{id}/cancel
POST /api/v1/bookings/{id}/cancel  # legacy owner cancel path
POST /api/v1/owners/me/service-requests
GET /api/v1/owners/me/service-requests
POST /api/v1/owners/me/service-requests/{requestId}/candidates
POST /api/v1/owners/me/service-requests/{requestId}/cancel
GET /api/v1/service-requests/{requestId}/quotes
PUT /api/v1/bookings/{id}/visit-proposal
PUT /api/v1/owners/me/bookings/{id}/accept-visit
PUT /api/v1/owners/me/bookings/{id}/reject-visit
PUT /api/v1/owners/me/bookings/{id}/arrive
PUT /api/v1/workers/me/bookings/{id}/arrive
PUT /api/v1/owners/me/bookings/{id}/confirm-arrival
PUT /api/v1/workers/me/bookings/{id}/confirm-arrival
POST /api/v1/bookings/{bookingId}/quotes
GET /api/v1/bookings/{bookingId}/quotes
GET /api/v1/workers/me/quotes
GET /api/v1/service-catalog
PUT /api/v1/quotes/{quoteId}/accept
PUT /api/v1/quotes/{quoteId}/reject
POST /api/v1/bookings/{bookingId}/daily-reports
GET /api/v1/bookings/{bookingId}/daily-reports
POST /api/v1/bookings/{bookingId}/inspection-nodes
GET /api/v1/bookings/{bookingId}/inspection-nodes
POST /api/v1/inspection-nodes/{nodeId}/inspect
GET /api/v1/inspection-nodes/{nodeId}/records
GET /api/v1/chat/rooms
POST /api/v1/chat/rooms/by-booking/{bookingId}
GET /api/v1/chat/rooms/{roomId}/messages
POST /api/v1/chat/rooms/{roomId}/messages
POST /api/v1/payment/orders
GET /api/v1/payment/orders/{orderId}
GET /api/v1/payment/orders
POST /api/v1/payment/callback
POST /api/v1/payment/orders/{orderId}/refund
GET /api/v1/settlements
POST /api/v1/after-sales
GET /api/v1/after-sales/{id}
GET /api/v1/after-sales
```

## 4. 当前未完成

### 后端关键缺口

- 真实短信供应商；开发环境目前返回模拟验证码。
- Refresh Token、登出撤销、会话/设备管理和账号注销。
- 业主资料 API 与数据库持久化已整理到主工作区提交范围；头像、地址簿、实名认证仍未实现。
- 工匠认证审核、可接单状态和更完整的筛选/排序；当前已完成工匠短信注册/登录、当前登录工匠资料 GET/PUT、公开工匠列表和详情。
- 预约创建、业主/工匠预约列表、工匠接单/拒单已有最小后端 API；派单、取消、改约、状态历史和更完整订单流转仍未实现。
- 报价单、报价明细、拒绝重报和业主最终确认已有本地后端实现，并已完成一条生产双模拟器 UI 闭环；仍缺正式支付前后的资金状态闭环、报价 PDF/图片归档和更多异常/多人比价真机复验。
- 施工日报、节点验收和整改已有后端实现，且施工日报与节点验收已完成一条生产双模拟器 UI 闭环；仍需继续完善业主项目视图、节点失败后的整改/重新申请真机复验，并把“已选定/已支付/开工”之间的状态推进做成真实闭环。
- 聊天房间与消息表已有后端与 Flutter REST/WS 基础链路；仍缺离线推送、客服协同和更完整的消息运营后台。
- 通用文件上传已使用 ECS 本地持久目录，工人案例、日报和聊天图片可走真实上传；仍缺正式对象存储、CDN 和图片审核。
- 收藏、评价、动态、举报、售后与反馈。
- 支付当前为线下付款上报与工人确认收款的诚实闭环；真实支付、退款、结算/对账和资金托管仍未接入支付机构，不会假成功。
- 已有受保护管理 API、管理员操作审计和分页/筛选校验；仍缺可视化管理后台。
- 生产仍为公网 HTTP 直连 IP；缺域名、HTTPS、Nginx/反代、正式短信、推送、监控告警和自动化备份。

### Flutter 集成缺口

- 当前产品交付与本地端到端验证目标仅为 Android；iOS 脚手架目录已删除，如未来恢复 iOS，需要重新生成平台工程并单独完成签名、权限和真机适配。
- 核心业主到工人闭环已改为真实 REST 路径：认证、资料、工人目录/详情/案例、服务请求多候选、预约、接单、上门时间、双方到场、报价比价、最终选人、日报、节点验收、聊天、线下付款上报和工人收款确认。非核心展示页仍有本地演示内容。
- 生产公网 API 的业主预约、工人查看真实业主信息、工人接单、业主回读状态已验证；Android Studio 模拟器已可视化验证工人端登录、真实预约卡片展示和 UI 点击“立即接单”闭环。当前证据包括 APK 构建、工人端模拟器截图、UI 点击后工人端待接单列表清空，以及业主 API 回读 `ACCEPTED`。
- 业主端消息页已补真实接单反馈生成与 Tab 切换刷新，并已在 `Zhidi_API35` Android 模拟器上完成截图复验：登录业主测试账号后，消息页显示 2 条真实“工人已接单”通知。
- 旧 Firestore 桥接和核心流程中的本地假成功路径已移除；仍需继续清点非核心页面的演示数据，避免用户误以为已上线。
- 通用上传、聊天 REST/WS 与完整项目主状态已形成生产链路；仍缺系统推送、真实支付和应用商店级稳定性复验。
- 业主端当前允许未登录浏览首页；首页以外底部 Tab 会触发登录，未登录时不显示受保护消息红点。

## 5. 当前优先方向

建议按依赖顺序推进：

1. JWT 入站认证、统一当前用户身份和权限测试已完成。
2. 业主资料 GET/PUT、Android 首次引导闭环、业主端 app shell 路由、设置退出、个人中心基础 UI、报价收藏、报价页保存入口、工人详情报价入口、完整工种工价数据映射、透明工价列表页、施工中师傅/阶段完成状态底座、“我的家”最小施工进度页、工人详情预约写入施工进度链路、工人列表进入详情预约链路、本地验收申请/通过/驳回闭环、验收通过自动归档展示和材料估算确认采购已验证；下一步继续拆分地址扩展等 Flutter 未提交改动，再推进工匠账号与资料。
3. 工匠短信注册/登录、当前资料 GET/PUT、公开列表和详情已完成；业主端工匠列表/详情已在 Android 模拟器联调真实后端工匠数据。
4. 生产公网 API 已验证工匠真实预约列表与接单闭环；下一步做 Android 双端可视化联调、强停重启会话恢复实测，并推进派单、取消/改约、状态历史，逐步替换现有本地与 Firestore 订单桥接。
5. 工匠施工案例和案例图片上传已完成；继续完成报价、施工项目、日报、验收和通用文件上传。
6. 最后建设消息通知、支付、管理后台和生产部署能力。

`docs/superpowers/plans/2026-07-14-owner-profile-backend.md` 是较早的业主资料后端计划；当前以主工作区未提交源码和最新验证结果为准。

## 6. 运行与验证

启动本地后端（需要 MySQL）：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw spring-boot:run \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

Swagger：`http://localhost:8080/swagger-ui/index.html`

启动 Flutter 业主端：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
../flutter/bin/flutter run \
  --flavor owner \
  --dart-define=ZHIDI_APP_FLAVOR=owner \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

Flutter 检查：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_app
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter analyze
HOME=$PWD/.codex-flutter-home ../flutter/bin/flutter test
```

后端测试：

```bash
cd /Users/liupei/Documents/zhidi/zhidi_server
MAVEN_USER_HOME=/Users/liupei/Documents/zhidi/.m2 ./mvnw test \
  -Dmaven.repo.local=/Users/liupei/Documents/zhidi/.m2/repository \
  -s /Users/liupei/Documents/zhidi/.m2/settings.xml
```

## 7. Codex 接手任务的最小流程

1. 读本文件。
2. 运行 `git status --short`，不要覆盖现有修改。
3. 根据任务只读相关入口、模型、服务和测试。
4. 检查对应计划是否真的已实现；以源码、迁移和测试为准。
5. 修改前说明范围，修改后运行与风险相匹配的验证。
6. 若能力状态发生变化，精简更新本文件的“已完成/未完成”。

## 8. 状态维护规则

- 只记录已由源码、迁移或测试验证的事实。
- 规划功能保留在“未完成”，不能因为存在设计/计划文件就移到“已完成”。
- 更新时修改“最近核对”日期，并删除过时描述，避免只追加内容导致文件膨胀。
- 保持本文件可在几分钟内读完；实现细节用链接指向源码或专题设计文档。

## 9. 源码基线与整改验证

2026-07-17 已按 `docs/superpowers/specs/2026-07-17-source-baseline-cleanup-design.md` 整理成可恢复、可验证的源码基线。详细报告：`docs/source-baseline-report-20260717.md`。

2026-07-18 已按 `docs/superpowers/plans/2026-07-18-production-roadmap-remediation.md` 修正 Android 正式上线路线实现中的阻断问题，并将后端部署到 ECS `47.109.0.191`。未执行 git commit、push。

最新本地验证结果：

| 项目 | 结果 |
|------|------|
| 后端全量测试 | `./mvnw test`：193 tests, 0 failures, 0 errors, BUILD SUCCESS |
| Flutter analyze | `flutter analyze`：No issues found |
| Flutter 全量测试 | `flutter test --reporter compact`：171 passed, 3 skipped，All other tests passed |
| Owner release APK | `output/apks/zhidi-owner-1.0.0-release-20260722.apk`，87 MB，包名 `com.zhidi.owner`，SHA-256 `33d4fa35eb5fa8750a3187b001dd202d35a65e3db1f1de56b710e646b7b65630` |
| Worker release APK | `output/apks/zhidi-worker-1.0.0-release-20260722.apk`，87 MB，包名 `com.zhidi.worker`，SHA-256 `716fe89c0a1191e895cd7c90422b478627dd925b1358ad31b9330a5f42357c03` |
| ECS 后端部署 | `/opt/zhidi/zhidi-server.jar`，SHA-256 `bc450910d95578d19ff2b3a370e141f20ecbf6569854585b14dfa25291f1eaf4`，Flyway V17，`/actuator/health` 为 `UP` |

ECS 发布备份位于 `/opt/zhidi/backups/20260718150120/`，包含旧 jar、`.env` 备份和迁移修复前数据库 dump。发布期间生产 V14/V15 迁移分别遇到 MySQL 非事务 DDL 半成品表和默认管理员账号已有手机号但 UUID 不同的问题；已修正 V15 并用回归测试覆盖，生产最终无失败迁移记录。

已复核改动清单，范围集中在 Android flavor 识别、生产配置、服务请求/预约/报价/日报/验收/支付边界、数据库迁移、对应测试和项目状态文档。

2026-07-19 修复业主端“我的预约”远程取消时的 Flutter `Dismissible` 红屏：取消请求现在会先等待服务器成功并从状态列表移除预约，再完成滑动动画；失败时保留预约并提示重试。新增本地删除及延迟远程取消两条组件回归测试。

2026-07-19 针对 Android 真机反馈补强工人上门时间与双端验证码流程：工人提交上门时间前会先刷新服务器预约并验证该预约仍属于当前账号且保持已接单状态，陈旧预约不再携带旧 `bookingId` 请求服务器；业主端和工人端验证码均绑定发送时手机号，修改手机号会清空旧验证码并允许重新获取，避免把已被服务器作废的旧验证码误报为偶发登录失败。

2026-07-19 补全业主端候选师傅决策入口：候选列表整卡可进入服务器真实工人详情并查看公开施工案例，详情页可直接添加候选；候选以服务器添加成功为准，最多三位且禁止重复，页面底部提供“完成选择（已选 X/3）”，从首页匹配入口完成后切换“我的家”并触发真实需求刷新。候选页、真实案例和首页回归测试共 22 项通过，Flutter 全量静态检查无问题；真机可视化复验仍需使用本次新 APK 完成。

2026-07-22 完成 V17 生产闭环部署与公网 API 复验：在 ECS `47.109.0.191` 使用 release JAR 跑通业主注册/登录、业主资料、工人注册/登录、工人资料、业主查看工人、创建服务需求、添加候选、工人待接单、接单、提出上门时间、业主确认、双方到场、固定目录报价、业主比价和选人、工人日报、业主查看日报、节点验收、聊天、业主线下付款上报、工人确认收款、工人端结算 `SETTLED`。发布前备份位于 `/opt/zhidi/backups/20260722230245-pre-v17-deploy/`。
