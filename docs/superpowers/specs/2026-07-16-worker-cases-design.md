# 工人施工案例真实跨端闭环设计

## 目标

工人可在工人端维护施工案例并从 Android 相册上传真实图片；案例和图片保存到 ECS。业主从工人列表进入真实工人详情后，看到该工人服务器案例，不再看到 Picsum 假案例。

## 架构

- MySQL `worker_cases` 保存案例标题、说明、服务城市、完工年份和图片 URL 列表。
- 图片文件保存到 ECS `/opt/zhidi/uploads/cases`，数据库不保存图片二进制。
- 后端公开 `/uploads/**` 静态读取；文件名由服务端 UUID 生成，禁止客户端提供路径。
- 工人案例写接口要求 WORKER JWT，并以 JWT 的 `userId` 绑定所有权。
- `GET /api/v1/workers/{workerUserId}/cases` 为公开只读接口，供业主详情页使用。

## API

- `POST /api/v1/workers/me/case-images`：上传单张 JPG、PNG 或 WebP，最大 10MB，返回绝对 `url`。
- `GET /api/v1/workers/me/cases`：当前工人查看自己的案例。
- `POST /api/v1/workers/me/cases`：创建案例。
- `PUT /api/v1/workers/me/cases/{caseId}`：编辑自己的案例。
- `DELETE /api/v1/workers/me/cases/{caseId}`：删除自己的案例记录。
- `GET /api/v1/workers/{workerUserId}/cases`：业主/游客查看公开案例。

案例必填标题、说明、城市、完工年份和 1–6 个本站图片 URL；完工年份范围为 2000 到当前年份。删除案例只删除记录，本阶段不自动删除可能仍被引用的图片文件。

## Flutter

- 新增独立 `WorkerCaseApiClient`，封装案例 CRUD、公开查询和 multipart 图片上传。
- 工人“个人资料”页增加“施工案例”管理入口；案例编辑页支持从相册多选、上传、填写信息、保存和删除。
- 业主真实工人详情页按 `remoteProfile.userId` 拉取案例，展示标题、说明、城市、年份和图片；加载失败显示重试，不回退假图。
- 本地 Mock 工人仍可保留原展示，不影响未接后端的演示入口。

## 错误与安全

- 空文件、非图片、超限文件、越权编辑、非法图片 URL 返回统一业务错误。
- 上传或保存失败保留表单内容并显示中文提示。
- 公开接口只返回案例展示字段，不返回工人手机号或服务器文件路径。
- 静态图片文件名不可预测，且不接受目录穿越输入。

## 验证

- 后端纯单元测试覆盖所有权、校验和公开查询；迁移与 JPA 通过打包校验。
- Flutter client 测试覆盖 JSON、multipart 和错误响应。
- Widget 测试覆盖工人案例入口/保存，以及业主远程案例展示且不出现 Picsum URL。
- 发布后用生产工人 Token 创建测试案例，业主端公开 API 回读，并在双模拟器截图留证。
