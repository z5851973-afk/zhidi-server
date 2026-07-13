# 知底 Spring Boot 后端设计

## 目标与范围

在现有知底 Flutter 项目旁新增独立 Spring Boot 服务端，为业主端和工匠端提供统一的 REST API，并可通过 Docker Compose 部署到 Ubuntu 22.04。

一期交付覆盖：

- 业主和工人手机号验证码登录。
- JWT 访问令牌、刷新令牌和角色权限控制。
- 业主资料、工人资料及工人认证审核。
- 已认证工人列表和详情。
- 预约、接单、拒单、报价及报价确认。
- 施工项目、工序进度、施工日志、节点验收和整改。
- 微信支付与支付宝的统一支付接口、分阶段付款、退款和对账记录。
- 开发环境本地文件存储、生产环境阿里云 OSS。
- MySQL 数据库迁移、OpenAPI 文档、测试和 Ubuntu 部署资料。

一期不包含实时聊天、Web 管理界面、银行卡分账和资金托管。管理员审核等后台能力以 REST API 交付。款项由公司的微信支付商户号或支付宝企业商户直接收取到绑定的公司结算账户。

## 总体架构

采用模块化单体 Spring Boot。所有业务模块在一个部署单元内运行、共用一个 MySQL 数据库，通过清晰的领域边界隔离。当前规模下该方案便于开发、事务处理、部署和排错；业务增长后可以按模块拆分服务。

```text
Flutter 业主端 / 工匠端
          |
       HTTPS REST
          |
        Nginx
          |
Spring Boot 模块化单体
  |-- 认证与权限
  |-- 业主账户
  |-- 工人资料与审核
  |-- 预约与接单
  |-- 报价管理
  |-- 施工日志与验收
  |-- 分阶段支付
  `-- 文件存储适配
          |
  MySQL 8 + 本地文件/阿里云 OSS
```

建议技术基线：Java 21、Spring Boot 3、Maven、Spring Security、Spring Data JPA、Flyway、MySQL 8、JWT、springdoc OpenAPI、JUnit 5、Testcontainers、Docker Compose 和 Nginx。实际依赖版本在实施时选用相互兼容且仍受支持的稳定版本，并锁定在构建文件中。

后端目录使用 `zhidi_server/`，与 `zhidi_app/` 平级。后端不直接依赖 Flutter 代码；双方通过版本化 API DTO 和 OpenAPI 契约对接。

## 领域模块

### 认证与账户

手机号是账户主标识。同一个账户可以拥有 `OWNER`、`WORKER` 或 `ADMIN` 角色，角色身份资料分别保存。业主首次成功登录后自动创建业主身份；工人首次登录后创建待完善资料的工人身份。

工人准入状态为：

```text
PROFILE_INCOMPLETE -> PENDING_REVIEW -> APPROVED
                                  `-> REJECTED -> PENDING_REVIEW
```

只有 `APPROVED` 且开启接单状态的工人可以出现在业主端师傅列表并接单。审核记录保存审核人、时间、结果和原因。

### 预约、报价与项目

业主从师傅详情或工种入口创建预约。定向预约只能由目标工人处理；非定向预约可由管理员匹配工人。接单动作使用事务和乐观锁，避免重复接单。

预约主状态为：

```text
PENDING -> ACCEPTED -> QUOTING -> QUOTE_PENDING_CONFIRMATION
        -> REJECTED                   |-> QUOTE_REJECTED -> QUOTING
                                     `-> READY_TO_START -> IN_PROGRESS
                                                           |-> INSPECTION
                                                           `-> COMPLETED
```

取消属于终止状态，取消人、原因和时间单独记录。非法状态跳转返回明确业务错误，不直接覆盖现有状态。

报价由主表和明细组成。明细类型为人工或辅材，所有金额使用人民币“分”的整数保存。工人提交报价后不可原地修改；业主驳回后创建新版本，历史版本永久保留。

