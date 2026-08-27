# API 端点清单（自动生成）

> ⚙️ 本文件由 `scripts/sync-docs.mjs` 从 `server/src/**/*.controller.ts` 自动生成，**请勿手改**；
> 每次 master 推送后由 `.github/workflows/docs-sync.yml` 自动更新（人工改动会被覆盖）。
> 完整契约见 [技术方案](./AA分账App-技术方案.md)；Swagger：`GET /api/docs`。

共 44 个端点。表格：HTTP 方法 | 路径（`api/v1` 为全局前缀）| 鉴权 | 说明。

| 方法 | 路径 | 鉴权 | 说明 |
|---|---|---|---|
| DELETE | `api/v1/auth/devices/:deviceId` | 🔒 登录 | 退出某台设备（移除记录；不存在也视为成功） |
| DELETE | `api/v1/auth/me` | 🔒 登录 | 注销账号（商店合规：应用内删除账号）。 |
| DELETE | `api/v1/bills/:id` | 🔒 登录 |  |
| DELETE | `api/v1/groups/:id/members/:userId` | 🔒 登录 |  |
| DELETE | `api/v1/groups/:id` | 🔒 登录 |  |
| DELETE | `api/v1/notifications/:id` | 🔒 登录 | 删除单条消息（消息中心左滑 / 长按删除） |
| DELETE | `api/v1/regular-bills/:id` | 🔒 登录 |  |
| GET    | `api/v1/auth/devices` | 🔒 登录 | 登录设备列表（最近登录在前） |
| GET    | `api/v1/auth/me` | 🔒 登录 |  |
| GET    | `api/v1/auth/security-question` | 公开 | P04：忘记密码第一步 — 查询账户的安全问题（问题非机密） |
| GET    | `api/v1/bills/:id` | 🔒 登录 |  |
| GET    | `api/v1/groups/:id/invite` | 🔒 登录 |  |
| GET    | `api/v1/groups/:id/settlement` | 🔒 登录 | 计算最少转账结算方案（并落库为最新 pending 记录） |
| GET    | `api/v1/groups/:id` | 🔒 登录 |  |
| GET    | `api/v1/notifications/stream` | 公开 | SSE 实时通知流（支持 ?access_token= 与 Authorization header） |
| GET    | `api/v1/notifications/unread-count` | 🔒 登录 |  |
| GET    | `api/v1/regular-bills/:id` | 🔒 登录 |  |
| GET    | `api/v1/users/:id` | 🔒 登录 | 公开资料 |
| GET    | `api/v1/users/search` | 🔒 登录 | 搜索账户名（用于添加群成员） |
| PATCH  | `api/v1/auth/me` | 🔒 登录 | P50：编辑个人资料（昵称 / 头像 / 个性签名） |
| PATCH  | `api/v1/bills/:id` | 🔒 登录 |  |
| PATCH  | `api/v1/groups/:id` | 🔒 登录 |  |
| PATCH  | `api/v1/regular-bills/:id` | 🔒 登录 |  |
| POST   | `api/v1/auth/avatar` | 🔒 登录 | P50：上传头像图片（multipart file）→ 返回服务端可访问 URL（/uploads/...）。 |
| POST   | `api/v1/auth/change-password` | 🔒 登录 |  |
| POST   | `api/v1/auth/change-security-question` | 🔒 登录 | P52：修改安全问题（需当前密码验证） |
| POST   | `api/v1/auth/devices` | 🔒 登录 | 上报当前设备（幂等 upsert；打开「账号安全」页时调用，保证本机在列） |
| POST   | `api/v1/auth/forgot/reset` | 公开 |  |
| POST   | `api/v1/auth/forgot/verify` | 公开 |  |
| POST   | `api/v1/auth/login` | 公开 |  |
| POST   | `api/v1/auth/register` | 公开 |  |
| POST   | `api/v1/bills/:id/mark-paid` | 🔒 登录 |  |
| POST   | `api/v1/bills/:id/receipts/:receiptId/ocr/retry` | 🔒 登录 | 重试识别（P33 凭证；权限：创建者/垫付人/群主） |
| POST   | `api/v1/bills/:id/receipts/:receiptId/replace` | 🔒 登录 |  |
| POST   | `api/v1/bills/:id/receipts` | 🔒 登录 |  |
| POST   | `api/v1/bills/:id/remind` | 🔒 登录 |  |
| POST   | `api/v1/bills/settle-all` | 🔒 登录 | 一键结清：群内全部未结清账单统一标记已付 |
| POST   | `api/v1/groups/:id/members` | 🔒 登录 |  |
| POST   | `api/v1/groups/:id/transfer` | 🔒 登录 |  |
| POST   | `api/v1/groups/join` | 🔒 登录 |  |
| POST   | `api/v1/notifications/:id/read` | 🔒 登录 |  |
| POST   | `api/v1/notifications/read-all` | 🔒 登录 |  |
| POST   | `api/v1/receipts/pre-upload` | 🔒 登录 | 草稿预上传：记账页拍/选后立刻上传暂存并识别（返回 uploadId，账单创建时绑定，24h 未绑定回收） |
| POST   | `api/v1/settlements/:id/paid` | 🔒 登录 | 标记某笔结算记录已收款 |
