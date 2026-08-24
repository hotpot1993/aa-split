# AA分账App 服务端

基于 **NestJS 10 + TypeScript + Prisma + PostgreSQL** 的 AA 分账 App 后端。

- 全局前缀：`/api/v1`
- 统一响应：`{ code: 0, message: "ok", data }`；错误：`{ code: 非0, message }`
- 金额一律为 **整数分**（`amountCents` / `shareAmountCents`），不使用浮点
- 鉴权：`Authorization: Bearer <JWT>`（access 30 天 / refresh 7 天，refresh 通过返回体下发）

---

## 1. 技术栈

| 维度 | 选型 |
|---|---|
| 框架 | NestJS 10（TypeScript, `strict: true`） |
| ORM / 数据库 | Prisma + PostgreSQL 16 |
| 鉴权 | JWT（`@nestjs/jwt`）+ bcryptjs（cost 12） |
| 限流 | `@nestjs/throttler`（全局 100 次/分钟；`/auth/login` 单独 5 次/10 分钟） |
| 定期账单 | BullMQ + Redis（`@nestjs/bullmq`） |
| 文件 | MinIO（S3 兼容）或本地磁盘（`OBJECT_STORAGE=local`） |
| 实时 | SSE（手写内存 Map 订阅器，无 event-emitter / WebSocket） |
| 文档 | Swagger（`/api/docs`） |
| 测试 | jest + ts-jest + `@nestjs/testing`（PrismaService 一律 `jest.mock`） |

> 说明：**未引入 eslint、未引入 `@nestjs/event-emitter`**，符合任务约定。

---

## 2. 本地运行

### 2.1 安装与生成 Prisma Client

```bash
cd server
npm install                                  # 首次较慢，耐心等待
npx prisma generate                          # 生成 Prisma Client
```

### 2.2 配置环境变量

```bash
# 复制示例 .env 并修改
cp .env.example .env
```

关键项（详见 `.env.example`）：

- `DATABASE_URL`：PostgreSQL 连接串
- `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET`：务必改成随机长字符串
- `REDIS_HOST` / `REDIS_PORT`（可选，见降级说明）
- `OBJECT_STORAGE=local|minio`（默认 `local`，无 MinIO 也能跑）
- `PORT`（默认 3000）、`CORS_ORIGINS`、`SWAGGER_ENABLED`

### 2.3 数据库（两种方式）

**方式 A：有本地/远程 PostgreSQL**（推荐，需要 `npx prisma db push`）

```bash
# 建表（仅首次）；也可用 docker compose 起一个 Postgres
npx prisma db push
```

**方式 B：用 Docker Compose 起 Postgres**（本机装有 Docker）

```bash
docker compose up -d postgres
npx prisma db push
```

> 注：仓库未附带 `docker-compose.yml`，可用任意 PostgreSQL 16 实例；若本机无 Docker 也无数据库，可先只跑构建/测试（见 §5）。

### 2.4 启动

```bash
npm run dev            # 开发模式（watch）
# 或
npm run build && npm run start:prod
```

启动后：

- 健康检查：`GET http://localhost:3000/api/v1/health` → `{ "code":0, "message":"ok", "data":{"status":"ok"} }`
- Swagger：`http://localhost:3000/api/docs`

### 2.5 造演示数据（可选）

```bash
npx prisma db seed
```

会创建一个演示群「饭友群」+ 3 名成员 + 一笔三方均摊账单。

---

## 3. 无 Docker / 无 Redis / 无 MinIO 的降级说明

| 依赖 | 缺失时的影响 | 如何降级/规避 |
|---|---|---|
| **PostgreSQL** | 应用无法真正读写数据 | 必须连到一个 Postgres 16；无本地实例时可临时用云/容器实例。**纯构建与测试（`npm run build` / `npm test`）不依赖数据库**。 |
| **Redis / BullMQ** | 定期账单的定时扫描不生效 | 完全不影响主流程。`RegularBillsProcessor` 在注册重复任务时用 `try-catch` **惰性降级**：Redis 连不上时仅打印 warning，进程不会崩溃；账单/群组/结算等功能照常。 |
| **MinIO / 对象存储** | 凭证图片上传 | 将 `.env` 中 `OBJECT_STORAGE=local`（默认），文件写本地 `UPLOAD_DIR`（默认 `./uploads`），通过 `/uploads/*` URL 访问。 |

> 结论：**只跑构建与单测时，无需 Docker、无需 Redis、无需 MinIO、无需真实数据库。**

---

## 4. 测试命令

```bash
cd server
npm run build     # tsc 编译，无错
npm test          # jest 全绿
```

测试覆盖：

- `src/settlement/settlement.algorithm.spec.ts`（**必须全通过**）
- `src/settlement/settlement.service.spec.ts`（结算汇总 + 落库 + markPaid，mock PrismaService）
- `src/auth/auth.service.spec.ts`（注册/登录/找回，mock PrismaService）
- `src/bills/bills.util.spec.ts`（分摊校验：均摊/自定义/免摊/合计不相等）

> 测试中 `PrismaService` 一律通过 `jest.mock` / `useValue` 注入，**不连接真实数据库**。

---

## 5. API 一览

> 除标注 `@Public` 外，均需 `Authorization: Bearer <JWT>`。分页统一 `?page=1&pageSize=20`（默认 20，上限 100），返回 `{ list, total, page, pageSize }`。