报价确认后创建施工项目，并按工种或整屋模板生成施工阶段。阶段顺序支持拆除、水电、防水、泥瓦、木工、油漆、安装，也允许管理员配置其他工序。

### 施工日志与验收

施工日志分为：

- 进场记录。
- 每日施工记录。
- 节点验收记录。

日志包含施工日期、工序、文字说明、施工工艺、验收标准和照片。照片通过文件服务上传，日志只引用文件对象 ID。

施工阶段状态为：

```text
NOT_STARTED -> IN_PROGRESS -> PENDING_INSPECTION
                                |-> APPROVED -> COMPLETED
                                `-> RECTIFICATION -> PENDING_INSPECTION
```

工人提交验收，业主可以通过或驳回。驳回必须填写原因，整改和再次提交均保留历史记录。

## 数据模型

核心表及职责如下：

- `users`：手机号、账户状态和审计时间。
- `user_roles`：账户角色。
- `sms_codes`：验证码摘要、用途、过期时间和尝试次数。
- `refresh_tokens`：刷新令牌摘要、设备 ID、到期和撤销信息。
- `owner_profiles`：业主资料。
- `worker_profiles`：工人全名、工种、经验、认证状态和接单状态。
- `worker_review_records`：工人审核历史。
- `appointments`：预约对象、地址、面积、上门时间和当前状态。
- `appointment_status_history`：预约状态变更历史。
- `quotes`：报价版本、人工总价、辅材总价和状态。
- `quote_items`：人工或辅材报价明细。
- `projects`：施工项目和总状态。
- `project_stages`：项目工序、顺序和阶段状态。
- `construction_logs`：进场、每日施工和节点日志。
- `construction_log_files`：日志图片关联和排序。
- `inspections`：验收申请、决定、意见和时间。
- `file_objects`：存储驱动、对象键、媒体类型、大小和上传者。
- `payment_plans`：项目付款计划、总额和状态。
- `payment_stages`：付款节点、金额、顺序和支付状态。
- `payment_orders`：渠道、平台交易号、商户订单号、金额和状态。
- `payment_callbacks`：支付通知原文摘要、验签和处理结果。
- `refund_orders`：退款金额、原因、平台退款号和状态。
- `reconciliation_records`：渠道账单日期、对账状态和差异。
- `operation_logs`：登录、审核和关键业务操作审计。

手机号、身份证件信息及完整地址属于敏感字段。日志禁止记录验证码、令牌、支付密钥、完整手机号和支付回调密文。工人接单前只获得脱敏地址，接单后仅获得履约必要的信息。

## REST API

统一前缀为 `/api/v1`，JSON 字段使用 `camelCase`。所有列表接口使用游标或页码分页。响应包含 `code`、`message`、`data` 和 `traceId`；HTTP 状态码表达协议结果，业务码表达具体原因。

### 认证和资料

```text
POST /api/v1/auth/sms/send
POST /api/v1/auth/sms/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
GET  /api/v1/me
PUT  /api/v1/owners/me
PUT  /api/v1/workers/me/profile
PUT  /api/v1/workers/me/availability
```

短信发送请求包含手机号、登录端和用途。登录端只能是 `OWNER_APP` 或 `WORKER_APP`，服务端据此创建或校验对应角色，防止客户端任意申请管理员角色。

### 工人和审核

```text
GET  /api/v1/workers
GET  /api/v1/workers/{workerId}
GET  /api/v1/admin/workers/pending
POST /api/v1/admin/workers/{workerId}/approve
POST /api/v1/admin/workers/{workerId}/reject
```

公开列表仅返回已认证且可接单的工人。列表和详情统一使用工人真实展示全名，避免“我的服务”和师傅详情姓名不一致。

### 预约和报价

```text
POST /api/v1/appointments
GET  /api/v1/appointments
GET  /api/v1/appointments/{appointmentId}
POST /api/v1/appointments/{appointmentId}/accept
POST /api/v1/appointments/{appointmentId}/reject
POST /api/v1/appointments/{appointmentId}/quotes
GET  /api/v1/appointments/{appointmentId}/quotes
POST /api/v1/quotes/{quoteId}/confirm
POST /api/v1/quotes/{quoteId}/reject
```

业主只能查看自己的预约，工人只能查看派给自己的预约。报价总额由服务端根据明细重新计算，客户端提交的汇总值不作为可信数据。

### 项目、日志和验收

```text
GET  /api/v1/projects
GET  /api/v1/projects/{projectId}
POST /api/v1/projects/{projectId}/logs
POST /api/v1/projects/{projectId}/stages/{stageId}/start
POST /api/v1/projects/{projectId}/stages/{stageId}/inspections
POST /api/v1/inspections/{inspectionId}/approve
POST /api/v1/inspections/{inspectionId}/reject
POST /api/v1/files
GET  /api/v1/files/{fileId}
```

项目详情一次返回师傅摘要、人工和辅材报价、阶段进度、施工日志摘要及付款节点，供“我的家”页面统一展示。一个业主可以同时存在多个工种项目，接口不按工种去重。

### 分阶段支付

```text
GET  /api/v1/projects/{projectId}/payment-plan
POST /api/v1/payment-stages/{stageId}/pay
GET  /api/v1/payment-orders/{paymentOrderId}
POST /api/v1/payment-orders/{paymentOrderId}/close
POST /api/v1/admin/payment-orders/{paymentOrderId}/refund
POST /api/v1/payments/wechat/notify
POST /api/v1/payments/alipay/notify
GET  /api/v1/admin/reconciliation
```

`pay` 请求指定 `WECHAT` 或 `ALIPAY`，后端创建支付单并返回 Flutter 调起对应 App 支付所需参数。客户端支付结果只用于界面提示，不能直接更新支付状态。最终状态以服务端验签通过的异步通知和主动查单结果为准。

回调处理必须：

1. 验证平台签名和证书。
2. 校验应用、商户、订单号、币种和金额。
3. 以商户订单号建立唯一约束，幂等处理重复通知。
4. 在同一事务中更新支付单、付款节点和业务事件。
5. 保存可审计但不泄露密钥和敏感明文的处理记录。

支付计划按报价总额拆为多个节点，节点金额合计必须严格等于已确认报价总额。默认支持开工、水电验收、泥瓦验收和竣工等节点，具体比例由项目付款计划决定。进入下一节点是否要求已付款由付款计划规则控制。

## 认证与安全

Access Token 默认有效期 30 分钟，Refresh Token 默认有效期 30 天。刷新时轮换 Refresh Token，旧令牌立即撤销；服务端只保存令牌摘要。登出、密码学密钥轮换或账号禁用可以撤销会话。

JWT 至少包含用户 ID、角色、会话 ID、签发时间和到期时间，不包含手机号、地址等敏感资料。权限检查同时验证角色和资源归属，不能只依赖前端隐藏入口。

验证码策略：

- 开发环境使用配置的固定验证码，不调用短信服务。
- 生产环境使用阿里云短信适配器。
- 验证码短时有效、一次使用，数据库保存摘要。
- 按手机号、IP 和设备限制发送与验证频率。
- 连续失败达到阈值后临时锁定，并写安全审计日志。

CORS 只允许配置的来源。管理接口要求 `ADMIN` 角色。生产环境只接受 HTTPS，密钥通过环境变量或 Docker Secret 注入，不进入镜像、Git 或日志。

## 文件存储

文件服务定义统一接口，提供本地磁盘和阿里云 OSS 两个实现。开发环境使用 Docker 数据卷；生产环境使用私有 OSS Bucket。数据库保存对象键而非永久公开 URL。

上传限制包括允许的图片媒体类型、单文件大小、每条日志照片数量和上传者权限。下载时校验项目参与者或管理员权限；需要访问 OSS 时返回短期签名 URL。删除业务记录采用逻辑删除和延迟清理，避免误删仍被引用的施工证据。

## 支付合规边界

微信和支付宝均使用公司主体申请并开通的正式商户产品，平台支付款进入该商户绑定的公司结算账户。服务端不保存用户银行卡信息，不自行模拟资金托管或建立平台资金池。

公司后续向工人付款不属于一期 App 支付接口，应通过公司确认的合同、发票、税务和财务流程执行。上线前由公司财税及法律人员确认业务合同、退款规则、阶段款确认条件和向工人结算方式。若未来需要平台分账或担保交易，必须使用支付机构提供并由公司获准开通的对应产品，不能仅通过数据库记账替代。

## 错误处理与一致性

参数错误、未认证、无权限、资源不存在、状态冲突和限流分别映射稳定的 HTTP 状态与业务码。异常响应不返回堆栈、SQL 或第三方密钥信息。

接单、报价确认、验收和支付回调使用数据库事务。预约、报价、项目阶段和付款节点使用版本字段进行乐观锁控制。创建预约和创建支付单支持幂等键，网络重试不会生成重复记录。

第三方短信、OSS 和支付渠道故障采用明确的超时与有限重试。支付回调处理失败时保留待重试记录；重复处理仍遵守唯一约束和状态机。

## 部署与运维

Ubuntu 22.04 使用 Docker Compose 部署：

- `nginx`：TLS 终止、反向代理、上传大小限制和基础限流。
- `api`：Spring Boot 应用，暴露内部 HTTP 端口。
- `mysql`：MySQL 8，仅加入内部 Docker 网络，不向公网开放。
- 持久卷：MySQL 数据、本地文件和必要日志。

构建同时产出可独立运行的 JAR 和应用镜像。配置文件提供开发、测试和生产环境模板。容器包含健康检查，应用提供存活和就绪端点。Flyway 在部署时执行向前兼容的数据库迁移。

部署文档包含首次安装、配置 TLS、启动、升级、健康检查、日志查看、数据库备份、恢复演练和版本回滚。MySQL 每日备份到服务器受限目录，并建议同步到独立存储；备份保留周期可配置。

## 测试与验收

单元和集成测试至少覆盖：

- 固定验证码与短信适配器切换。
- 业主/工人登录、令牌刷新、轮换、登出和账号禁用。
- 角色越权、资源越权、短信限流和验证码重放。
- 工人资料提交、审核、驳回、重新提交及公开可见性。
- 定向预约只能由目标工人接单，重复接单产生状态冲突。
- 人工与辅材报价汇总、版本保留、确认和驳回。
- 一个业主多个同工种或不同工种项目均能正确返回，不错误去重。
- 进场、每日施工、节点验收、驳回整改和再次验收。
- 本地文件上传权限、类型、大小和项目访问权限。
- 微信和支付宝支付单创建的渠道适配契约。
- 回调验签失败、金额不一致、重复回调、退款和对账差异。
- Docker Compose 配置解析、应用健康检查和 MySQL 迁移。

使用 Testcontainers 启动真实 MySQL 进行仓储和 REST 集成测试。外部短信、OSS 和支付 SDK 使用适配器契约测试；生产支付沙箱或官方测试环境作为部署前人工验收步骤。

一期验收闭环为：业主登录并浏览已认证工人，创建预约；工人登录并接单，提交人工和辅材报价；业主确认报价并形成分阶段付款计划，通过微信或支付宝创建支付；工人上传施工日志并发起节点验收；业主验收或要求整改；付款与项目进度在两个 App 中读取同一份服务端数据。

## Flutter 对接边界

本设计先新增后端，不在同一实施步骤中大规模重写 Flutter 状态管理。后端稳定后，通过独立客户端对接计划逐步将以下临时来源替换为 REST API：

- 本地模拟登录。
- Firebase `shared_workers`。
- Firebase `shared_orders`。
- 本地 `shared_orders.json`。
- 内存或 SharedPreferences 中的预约、报价和施工记录。

迁移期间后端 DTO 以当前 Flutter 展示所需字段为基础，但服务端 ID、状态码和金额类型作为唯一权威来源。客户端不得用师傅姓名或工种名称作为关联键，必须使用服务端 ID。
