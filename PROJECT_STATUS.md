# 知底项目状态

> Codex 快速上下文。最近核对：2026-08-09（P0/P1 单工种交易闭环已合并到 `main` 并部署 ECS，生产 Flyway 到 V33；双端生产 API debug APK 已生成但未自动安装到真机/模拟器）。开始任务时先读本文件；只有任务涉及的部分才继续读取源码或 `docs/superpowers/` 下的设计与计划。

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
- 2026-07-31 已按“业主直接找工人”的产品方向继续优化业主端候选师傅页：顶部改为轻量工种/城市摘要、最多 3 位候选提示和“综合排序 / 经验优先 / 看案例 / 可预约”筛选胶囊；师傅条目升级为横向榜单式资料名片，展示姓名、认证、工种、城市、工龄、擅长领域、自我介绍摘要、案例/可预约/资料完整标签。为降低业主浏览压力，右侧操作调整为轻量“查看详情”和橙色主动作“加入候选/已加入”，头像与文字层级也改为更柔和的名片风格。页面不展示平台价，也不伪造评分、距离、订单数等后端暂未提供的数据；已通过 `flutter analyze`、`flutter test test/candidate_picker_page_test.dart`、业主端 debug APK 构建安装和 `emulator-5554` 可视化复验，截图为 `zhidi_app/output/evidence/owner-candidate-comfort-v5-live.png`。
- 2026-08-01 已继续把业主端候选师傅页的信任信息改为真实服务端字段：公开工匠目录 `WorkerDirectoryResponse` 新增 `caseCount` 和 `hiredCount`，由工人工地案例数与 `HIRED` 预约数计算；Flutter 目录模型兼容旧响应，缺失时按 0 展示。候选卡片不再写死“案例”，而是展示“X个案例/暂无案例”和“X次被选中/可预约”；头像也改为更干净的首字母头像 + 小认证标，减少视觉杂乱。已通过后端 `WorkerProfileServiceTest`、`WorkerDirectoryControllerTest`，Flutter `candidate_picker_page_test.dart`、`worker_directory_api_client_test.dart`、`flutter analyze`、后端编译和业主端 APK 构建安装；模拟器截图为 `zhidi_app/output/evidence/owner-candidate-real-trust-v7-live.png`。本地后端字段变更尚未发布到 ECS，发布后线上候选页才会显示真实案例数/被选中次数。
- 2026-08-01 已修复业主端候选详情“取消失败：internal server error”：根因是详情页使用旧的服务请求状态，服务器订单已进入上门/后续流程时仍显示“取消”，且后端把不可取消的业务规则抛成未处理 500。现在候选详情进入后会重新拉取最新服务请求并刷新候选状态，已上门/后续流程不再展示普通取消；后端 `ownerCancel/workerCancel` 会把不可取消返回为 409 `BOOKING_CANNOT_CANCEL` 和中文提示。已通过 Flutter `my_home_minimal_page_test.dart`、候选页/目录相关测试、`flutter analyze`、后端 `BookingCancellationUnitTest` 与 `BookingControllerTest`，后端 jar 已备份并部署到 ECS，公网健康检查 `UP`；新版业主端 debug APK 已安装到 `emulator-5554`。
- 2026-08-01 已优化业主端“我的家 > 我的装修需求”展示：同一工种的历史重复服务请求不再逐条堆叠，列表按工种合并为一个入口；合并时优先保留更有进展的请求（状态更靠后、有候选、有邀请、更新时间更新），只影响 Flutter 展示层，不删除服务器真实数据。新增 `deduplicates service requests by trade in my decoration needs` 回归测试，`test/my_home_minimal_page_test.dart` 与 `flutter analyze` 通过；业主端公网 debug APK 已重新构建并安装到 `emulator-5554`。
- 2026-08-01 已修正业主端候选详情已支付后仍显示“去支付”的误导：候选详情现在会读取业主支付订单列表并按 bookingId 匹配支付状态，未付款显示“去支付”，业主已上报线下付款显示“待师傅确认收款”，工人确认后显示“已支付 · 查看记录”；点击仍可进入支付页查看记录，但不再用橙色支付 CTA 诱导重复付款。新增 `paid selected candidate shows paid record instead of pay CTA` 回归测试，`test/my_home_minimal_page_test.dart` 与 `flutter analyze` 通过；业主端公网 debug APK 已重新构建并安装到 `emulator-5554`。
- 2026-08-01 已修正业主端“我的家 > 装修费用”仍显示 ¥0 的问题：页面级加载业主支付订单并按 bookingId 取最新状态，费用卡优先使用已支付/业主已上报付款的支付订单金额汇总；没有真实支付订单时才回退到已保存报价或本地估算。新增 `cost card syncs confirmed amount from paid payment orders` 回归测试，`test/my_home_minimal_page_test.dart` 与 `flutter analyze` 通过；业主端公网 debug APK 已重新构建并安装到 `emulator-5554`。
- 2026-08-01 已补齐业主端“我的家 > 装修费用”的人工/辅料拆分：页面加载已支付订单时会同步拉取对应预约的报价明细，优先用报价项 `laborFee` 计算人工费用，并把已支付总额扣除人工后的剩余金额展示为辅材费用，避免截图中“已确认 ¥310、人工 ¥310、辅材 ¥0”的信息不完整问题；若报价明细缺失或没有拆分字段，仍保留原来的安全回退。回归测试已覆盖 `已确认 ¥310 / 人工 ¥200 / 辅材 ¥110`，`test/my_home_minimal_page_test.dart`、`flutter analyze` 和业主端 debug APK 构建安装通过。
- 2026-08-01 已按用户要求清空生产测试账号与业务数据，方便从头复测：清理前完整备份位于 ECS `/opt/zhidi/backups/20260801222249-clean-test-accounts/zhidi-before-clean-test-accounts.sql`。清理后仅保留 1 个 ADMIN 管理员账号；业主资料、工人资料、服务需求、预约、报价、支付订单、聊天房间/消息、日报、验收、售后、结算、质保金和验证码表均为 0；`service_catalog` 与 `flyway_schema_history` 保留。已清除 `emulator-5554` 业主端和 `emulator-5556` 工人端本地应用数据并重新启动双端；后端健康检查 `UP`，公网公开工人列表返回空数组，`test/my_home_minimal_page_test.dart` 通过。
- 2026-08-05 已精确清理当前双端复测账号：业主 `19938919913`、工人 `13333333333` 及其资料、地址、服务需求、预约、报价、聊天、日报、验收、付款、结算、质保金、验证码和关联审计数据均回查为 0，其他用户与公共价目数据未处理。清理前完整备份位于 ECS `/opt/zhidi/backups/20260805003418-clean-current-test-accounts/zhidi-before-clean.sql`。双模拟器应用数据已清除并冷启动，工人端回到登录页、业主端回到未登录首页；生产后端健康检查为 `UP`。
- 2026-08-05 已修复业主端“我的预约”对终态订单仍允许侧滑取消的问题：只有待接单、已确认、待确认上门时间、已约定上门和待确认到场的远程预约允许侧滑取消，已拒绝、已取消及后续状态不再触发取消接口；后端继续保留 409 `BOOKING_CANNOT_CANCEL` 作为业务保护。Widget 回归 3 项、预约状态同步回归合计 10 项及 `flutter analyze` 均通过；生产地址版业主 debug APK 已覆盖安装到 `emulator-5556`，用现有“已拒绝/已取消”订单实机侧滑复验无弹窗、无错误提示。两台模拟器同时安装并启用 Fcitx5 拼音输入法，均已实际输入 `nihao` 并显示“你好”候选。
- 2026-08-05 已修复工人端“确认业主已到场”返回 500：根因是 `BookingService.confirmArrival` 在一次请求中依次写入工人与业主两个到场标记，第一个写入已将订单推进为 `ON_SITE`，第二个写入随即因状态不再是 `ARRIVAL_PENDING` 抛异常并回滚。现在只写入当前确认方的标记，由领域状态机在双方标记齐全时一次推进到 `ON_SITE`。新增成功路径集成回归先失败后通过，后端全量 227 项测试为 0 失败；修正版 JAR 已备份旧包并部署到 ECS，备份目录 `/opt/zhidi/backups/20260805222904-pre-arrival-confirm-fix/`，公网健康检查为 `UP`。真实订单 `dc21e1f2-52a8-4487-b861-7a94945fc848` 已在工人模拟器重新点击确认，界面进入“已到场/提交报价单”，数据库回查为 `ON_SITE` 且双方到场标记均为 1。
- 2026-08-06 已修复工人端报价数量删除最后一个数字后输入框自动收起的问题：项目勾选状态与数量值已解耦，空数量保留勾选、输入框和焦点，金额按 0 计算且提交按钮禁用，重新输入数字后小计、总价和提交状态即时恢复。新增 Widget 回归先失败后通过，报价页 3 项测试与 `flutter analyze` 均通过；工人 debug APK 已安装到 `emulator-5554`，用真实木工报价页复验删除 `1` 后输入框保持空白，再输入 `5` 后总价恢复为 `¥600`，未提交真实报价。
- 2026-08-06 已补齐报价确认前的双端透明展示：业主报价对比卡按“人工明细 / 材料明细”展示项目、单价、数量、单位和小计，并在工人报价总价之外增加 10% 平台服务费及业主应付总额；最终选人二次确认会再次核对三项金额并明确服务费不从工人报价中扣除。工人订单在报价已提交及后续状态可从订单详情读取服务器真实报价，打开共用报价明细页查看人工和材料清单，工人侧不显示业主平台服务费；加载失败保留订单页并可重试。业主报价、工人订单详情和报价输入共 15 项 Widget 测试通过，`flutter analyze` 无问题；公网配置的双端 debug APK 已覆盖安装到 `emulator-5556`（业主）和 `emulator-5554`（工人），两端均冷启动成功。
- 2026-08-06 已修正工人端验收合格后的资金状态：预约自动归档为已完成不再等同于已经付款；没有结算记录时完工档案和底部操作明确显示“等待业主付款”，并从服务器已接受报价按 90%/10% 展示“预计可结算 / 预计质保金”，不再误显示“本单可结算 ¥0 / 本单质保金 ¥0”。支付订单会保留在工人状态中：业主已上报付款时入口切换为“核对明细并确认收款”，真正形成结算与质保记录后才显示“本单可结算 / 本单质保金”和“查看收入明细”。新增未付款完工单回归覆盖报价 ¥10440 → 预计可结算 ¥9396、预计质保金 ¥1044。
- 2026-08-06 已在本地完成新订单 `OFFLINE_SPLIT_V2` 资金闭环：业主将报价总额 100% 线下支付给工人，另将报价 10% 平台服务费支付到公司账户；工人确认工程款、管理员核验服务费后订单才完成。新订单不再从业主付款中冻结质保金，工人改为按每单报价 10% 向独立履约质保账户补充，有效余额封顶 ¥10000；待补充、待释放或售后扣减未补足时禁止接新单。旧订单继续使用 `LEGACY_OWNER_RETENTION`，旧金额与旧质保记录不重算。Flyway V24、双付款/管理员核验 API、质保账户/义务/流水/释放 API、售后扣减、微信未配置 503 边界和双端新旧 UI 分支均已实现；后端全量 247 项、Flutter 全量 260 项通过（3 项按既有条件跳过），`flutter analyze` 无问题，后端 JAR 与 owner/worker debug APK 构建成功。该版本**尚未部署到 ECS，也未安装到公网闭环模拟器**；生产仍运行 V23 与旧 90%/10% 单笔质保口径。部署前必须分别配置公司服务费账户和工人履约质保账户环境变量，真实微信支付仍未配置。
- 2026-08-07 工人端全部新旧订单入口已隐藏业主平台服务费：新订单仍显示全额工程款、到账状态与独立履约质保账户，历史订单仍显示报价、可结算金额和历史质保；升级前已保存的旧付款消息会在恢复时原位脱敏并重新保存。最终复审通过，严格文案扫描无匹配，三文件关键回归 34 项通过，`flutter analyze` 无问题，Flutter 全量测试 265 项通过、3 项按既有条件跳过。新版 worker debug APK 为 `zhidi_app/build/app/outputs/flutter-apk/app-worker-debug.apk`（211054815 bytes，SHA-256 `ed11e285849dd34622a68c281671bbed274a1d055c77881f3e47ff3d8b99722a`，使用 `API_BASE_URL=http://47.109.0.191:8080` 构建）。用户发现模拟器仍显示旧服务费行后，回查确认 `Zhidi_Worker_API35` 安装的是 2026-08-06 旧包（SHA-256 `e9dcea9a9cedfe1a4c2a1d6770c0e0954a689b7c49286dd8d615b8874826fecd`）；现已保留数据覆盖安装新包，安装包哈希与构建产物一致，并用同一笔 ¥10840 历史订单现场复验：只显示报价总价、可结算 ¥9756 和历史质保金 ¥1084，不再显示平台服务费，证据为 `zhidi_app/output/evidence/worker-settlement-after-fee-visibility-install-20260807.png`。本地源码改动尚未部署到 ECS、尚未提交。
- 2026-08-07 已修复业主端木工完工后仍停在“施工中”及验收记录无限转圈：生产库该木工预约已为 `COMPLETED`、验收节点为 `PASSED`、记录为 `PASS`，问题来自业主模拟器旧 APK 以及从验收页返回后未刷新服务请求；现在返回“我的家”会重新读取服务器状态，项目卡显示“已完成”并激活最后进度节点。验收记录子页改在依赖可用后加载，不再于 `initState` 读取 `OwnerAppScope`，失败时显示原因和重试入口，结果标签改为中文“已通过/未通过”。相关 21 项 Widget 回归与 `flutter analyze` 均通过；公网 owner debug APK（SHA-256 `6f7cfbfa50d4bcc63e45ad02541a9f627f8bbb9b8bf3aa08e759ae758a22987c`）已保留数据覆盖安装到 `Zhidi_API35`，现场确认木工项目为“已完成”、验收记录显示“第 1 次验收 / 已通过”，且日志无原生命周期异常。证据为 `zhidi_app/output/evidence/owner-my-home-completed-final-verified-20260807.png`、`zhidi_app/output/evidence/owner-inspection-records-final-verified-20260807.png`。本次只更新 Flutter 业主端，未改动或部署后端，尚未提交。
- 2026-08-07 已修复工人拒单后业主端仍强制进入候选工作台的状态串线：Flutter 现与后端统一将 `REJECTED / CANCELLED / NOT_SELECTED` 视为已结束候选，不再进入顶部当前项目、不计入候选人数，详情中归入“已结束”并禁止取消操作；同工种有新需求时优先展示新建需求，因此木工师傅拒单后业主会看到“待匹配 / 0 位候选 / 1 次邀请”，可继续选择其他师傅。同时“我的装修需求”已按候选 `COMPLETED` 显示绿色“已完成”。`test/my_home_minimal_page_test.dart` 17 项全部通过，`flutter analyze` 无问题；公网 owner debug APK（SHA-256 `70985cc670826cc7858ad95d76a42590d95f991c6d8453d3590a9365e1a68cf6`）已保留数据覆盖安装到 `emulator-5556`，用服务器真实已拒绝订单现场复验通过，运行日志无 Flutter 异常或布局溢出。证据为 `zhidi_app/output/evidence/owner-rejected-worker-returned-to-matching-20260807.png`、`zhidi_app/output/evidence/owner-rejected-worker-ended-history-20260807.png`。本次仅更新 Flutter 业主端，未改动或部署后端，尚未提交。
- 2026-08-07 业主端候选师傅页已增加当前业主专属的真实“已合作”标识：页面并行读取该业主历史需求，只把非当前需求中同一 `workerUserId` 且候选状态为 `READY_TO_START / HIRED / COMPLETED` 的师傅标为绿色“已合作”；不再用全平台 `hiredCount` 冒充合作关系，待接单/拒绝等状态和当前需求也不会误标。历史接口失败时保留原信任信息且不阻塞找师傅，已合作师傅仍可再次“加入候选”。候选页及目录相邻回归 23 项通过、1 项按既有条件跳过；Flutter 全量测试 276 项通过、3 项按既有条件跳过，`flutter analyze` 无问题；公网 owner debug APK（211056345 bytes，SHA-256 `8e905b3641420c694906fb7422c7a90886cd28f25c67b5a12e94bded3212e6ab`）已保留数据覆盖安装到 `emulator-5556`，并以服务器真实已完成木工合作现场确认“已合作”和可用“加入候选”同时显示，运行日志无 Flutter 异常或布局溢出。证据为 `zhidi_app/output/evidence/owner-candidate-cooperation-badge-20260807.png`。本次仅更新 Flutter 业主端，未改动或部署后端，尚未提交。
- 2026-08-08 已完成 P0 真实用户就绪整改：业主/师傅端以完整 `serviceRequestId + bookingId` 隔离需求、候选、报价、验收和付款；旧完工项目不再覆盖新需求，拒单/取消/未选中不再算活跃候选，报价刷新不再复用旧金额；订单消失不再回退到列表第一单，切号、退出和过期会话会清除并隔离上个账号业务数据。生产入口只使用服务端真实师傅资料、案例、预约和聊天室，移除本地预约/聊天假成功以及未经支持的认证、在线、托管、自动退款等承诺；价格页明确本地参考价与服务器报价边界。双端新增基于真实 REST 状态变化的前台应用内通知和精确深链，并对目标失效与临时网络故障分开处理；该能力不是系统推送，工人售后仍因后端缺少可发现列表而未伪造。完整整改记录见 `docs/superpowers/plans/2026-08-08-p0-real-user-readiness.md` 和 `.superpowers/sdd/2026-08-08-p0-real-user-readiness/`。本地最终验证为后端 249 项全通过、Flutter 333 项通过/3 项跳过、`flutter analyze` 无问题；部署状态见 2026-08-09 条目。
- 2026-08-09 已把 P0/P1 单工种交易闭环合并并部署到 ECS：`main` 当前提交为 `2bc660da18fd1c793c51748ad99d220e6e875988`，生产 JAR SHA-256 为 `a8b836e6b7454a2c724883908a2bdd85eefc3cbceb3d41cb946c9732410e8572`，`zhidi.service` 已重启且公网健康检查 `UP`；Flyway 生产迁移已到 V33 `payment reference claims`。发布前备份位于 `/opt/zhidi/backups/20260809155342-pre-p1-task8/`，包含旧 JAR、systemd、`.env` 和数据库 dump。本轮也已用 `API_BASE_URL=http://47.109.0.191:8080` 构建双端 debug APK：`zhidi_app/output/apks/zhidi-owner-debug-20260809-p1-task8.apk`（SHA-256 `ea76c1bdcaf3a3bb333523c76fe736795df825449b433ebb3add8f57ece323fa`）与 `zhidi_app/output/apks/zhidi-worker-debug-20260809-p1-task8.apk`（SHA-256 `cbefe38b71b38bd64a7491d0d426261620b49640b78af5d7ad0761897b7cda3e`）；尚未自动安装到真机/模拟器。
- 2026-08-01 已修复工人端待接单卡片需求文案和业主端互动消息同步：工人端订单卡片不再显示“油漆师傅（）”，会按业主需求显示“需要油漆师傅”，面积为空时去掉空括号；业主端消息页现在会调用真实 `GET /api/v1/chat/rooms` 拉取聊天室预览，互动消息 Tab 显示工人发送的最新消息和未读数，点击进入真实 `ChatDetailPage` 并在返回后刷新，不再只读本地旧 `chatMessages`。新增 `pending order card describes needed trade without empty area` 与 `owner interaction messages show remote chat room previews` 回归测试，`flutter analyze` 通过；业主端和工人端公网 debug APK 已重新构建并安装到 `emulator-5554`/`emulator-5556`。
- 2026-08-01 已修复工人端订单详情顶部右侧溢出：小屏幕下“等待业主确认上门时间”等长状态与 UUID 订单号同排展示时，订单号现在会在右侧单行省略，不再触发 Flutter `RIGHT OVERFLOWED`。新增 `order detail header handles long status and order id` 回归测试，`test/worker_order_detail_refresh_test.dart`、`flutter analyze` 和工人端公网 debug APK 构建安装通过。
- 2026-08-01 已补齐业主端“师傅预约上门”订单通知：业主端同步远程预约时，除 `PENDING/ACCEPTED` 外，现在会对 `VISIT_PROPOSED` 生成去重的“待确认上门时间”预约通知，提示业主前往订单确认上门时间；消息页的“订单通知”分类可同步显示。新增 `fetchRemoteBookings adds owner message when worker proposes visit time` 回归测试，`test/owner_booking_state_sync_test.dart`、`flutter analyze` 和业主端公网 debug APK 构建安装通过。
- 2026-07-29 已按用户要求清空生产测试账号和测试业务数据：ECS MySQL 清理前备份为 `/opt/zhidi/backups/zhidi-before-test-cleanup.sql`，清理后仅保留管理员 `13800000000/ADMIN`，业主/工人资料、服务需求、预约、报价、日报、验收、支付和验证码表均为 0。随后用干净账号 `19672900201`（业主）与 `19772900201`（工人）重新跑公网双模拟器真实 UI：业主登录验证码自动填入、找水电师傅、添加 `UI闭环水电师傅` 候选、完成选择后“我的家”显示待接单；工人端登录后真实显示待接单卡片，点击“立即接单”后服务器状态为 `ACCEPTED`，业主消息页出现“工人已接单”，我的家变为“待上门”；工人端提出 2026-07-30 09:00 上门时间后服务器状态为 `VISIT_PROPOSED`，业主候选详情“确认时间”后状态为 `VISIT_SCHEDULED`。证据截图包括 `output/evidence/owner-clean-candidate-list-20260729.png`、`owner-clean-my-home-after-complete-20260729.png`、`worker-clean-pending-after-login-20260729.png`、`owner-clean-message-after-worker-accept-20260729.png`、`worker-clean-after-propose-visit-20260729.png`、`owner-clean-after-confirm-visit-20260729.png`。该测试账号暂保留用于继续验证双方到达、报价、验收和付款；完成后需再次清理。
- 2026-07-29 已继续跑完干净账号公网双模拟器后半段闭环：工人端“我已到达”后服务器进入 `ARRIVAL_PENDING`，业主端确认师傅到场后进入 `ON_SITE`；工人端加载服务端固定水电价目并提交 `水管检修 + 电路检修` 报价 ¥160，业主端“我的家”显示 `报价待确认/¥160`，勾选协议并二次长按确认后服务器 `bookings.HIRED`、`quotes.ACCEPTED`；工人端提交施工日报后业主候选详情可看到同一条日报；工人端发起水电节点验收，业主端 UI 通过第一个节点，其余同接口节点通过后支付页成功生成线下付款订单，业主上报已付款、工人确认实际收款后 `payment_orders.status=WORKER_CONFIRMED_RECEIVED`、工人结算 ¥160。同步修复本轮复验发现的 3 个业主端问题：`ARRIVAL_PENDING` 时“我的家”项目工作台直接显示“确认师傅已到场”并调用真实接口；报价清单在 quote 缺少 `workerName` 时使用候选工人名，不再显示“未知师傅/该师傅”；支付页不再在 `initState` 读取 `OwnerAppScope` 导致生命周期错误。验证命令包括 `flutter test test/owner_quote_confirmation_test.dart test/my_home_minimal_page_test.dart test/owner_payment_page_test.dart`、`flutter analyze`、业主端公网 debug APK 构建安装，以及生产 API 回查报价、日报、验收、支付订单状态。复验完成后已按要求再次清理测试账号 `19672900201`、`19772900201` 及关联业务数据，清理前备份位于 `/opt/zhidi/backups/20260729-clean-ui-final/zhidi-before-clean-ui-final.sql`，回查测试用户、资料、预约、服务需求和支付订单均为 0。
- 2026-07-29 继续修复清理测试账号后模拟器旧登录态导致的真实接口 401：聊天 API 现在会保留后端 `UNAUTHORIZED/access token invalid` 等真实 code/message，不再统一包装成 `CHAT_ROOM_FAILED`；业主端创建需求和业主/工人聊天入口遇到 401 会清除本地登录态并提示“登录已过期，请重新登录”，避免旧账号已从服务器删除但本地仍显示旧订单、点击后报技术错误。已重新构建安装业主端 APK，并清除 `emulator-5554` 旧本地数据，当前业主端回到无旧登录态的干净首页。
- 2026-07-29 已修复工人端验证码登录重复点击问题：`WorkerLoginPage` 在登录请求 pending 时会立即忽略后续点击，并用 `finally` 可靠复位 loading，避免同一验证码被连续提交后端、第一次成功/处理中但后续请求返回“验证码不正确”。新增 Widget 回归测试 `worker login ignores repeated taps while request is pending`，已通过 `flutter test test/worker_login_page_test.dart` 与 `flutter analyze`；已重新构建公网工人端 debug APK 并安装到 `emulator-5556`，清空本地旧状态后用临时工人号真实 UI 连续点击登录，结果直接进入“完善工人资料”，未再出现验证码无效；临时测试号 `19772900301` 及验证码已从生产库清理为 0。
- 2026-07-29 已修复工人端“完善工人资料”保存失败只显示泛化错误的问题：`PUT /api/v1/workers/me` 现在会保留后端错误 envelope（如 `UNAUTHORIZED/access token invalid`），资料页遇到 401 会清除工人端本地登录态并提示“登录已过期，请重新登录”，避免已删除测试账号的旧 token 继续卡在资料页。新增 `auth_api_client_test.dart` 与 `worker_profile_onboarding_test.dart` 回归，连同 `worker_session_state_test.dart` 和 `flutter analyze` 通过；已重新构建公网工人端 debug APK，安装到 `emulator-5556` 并清空旧本地状态，当前工人端回到干净登录页。
- 2026-07-29 已同步修复业主端验证码登录重复点击问题：`LoginPage` 在登录请求 pending 时会立即忽略后续点击，避免同一验证码被连续提交。新增 Widget 回归测试 `repeated login taps send only one owner login request`，与工人端登录测试一起通过；`flutter analyze` 无问题。已重新构建公网业主端 debug APK，安装到 `emulator-5554` 并清空业主端本地旧状态。
- 2026-07-29 已按“业主直连工人、平台只做保障”的产品初心微调业主端“找师傅”页：保留现有沉浸式照片工种卡，不改成平台派单/分配模式；顶部说明从“平台马上匹配”改为“看资料、看案例、看工价，自己选师傅”；工种卡可用状态从“X位可接单/0位可接单”调整为“X位可预约/暂无可约 · 先看工价”，弱化平台分配感并降低 0 人状态的挫败感。已通过 `test/trade_select_page_visual_test.dart`、双端登录回归测试与 `flutter analyze`，并重新构建安装业主端公网 debug APK 到 `emulator-5554`。
- 2026-07-29 已修复业主端“我的家”预选候选师傅后误显示施工流程的问题：顶部工作台会根据候选状态切换为候选预约阶段或施工阶段；`PENDING/ACCEPTED/VISIT/ARRIVAL/ON_SITE/QUOTE_PENDING` 显示“师傅 · 候选”、预约/报价进度、预约记录与报价比价，不再显示“施工中/施工记录/验收”；只有 `HIRED` 后才进入施工项目文案。新增 `preselected candidate does not show construction workflow` 回归，相关“我的家/报价/验收”测试与 `flutter analyze` 通过；已重新构建并安装业主端公网 debug APK 到 `emulator-5554`。
- 2026-07-29 已修复工人端消息页不显示业主聊天消息的问题：工人首页“消息”Tab 现在会调用真实 `GET /api/v1/chat/rooms` 展示聊天会话预览，并保留原订单/报价/验收通知；点击聊天会话进入同一套 `ChatDetailPage` 真实聊天室。新增 `worker messages tab shows remote chat room previews` 回归，`test/worker_bottom_navigation_test.dart`、`test/chat_api_client_test.dart` 与 `flutter analyze` 通过；已重新构建并安装工人端公网 debug APK 到 `emulator-5556`。
- 2026-07-29 已修复工人端消息会话点击后未读气泡不消除的问题：后端新增 `POST /api/v1/chat/rooms/{roomId}/read` 标记房间已读；Flutter 聊天详情页打开后会调用已读接口，工人端消息列表点击会话时先本地乐观清零并在返回后刷新服务器会话列表；进入消息 Tab 时也会把本地订单/报价通知标为已读，避免底部消息红点进入页面后仍停留。新增 `marks a chat room as read` 和工人端消息红点回归，生产 ECS 健康检查 `UP` 且 Swagger 已包含新接口。
- 2026-07-29 已修复工人端节点验收按固定四节点生成的问题：工人端验收页现在按当前订单工种生成并展示单一对应节点，例如水电订单只生成“水电验收”、泥瓦订单只生成“泥瓦验收”；历史订单若已存在其他工种旧节点，前端会过滤为当前工种节点。新增“只创建当前工种节点”和“隐藏历史杂节点”回归测试，`flutter analyze` 通过，并已构建安装工人端公网 debug APK 到 `emulator-5556`；现场复验泥瓦订单只显示“泥瓦验收”。后续资金闭环需继续实现验收通过后工人可结算 90%、冻结 10% 质保金。
- 2026-07-30 已修复业主端生成支付订单仍要求“全部验收节点通过”的后端旧规则：`PaymentOrderService` 现在只校验当前预约工种对应验收节点是否已通过，历史残留的其他工种节点不再阻塞付款。新增后端回归 `paymentOrderOnlyRequiresTheBookingTradeInspectionToPass`，已打包部署到 ECS，健康检查 `UP`；在业主端 `emulator-5554` 原支付页重新点击“生成支付订单”已成功生成 ¥310 线下支付订单。下一步继续把资金结算从当前全额结算改为验收通过后 90% 可结算、10% 质保金冻结。
- 2026-07-30 已实现线下支付订单的 90%/10% 质保金规则：新生成的线下付款订单会把 `workerSettlement` 计算为报价金额 90%，`warrantyRetention` 计算为 10% 并通过支付订单 API 返回；业主端支付明细显示“工人可结算 90%”与“质保金冻结 10%”。工人确认实际收款后生成的结算记录只记录 90% 可结算金额，10% 暂作为冻结质保金展示，不会在当前线下结算里提前发给工人。后端回归 `PaymentOrderOfflineFlowTest`、`PaymentOrderServiceOfflineTest`，Flutter 回归 `payment_models_test`、`payment_api_client_test`、`owner_payment_page_test` 与 `flutter analyze` 均通过；ECS 已部署并健康检查 `UP`，最新业主端/工人端公网 debug APK 已安装到 `emulator-5554`/`emulator-5556` 并可启动。注意：历史已生成的支付订单不会自动重算 90/10，只有新订单适用。
- 2026-07-30 已继续补齐 10% 质保金账本：新增 `warranty_retentions` 表和 `GET /api/v1/warranty-retentions`、`POST /api/v1/admin/warranty-retentions/{id}/release`、`POST /api/v1/admin/warranty-retentions/{id}/deduct`；工人确认实际收款时会自动生成 `HELD` 质保金冻结记录，管理员可按售后处理扣减，质保结束后可释放剩余金额，记录会显示原始金额、已扣减、已释放和剩余冻结。工人端“结算”页已读取并展示质保金状态。后端回归 `PaymentOrderServiceOfflineTest`、`WarrantyRetentionServiceTest`，Flutter 回归 `payment_models_test`、`payment_api_client_test`、`owner_payment_page_test` 与 `flutter analyze` 通过；ECS 已部署并确认 Swagger 暴露 `/api/v1/warranty-retentions`，健康检查 `UP`，最新双端公网 debug APK 已安装到 `emulator-5554`/`emulator-5556`。
- 2026-07-30 已把售后处理与质保金扣减串联：`after_sales` 新增 `warranty_retention_id` 与 `warranty_deduction_amount`，管理员处理售后 `PUT /api/v1/admin/after-sales/{id}/process` 可选传 `warrantyDeductionAmount`；传入正数时，后端会找到该预约最新质保金记录并扣减，同时把扣减金额和关联质保金记录写回售后单。Flutter `AfterSaleModel` 已解析扣减结果。后端回归 `AfterSaleServiceTest`、`WarrantyRetentionServiceTest`、`PaymentOrderServiceOfflineTest`，Flutter 支付/售后模型测试与 `flutter analyze` 通过；ECS 已部署，健康检查 `UP`，Swagger 已确认暴露 `warrantyDeductionAmount`。
- 2026-07-30 已补齐最小管理端运营 API：`GET /api/v1/admin/after-sales` 支持按售后状态分页查看工单，`PUT /api/v1/admin/after-sales/{id}/process` 统一管理员处理售后并写入 `ADMIN_AFTER_SALE_PROCESS` 操作审计，`GET /api/v1/admin/warranty-retentions` 支持按质保金状态分页查看冻结/释放/扣减账本。原普通售后 Controller 只保留业主/工人创建与查询，避免管理路由分散。后端回归 `AdminControllerTest`、`AfterSaleServiceTest`、`WarrantyRetentionServiceTest` 通过，后端打包通过；ECS 已部署，健康检查 `UP`，Swagger 已确认暴露 `/api/v1/admin/after-sales` 与 `/api/v1/admin/warranty-retentions`。
- 2026-07-30 已新增最小可视化管理后台页面 `/admin.html`：运营人员粘贴管理员 JWT 后，可查看售后工单、提交处理结果并扣减质保金，也可查看质保金账本、手动扣减或释放剩余质保金。页面随 Spring Boot jar 打包到 `BOOT-INF/classes/static/admin.html`，后端聚焦测试 `AdminStaticPageTest`、`AdminControllerTest` 通过，ECS 已部署新 jar 且健康检查 `UP`；当前仍是最小运营台，正式后台的登录、角色管理、审计检索、筛选导出和移动端适配还需后续完善。
- 2026-07-30 已补齐管理后台最小登录入口：新增 `POST /api/v1/auth/admin/login`，管理员使用短信验证码登录后获得 ADMIN JWT；该接口只允许已有 ADMIN 角色账号登录，不会像业主/工人入口一样自动创建管理员账号。`/admin.html` 已支持管理员手机号发送验证码、验证码登录并自动保存 token，同时保留手动粘贴 JWT 兜底。回归 `AuthServiceTest` 与 `AdminStaticPageTest` 通过。
- 2026-07-30 已扩展管理后台运营总览：`GET /api/v1/admin/dashboard` 现在返回总用户、今日新增、活跃预约、待处理售后、待工人确认收款、冻结质保金金额、今日付款金额和预约状态分布；`/admin.html` 顶部已显示关键运营卡片，登录、处理售后、扣减/释放质保金后会刷新总览。回归 `AdminControllerTest`、`AdminStaticPageTest` 通过，后端打包通过。
- 2026-07-30 已在 `/admin.html` 增加订单查询和用户查询：订单页调用 `GET /api/v1/admin/bookings`，支持按状态和工种筛选并展示业主、师傅、地址、创建时间；用户页调用 `GET /api/v1/admin/users`，支持按手机号和角色筛选并展示角色、状态和用户 ID。当前这两页只读，避免后台误操作账号或订单；回归 `AdminControllerTest`、`AdminStaticPageTest` 通过，后端打包通过。
- 2026-07-30 已补齐后台操作审计查询：`GET /api/v1/admin/operation-logs` 支持按动作、目标类型和结果筛选分页查看操作记录；`/admin.html` 增加“操作审计”Tab，可查看操作时间、动作、目标、操作人、结果、traceId 和详情 JSON。该页面只读，用于追踪管理员售后处理、质保金扣减/释放和订单状态干预。回归 `AdminControllerTest`、`AdminStaticPageTest` 通过，后端打包通过。
- 2026-08-02 已整理并部署报价到收款确认的金额闭环：服务端新支付订单以工人报价为基数，业主应付金额为“报价总价 + 10% 平台服务费”，工人可结算为报价的 90%，另 10% 进入质保金冻结；工人确认收款信息后结算记录停留在 `SETTLEABLE`，不再错误地立即标记为已结算。业主付款页可打开原报价单并按“人工明细 / 材料明细”查看；工人端轮询到业主已报告付款后生成去重未读通知，点击直达对应费用明细和原报价单，再确认进入待结算。工人报价表已拆分人工与材料板块并支持直接输入数量，固定价目录补充常用材料项。已恢复本机 Docker Desktop，Flutter 全量 204 项通过、3 项按既有条件跳过，`flutter analyze` 无问题，后端全量 212 项通过；ECS Flyway 已到 V20、10 条材料目录已落库、公网健康为 `UP`。发布前备份位于 `/opt/zhidi/backups/20260802010842-pre-v20-payment-quote/`；新后端 JAR SHA-256 为 `1852665cf03a998e59b6d1d683987162bac4c04c78aa271b3ceaf84efb64d0cf`。双端 APK 为 `zhidi_app/output/apks/zhidi-owner-debug-20260802-payment-quote.apk`、`zhidi_app/output/apks/zhidi-worker-debug-20260802-payment-quote.apk`，已安装到 `emulator-5554/5556` 并完成冷启动复验，证据为 `output/evidence/owner-launch-20260802.png`、`worker-launch-20260802.png`。
- 2026-08-02 已修复业主端既有支付单仍显示平台服务费为 0：根因是唯一一笔生产测试支付单在新计费规则部署前生成。V21 只匹配“线下付款、平台费为 0、工人结算恰为原金额 90%”的旧规则指纹，将业主应付总额补为报价总价的 110%，不重复修改新规则订单。迁移容器回归与后端全量 213 项测试均通过；ECS Flyway 已到 V21，生产支付单已由“报价 ¥5800 / 平台费 ¥0 / 合计 ¥5800”修为“报价 ¥5800 / 平台费 ¥580 / 合计 ¥6380”，受保护的业主支付订单 API 已真实回读同一结果，健康检查为 `UP`。发布前备份位于 `/opt/zhidi/backups/20260802101148-pre-v21-platform-fee/`，当前后端 JAR SHA-256 为 `333ea17e5ca3199b73ef74b718c1f09a7bf4b11b2b628ee306af5c8da28e5648`。
- 2026-08-02 已修复工人端结算金额不可见：根因是工人首页和“收入明细”仍读取旧的本地模拟账本，未使用已上线的结算与质保金接口。现在首页顶部直接展示服务端“可结算 / 质保金”，点击顶部或“收入明细”均进入同一真实结算页，返回后自动刷新；当前生产测试账务已在模拟器显示可结算 ¥5220、冻结质保金 ¥580。Flutter 全量 205 项通过、3 项按既有条件跳过，`flutter analyze` 无问题；公网工人端 APK 为 `zhidi_app/output/apks/zhidi-worker-debug-20260802-real-settlement.apk`，已安装到 `emulator-5556`，证据为 `output/evidence/worker-real-settlement-home-20260802.png` 和 `worker-settlement-detail-20260802.png`。
- 2026-08-02 已实现“当前工种验收合格后自动完成订单”：业主把当前预约工种的全部验收节点判定为通过后，后端会在同一事务内把预约从 `HIRED` 推进到 `COMPLETED`；历史遗留的其他工种节点不会阻塞，驳回或仍有未通过节点时保持施工中。工人端把服务端 `COMPLETED` 只归入“已完成”，业主端项目工作台同步显示“已完成”，并继续保留报价、施工记录、验收记录和付款入口；付款服务兼容 `HIRED/COMPLETED`，不会因自动完成而断开支付闭环。Flyway V22 已安全扩展状态约束并回填符合条件的历史预约，ECS 生产 Flyway 已到 V22、健康检查 `UP`，订单 `a0729b92-f261-47ae-9b6f-54c2fde79aba` 已从 `HIRED` 回填为 `COMPLETED`。发布前备份位于 `/opt/zhidi/backups/20260802120116-pre-v22-booking-completed/`；本次后端全量 217 项通过，Flutter 全量 206 项通过、3 项按既有条件跳过，`flutter analyze` 无问题。双端 APK 为 `zhidi_app/output/apks/zhidi-owner-debug-20260802-inspection-completed.apk`、`zhidi_app/output/apks/zhidi-worker-debug-20260802-inspection-completed.apk`，已安装到 `emulator-5554/5556`；证据为 `output/evidence/owner-completed-after-inspection-20260802.png` 和 `worker-completed-after-inspection-20260802.png`。
- 2026-08-02 已修复业主端“项目已完成且已付款，顶部仍显示去支付”：根因是“我的家”已加载并按预约聚合了最新支付单，但顶部项目工作台没有接收该支付状态。现在无支付单/待支付显示“去支付”，业主已报告付款显示“待师傅确认收款”，工人确认后显示绿色单行“已支付 · 查看记录”；点击仍进入统一付款详情查看报价和付款记录。新增两个 Widget 状态回归及窄屏单行约束，`test/my_home_minimal_page_test.dart` 13 项通过、Flutter 全量 208 项通过且 3 项按既有条件跳过、`flutter analyze` 无问题。公网业主端 APK 为 `zhidi_app/output/apks/zhidi-owner-debug-20260802-payment-status.apk`，已覆盖安装到 `emulator-5554`，证据为 `output/evidence/owner-paid-project-button-20260802.png`。
- 2026-08-02 已补齐工人查看收入与已完工工地的入口：接单中心顶部“可结算 / 质保金”增加明确的“收入明细”提示并继续读取真实结算接口；“已完成”列表按预约展示本单可结算金额、质保金和“查看完工档案”，整卡可进入对应工地。完工档案保留业主、需求和报价信息，直接展示本单资金，并提供只读施工记录、验收记录、收入与质保金入口；已完成订单不再允许新增日报、自动创建验收节点或重新申请验收。完工后同时关闭直接联系能力：删除“联系业主”，业主手机号改为前三后四位脱敏，底部只保留通栏“查看收入明细”；施工中订单的联系能力和完整电话保持不变。`flutter analyze` 无问题，Flutter 全量 212 项通过且 3 项按既有条件跳过；公网工人端 APK 为 `zhidi_app/output/apks/zhidi-worker-debug-20260802-completed-archive.apk`（SHA-256 `8ad25004dc073beaeda2d519df419f4442c242605657b1392630abbbaf91e916`），已覆盖安装到 `emulator-5556`。可视化证据为 `output/evidence/worker-home-completed-archive-20260802.png`、`worker-completed-list-20260802.png`、`worker-completed-archive-detail-20260802.png`、`worker-completed-daily-readonly-20260802.png`、`worker-completed-archive-no-contact-20260802.png`，运行日志未发现 Flutter 异常或布局溢出。
- 2026-08-02 已完成业主资料与服务器地址簿闭环：首次资料只要求姓名和城市，手机号只读显示已验证，头像和性别为选填；个人中心可编辑资料并显示常用地址数量。地址簿支持新增、编辑、删除、切换默认、默认地址自动补位和手机号脱敏，全部以 Spring Boot + MySQL 为事实源，网络失败不再本地假保存。新建装修需求和直接预约必须使用默认地址快照，无地址时会引导先添加，历史 `profile.address` 不再兜底。后端 Flyway 已安全部署到 V23，生产健康为 `UP`，资料 GET/PUT 与地址 CRUD 公网实测通过；后端全量 225 项通过，Flutter 全量 231 项通过且 3 项按既有条件跳过，`flutter analyze` 无问题。业主端 APK 为 `zhidi_app/output/apks/zhidi-owner-debug-20260802-owner-profile.apk`；模拟器已从全新账号跑通登录、首次资料、默认地址、强停重启、资料编辑和找工种自动带入地址，证据为 `owner-profile-final-20260802.png`、`owner-address-default-20260802.png`、`owner-default-address-trade-20260802.png`。本轮临时账号、验证码、地址和两个临时需求已精确清理，模拟器应用数据也已恢复为未登录干净状态。
- 2026-08-02 已把业主地址的省份、城市、区县改为受控三级联动，首期只开放四川省和甘肃省：四川目录锁定 21 个市州、183 个县级行政区，甘肃锁定 14 个市州、86 个县级行政区；嘉峪关因不设县级行政区，以“嘉峪关市 → 嘉峪关市”支持直管地址选择但不计入 86 个县级区划，兰州新区等开发区不作为县区加入。城市和区县支持搜索，切换上级会清空不匹配的下级；历史外省地址保留可见并标记“当前地区暂未开放”，重新选择前不能保存；服务端地址协议和数据库未改。`flutter analyze` 无问题，Flutter 全量 237 项通过且 3 项按既有条件跳过；业主端 APK 为 `zhidi_app/output/apks/zhidi-owner-debug-20260802-region-picker.apk`，已覆盖安装到 `emulator-5554`，并实测“四川省 → 成都市 → 武侯区”和“甘肃省 → 兰州市 → 城关区”无红屏、无布局溢出或 Flutter 异常。证据为 `output/evidence/owner-address-province-picker-20260802.png`、`owner-address-sichuan-selected-20260802.png`、`owner-address-gansu-selected-20260802.png`。
- 2026-08-04 已校正验收角色边界：只有当前订单师傅能发起或重新发起验收，业主端施工中主操作由“申请验收”改为只读的“验收进度”；师傅未发起时业主显示“师傅尚未发起验收”，只有 `INSPECTING` 状态允许业主去验收，驳回后等待师傅整改重新发起。后端全量 226 项测试通过（含 `InspectionIntegrationTest` 11 项角色回归），Flutter 全量 245 项通过且 3 项按既有条件跳过，`flutter analyze` 无问题。业主端公网调试 APK 为 `zhidi_app/output/apks/zhidi-owner-debug-20260804-inspection-role.apk`（SHA-256 `10a61382577d6aabc3f17c04bef1a87b73482c5117f5156656d5862d767bae73`），已安装冷启动到 `Zhidi_API35`，实机界面证据为 `output/evidence/owner-inspection-role-my-home-20260804.png` 与 `owner-inspection-role-status-20260804.png`，未发现 Flutter 异常或布局溢出。本次未改生产后端逻辑，不需要重新部署 ECS。
- 核心闭环的本地持久化只作为当前登录账号缓存，服务端仍是需求、预约、报价、验收、付款和聊天的事实源；退出、会话过期和切换账号会清除用户域缓存。
- 生产可达的核心找师傅、预约、订单、报价和聊天入口不再回退到旧本地 Mock/Firestore 假成功；尚未接通的非核心能力显示“暂未开放”或明确说明数据来源。
- Flutter 单元/Widget 测试覆盖认证、会话隔离、资料、候选、预约、报价、验收、付款、消息深链和重点页面；2026-08-09 合并前全量为 508 项通过、2 项按既有条件跳过。