### 认证 auth（`/auth`）
| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/auth/register` | `{accountName,password,nickname?,securityQuestion,securityAnswer}`；答案 bcrypt 存 `security_answer_hash` |
| POST | `/auth/login` | `{accountName,password}` → `{accessToken,refreshToken,user}`；单独限流 5 次/10 分钟 |
| POST | `/auth/forgot/verify` | `{accountName,securityAnswer}` → `{resetToken}`（10 分钟有效，DB 存 hash+过期） |
| POST | `/auth/forgot/reset` | `{resetToken,newPassword}` |
| POST | `/auth/change-password` | 需当前密码 + JWT |
| GET  | `/auth/me` | 我的资料 |

### 用户 users（`/users`）
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/users/search?accountName=` | 模糊搜账户名（用于加群成员，排除自己，最多 20 条） |
| GET | `/users/:id` | 公开资料 |

### 群组 groups（`/groups`）
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/groups` | 我加入的所有群 |
| POST | `/groups` | 创建（创建者自动为 owner+成员） |
| GET/PATCH/DELETE | `/groups/:id` | 详情(含成员)/修改(仅 owner)/解散(软删除) |
| POST | `/groups/:id/members` | `{accountName}` 查找并加为 active 成员 |
| DELETE | `/groups/:id/members/:userId` | owner 或本人退群（status=left） |
| POST | `/groups/:id/transfer` | `{newOwnerId}` 转让（仅 owner） |
| POST | `/groups/join` | `{inviteCode}` 加入；未知/已退群恢复 active |
| GET | `/groups/:id/invite` | `{inviteCode, joinedCount, members}` |

### 账单 bills（`/bills`、`/groups/:id/bills`）
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/groups/:id/bills` | 群账单流水（分页，bill_date desc + created_at desc，只返回未删除，含 creator/payer/participants） |
| POST | `/bills` | 创建；服务端校验 sum(share)=amount，成员校验，even 自动均摊（余数给第一位），自定义必填且免摊者=0 |
| GET/PATCH/DELETE | `/bills/:id` | 详情/编辑(仅创建者或群主)/删除(软删除) |
| POST | `/bills/:id/receipts` | 上传凭证（multipart 字段 `file`） |
| POST | `/bills/:id/mark-paid` | `{userId,paid}`；事务更新 + 重算 settle_status + 写通知 |
| POST | `/bills/:id/remind` | `{userIds[],message?}`；写通知 + 触发 SSE |

### 结算 settlement
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/groups/:id/settlement` | 计算最少转账方案（`summarizeBalances` + `computeSettlement`），返回 `{ transferCount, transfers:[{fromUserId,toUserId,amountCents,billIds}], settlementIds }` |
| POST | `/settlements/:id/paid` | 置某笔结算记录 `status=paid`（仅群成员） |

> **关于 `billIds`：** 方案中的转账是**净值合并**后的结果，无法精确还原到某一张账单，因此 `billIds` 采用 **近似归属**：把每笔转账金额按 from 用户在该群未结清账单中的应摊（从大到小）贪心匹配到账单 id。业务上仅作「这笔钱大概由哪些账单元组成」的参考。

### 通知 notifications（`/notifications`）
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/notifications?type=&isRead=` | 分页，按时间倒序 |
| GET | `/notifications/unread-count` | 未读数 |
| POST | `/notifications/read-all` | 全部已读 |
| POST | `/notifications/:id/read` | 单条已读 |
| GET | `/notifications/stream` | SSE，`text/event-stream`；支持 `?access_token=` 与 Authorization header；心跳注释保持连接 |

### 定期账单 regular-bills（`/regular-bills`）
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/regular-bills` | 我所在群的定期账单 |
| POST | `/regular-bills` | `{groupId,title,amountCents,category,splitType,cycle,dayOfWeek?\|dayOfMonth?,participants模板}` |
| GET/PATCH/DELETE | `/regular-bills/:id` | 详情/修改/停用 |

### 导出 / 统计 / 健康
| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/me/export?format=xlsx\|csv` | 导出我参与/垫付的全部账单，文件流（Content-Disposition attachment） |
| GET | `/me/statistics?year=2025` | `{totalAmountCents,billCount,byMonth,byCategory}` |
| GET | `/health` | `@Public`，返回 `{status:"ok"}` |

---

## 6. 与方案的差异/简化点

- **结算 `billIds` 为近似归属**（见上），非逐账单精确匹配。
- **`settlementIds`**：GET settlement 会把本次方案落库（group 维度最新一条 `pending`），并在响应中额外返回与该方案对齐的 `settlementIds`，供 `POST /settlements/:id/paid` 调用。
- **定期账单垫付人**：生成账单副本时 `payerId` 简化为模板创建者。
- **`settle_status`**：`pending/partial/settled` 由服务端在 `markPaid`/创建时重算。
- **正则/比例分摊**：`ratio` 模式在创建时按客户端传入的 `shareAmountCents`（即已算好的金额）处理，并校验合计=金额，与 `custom` 走同一套校验。
- **权限**：添加成员允许任一 active 成员；移除/编辑群/转让仅 owner；账单编辑仅创建者或群主。
- **Redis 惰性降级**：无 Redis 时仅定期账单扫描不可用，主流程不受影响。

---

## 7. 部署

`Dockerfile` 为多阶段构建：

```bash
docker build -t aa-split-server .
docker run -p 3000:3000 \
  -e DATABASE_URL=postgresql://user:pass@host:5432/aa_split \
  -e JWT_ACCESS_SECRET=... -e JWT_REFRESH_SECRET=... \
  -e OBJECT_STORAGE=local \
  aa-split-server
```

> 本机无 Docker 时不要执行 `docker` 命令；也不建议在没有数据库的情况下运行 `prisma migrate` / `db push`（默认禁止连接本机 5432）。