### Spring Boot 后端

- 基础框架：Java 21、Spring Boot 3.5、Maven、Spring MVC、Spring Data JPA、Spring Security、Flyway、MySQL、OpenAPI、Actuator。
- 已有统一 API 响应、trace ID、全局异常处理和基础审计表。
- 2026-07-22 已修复生产环境不存在路径被全局兜底错误包装为 500、未知异常不记录堆栈的问题：`/` 和随机不存在路径现在统一返回 404 `NOT_FOUND`，真正的未知异常会记录 traceId 和完整堆栈。ECS 已清除手工 `nohup` 与 systemd 双实例冲突，修正 `/opt/zhidi/.env` 的正式凭据并收紧为 `600`，当前仅由 `zhidi.service` 托管；公网健康、Swagger、数据库查询、鉴权和 404 已复验。
- 已完成用户、角色和短信验证码数据模型及 Flyway 迁移。
- 已完成业主/工匠验证码请求、注册、统一登录和 30 天 JWT 签发。
- 已完成 JWT 入站认证：受保护 API 回查数据库用户状态与角色，并统一返回 JSON 401/403 错误。
- 已实现验证码哈希保存、5 分钟有效期、错误次数限制，以及手机号/IP 发送频率限制。
- 已有服务、控制器、JWT、仓库和 MySQL Testcontainers 测试。
- 业主资料 MySQL 持久化、`GET /api/v1/owners/me`、`PUT /api/v1/owners/me` 已扩展头像与性别；服务器地址簿 `GET/POST/PUT/DELETE /api/v1/owners/me/addresses` 和设置默认地址接口已完成并部署，Flyway 当前为 V23。
- 工匠资料 MySQL 持久化、`GET /api/v1/workers/me`、`PUT /api/v1/workers/me` 已同步到主工作区，并通过对应后端测试。
- 工匠公开列表和详情 `GET /api/v1/workers`、`GET /api/v1/workers/{userId}` 已同步到主工作区，仅展示资料完整工匠。
- 预约最小后端闭环已同步到主工作区：业主可为资料完整工匠创建预约，业主/工匠可分别查看自己的预约，工匠可接单或拒单；已通过后端全量测试。
- 2026-08-08 已修复服务需求与候选生命周期串单：legacy `POST /api/v1/bookings` 每次创建独立服务需求，不再按业主、工种和城市复用旧需求；显式多人候选仍使用服务需求候选 API。只有 `OPEN/COMPARING` 需求可继续加候选，`REJECTED/CANCELLED/NOT_SELECTED/HIRED/COMPLETED` 统一不计入活跃候选，已分配或完成需求不会被新候选降回比较状态。相关能力已随 2026-08-09 P1 单工种交易闭环部署到 ECS。
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
POST /api/v1/auth/admin/login
GET /api/v1/owners/me
PUT /api/v1/owners/me
GET /api/v1/owners/me/addresses
POST /api/v1/owners/me/addresses
PUT /api/v1/owners/me/addresses/{addressId}
DELETE /api/v1/owners/me/addresses/{addressId}
PUT /api/v1/owners/me/addresses/{addressId}/default
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
POST /api/v1/chat/rooms/{roomId}/read
POST /api/v1/chat/rooms/{roomId}/messages
POST /api/v1/payment/orders
GET /api/v1/payment/orders/{orderId}
GET /api/v1/payment/orders
GET /api/v1/payment/offline-instructions
POST /api/v1/payment/orders/{orderId}/offline-split-report
POST /api/v1/payment/orders/{orderId}/construction-receipt-confirmation
POST /api/v1/payment/orders/{orderId}/wechat-intent
POST /api/v1/payment/callback
POST /api/v1/payment/orders/{orderId}/refund
GET /api/v1/worker-warranty/account
GET /api/v1/worker-warranty/contributions
GET /api/v1/worker-warranty/payment-instructions
POST /api/v1/worker-warranty/contributions/{contributionId}/report
POST /api/v1/worker-warranty/account/release-request
GET /api/v1/admin/payment-orders
POST /api/v1/admin/payment-orders/{orderId}/platform-fee-verification
GET /api/v1/admin/worker-warranty/contributions
POST /api/v1/admin/worker-warranty/contributions/{contributionId}/verification
POST /api/v1/admin/worker-warranty/accounts/{accountId}/release
GET /api/v1/settlements
POST /api/v1/after-sales
GET /api/v1/after-sales/{id}
GET /api/v1/after-sales
```

## 4. 当前未完成

### 后端关键缺口

- 真实短信供应商；开发环境目前返回模拟验证码。
- Refresh Token、登出撤销、会话/设备管理和账号注销。
- 业主资料、头像字段与地址簿已实现并部署；第三方实名认证仍未接入，当前只如实显示“手机号已验证”。正式实名认证通常需要企业主体、认证供应商合同与相应合规材料。
- 工匠认证审核、可接单状态和更完整的筛选/排序；当前已完成工匠短信注册/登录、当前登录工匠资料 GET/PUT、公开工匠列表和详情。
- 业主直接选师傅的需求、多候选、预约、接单/拒单、改约、双方到场、取消和最终选人主状态机已实现；仍缺可审计的完整状态历史、重复请求幂等键、异常并发压测和正式运营干预工具。平台派单不是当前产品模型。
- 报价单、人工/材料明细、拒绝重报、多人比价和业主最终确认已实现；仍缺报价 PDF/图片归档、电子签署以及更多断网、重复提交、并发多人报价的真机复验。
- 施工日报、当前工种节点验收、整改重提和验收完成归档已实现；仍需加强现场图片审核/归档、超大文件与弱网恢复、跨日施工阶段编排和完整异常真机复验。
- 聊天房间与消息表已有 REST/WS 基础链路，双端已增加真实状态轮询生成的前台应用内通知和精确深链；仍缺 APNs/FCM/国产厂商系统推送、离线事件补偿、客服协同和消息运营后台。工人端目前没有可发现的售后列表 API 与售后页面，因此不能生成真实工人售后通知。
- 通用文件上传已使用 ECS 本地持久目录，工人案例、日报和聊天图片可走真实上传；仍缺正式对象存储、CDN 和图片审核。
- 师傅收藏在服务端化前已明确标记不可用；评价、动态、举报和反馈仍未完成。业主售后有真实订单绑定入口，工人售后发现列表、双方追加证据/回复和完整状态时间线仍缺失。
- “全屋翻新”目前没有跨工种总项目、阶段依赖、总预算、工期和项目负责人编排；未接通的整屋服务入口已显示“暂未开放”，不能视为已形成闭环。
- 生产支付已切换为 `OFFLINE_SPLIT_V2` 线下拆分上报：工程款付工人、平台服务费付公司，工人独立履约质保账户按规则补缴；历史订单继续兼容旧质保口径。真实微信支付、退款、自动结算/对账仍未接入支付机构，未配置时明确失败，不会假成功。
- 已有受保护管理 API、管理员操作审计、分页/筛选校验和最小 `/admin.html` 可视化运营台；仍缺正式后台登录、角色管理、审计检索、筛选导出、指标看板和更完整的移动端适配。
- 生产仍为公网 HTTP 直连 IP；缺域名、HTTPS、Nginx/反代、正式短信、推送、监控告警和自动化备份。

### Flutter 集成缺口

- 当前产品交付与本地端到端验证目标仅为 Android；iOS 脚手架目录已删除，如未来恢复 iOS，需要重新生成平台工程并单独完成签名、权限和真机适配。
- 核心业主到工人闭环已改为真实 REST 路径：认证、资料、工人目录/详情/案例、服务请求多候选、预约、接单、上门时间、双方到场、报价比价、最终选人、日报、节点验收、聊天、线下付款上报和工人收款确认。非核心页面只能展示明确标注来源的参考数据或“暂未开放”，不得产生本地成功结果。
- 生产公网 API 的业主预约、工人查看真实业主信息、工人接单、业主回读状态已验证；Android Studio 模拟器已可视化验证工人端登录、真实预约卡片展示和 UI 点击“立即接单”闭环。当前证据包括 APK 构建、工人端模拟器截图、UI 点击后工人端待接单列表清空，以及业主 API 回读 `ACCEPTED`。
- 双端消息已覆盖预约、上门、到场、报价、选人、验收和付款等真实状态变化，使用稳定事件 ID、会话隔离和目标存在性校验；当前实现是前台每 8 秒 REST 轮询的应用内通知，不是系统推送，应用离线期间也没有完整事件补偿。
- 旧 Firestore 桥接和核心流程中的本地假成功路径已移除；仍需继续清点非核心页面的演示数据，避免用户误以为已上线。
- 通用上传、聊天 REST/WS 与项目主状态已有真实链路；本批 P0 改动仍需生成双端 APK、安装到两台真机/模拟器并用全新账号跑一遍完整公网闭环。系统推送、真实在线支付和应用商店级稳定性复验仍未完成。
- 业主端当前允许未登录浏览首页；首页以外底部 Tab 会触发登录，未登录时不显示受保护消息红点。

## 5. 当前优先方向

建议按依赖顺序推进：

1. 先按数据库备份、环境变量核对、JAR/APK 构建、灰度发布、健康检查和回滚方案部署当前本地 P0/V24 版本；随后用两个全新账号在双设备跑完“选师傅 → 接单 → 上门 → 到场 → 报价 → 选人 → 日报 → 验收 → 线下付款 → 工人确认 → 售后”公网闭环。
2. 申请域名并完成 Nginx/HTTPS、证书续期、安全组收口、监控告警和自动备份；停止正式用户通过公网 HTTP 直连 IP。
3. 接入真实短信、系统推送、对象存储/CDN和图片审核，并补齐离线事件源；这些能力需要供应商账号、密钥和相应企业材料。
4. 取得支付所需资质后接微信/支付宝正规支付、退款、分账或合规资金方案、对账和财务审计；当前只保留诚实的线下付款与人工核验流程。
5. 补齐工人售后发现/处理、评价举报、全屋翻新跨工种项目编排和正式运营后台。
6. 完成 Android 真机矩阵、弱网/断网/重复点击/中断恢复、隐私合规、签名加固、崩溃监控和应用商店发布准备。

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

最新合并与部署验证结果（2026-08-09 P0/P1 单工种交易闭环）：

| 项目 | 结果 |
|------|------|
| 后端全量测试 | 合并前 `./mvnw test`：383 tests, 0 failures, 0 errors, 0 skipped |
| Flutter analyze | `flutter analyze`：No issues found |
| Flutter 全量测试 | 合并前 `flutter test --reporter compact`：508 passed, 2 skipped，All other tests passed |
| 改动格式检查 | `git diff --check`：无输出 |
| 本批交付状态 | 已合并到 `main` 并部署 ECS；生产健康检查 `UP`，Flyway 到 V33；双端生产 API debug APK 已生成，尚未安装到真机/模拟器 |

ECS 发布备份位于 `/opt/zhidi/backups/20260718150120/`，包含旧 jar、`.env` 备份和迁移修复前数据库 dump。发布期间生产 V14/V15 迁移分别遇到 MySQL 非事务 DDL 半成品表和默认管理员账号已有手机号但 UUID 不同的问题；已修正 V15 并用回归测试覆盖，生产最终无失败迁移记录。

已复核改动清单，范围集中在 Android flavor 识别、生产配置、服务请求/预约/报价/日报/验收/支付边界、数据库迁移、对应测试和项目状态文档。

2026-07-19 修复业主端“我的预约”远程取消时的 Flutter `Dismissible` 红屏：取消请求现在会先等待服务器成功并从状态列表移除预约，再完成滑动动画；失败时保留预约并提示重试。新增本地删除及延迟远程取消两条组件回归测试。

2026-07-19 针对 Android 真机反馈补强工人上门时间与双端验证码流程：工人提交上门时间前会先刷新服务器预约并验证该预约仍属于当前账号且保持已接单状态，陈旧预约不再携带旧 `bookingId` 请求服务器；业主端和工人端验证码均绑定发送时手机号，修改手机号会清空旧验证码并允许重新获取，避免把已被服务器作废的旧验证码误报为偶发登录失败。

2026-07-19 补全业主端候选师傅决策入口：候选列表整卡可进入服务器真实工人详情并查看公开施工案例，详情页可直接添加候选；候选以服务器添加成功为准，最多三位且禁止重复，页面底部提供“完成选择（已选 X/3）”，从首页匹配入口完成后切换“我的家”并触发真实需求刷新。候选页、真实案例和首页回归测试共 22 项通过，Flutter 全量静态检查无问题；真机可视化复验仍需使用本次新 APK 完成。

2026-07-22 完成 V17 生产闭环部署与公网 API 复验：在 ECS `47.109.0.191` 使用 release JAR 跑通业主注册/登录、业主资料、工人注册/登录、工人资料、业主查看工人、创建服务需求、添加候选、工人待接单、接单、提出上门时间、业主确认、双方到场、固定目录报价、业主比价和选人、工人日报、业主查看日报、节点验收、聊天、业主线下付款上报、工人确认收款、工人端结算 `SETTLED`。发布前备份位于 `/opt/zhidi/backups/20260722230245-pre-v17-deploy/`。
