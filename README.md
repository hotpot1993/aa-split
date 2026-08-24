# AA分账App 🐼

> 和朋友 AA 分账的手机 App：自定义账户名 + 密码登录，不碰真实资金。
> 风格：手绘风 · 可爱轻松（吉祥物：团团 🐼）

## ✅ 当前状态（代码已生成）

| 产物 | 状态 | 验收 |
|---|---|---|
| 服务端 `server/`（NestJS 10 + Prisma + PostgreSQL，全模块 + SSE + BullMQ + Swagger） | ✅ | `npm install` / `npx prisma generate` / `npm run build` / `npm test`（35/35）全通过 |
| 客户端 `app/`（Flutter + Riverpod + go_router，31 页全量 + `aa_design` 手绘设计系统） | ✅ | `flutter analyze` 0 issues / `flutter test` 3/3 通过 |
| 结算算法（`server/src/settlement/`，含"已付份额排除"修复） | ✅ | 13 个金标准单测全绿 |
| 基础设施（docker-compose / Makefile / CI / 字体 asset） | ✅ | — |
| **真实联调**（本机 PostgreSQL 16.12 便携实例 + API smoke + SSE） | ✅ | `node scripts/smoke-api.mjs` **22/22** · `node scripts/sse-check.mjs` SSE 实时事件 ✅ |

**说明**：客户端默认 **Demo 模式**（`--dart-define=AA_USE_MOCK=false` 切真实后端，见
[app/README.md](app/README.md) 联调清单）；服务端运行需要一个 PostgreSQL 实例
（Docker 不可用时 `npx prisma db push` 建表——本机无 Docker 环境）

## 仓库结构（monorepo）

```
aa-dsh/
├── docs/                     # 产品原型 / UI设计规范 / 技术方案 / 可交互Demo
├── server/                   # NestJS 10 + Prisma + PostgreSQL（REST + SSE）
│   ├── prisma/schema.prisma  # 数据库模型（金额一律以分存储）
│   └── src/
│       ├── auth/             # 注册/登录/JWT/找回/改密
│       ├── users/            # 用户资料
│       ├── groups/           # 群组/成员/邀请码
│       ├── bills/            # 账单/分摊/凭证/催款
│       ├── settlement/       # 最少转账笔数结算算法 + 单测
│       ├── notifications/    # 消息中心 + SSE
│       ├── regular-bills/    # 定期账单（BullMQ 调度）
│       ├── export/           # 数据导出（xlsx/csv）
│       └── statistics/       # 统计聚合
└── app/                      # Flutter 客户端
    ├── lib/                  # 主工程（Riverpod + go_router）
    └── packages/aa_design/   # 手绘风设计系统（组件库）
```

## 快速开始

### 服务端

```bash
cd server
npm install
npx prisma generate          # 生成 Prisma Client
npm run dev                  # 开发模式 http://localhost:3000/api/v1
npm test                     # 单元测试（含结算算法 13 例）
npm run build                # 类型检查 + 产物
```

API 文档（Swagger）：启动后访问 <http://localhost:3000/api/docs>

需要本地 PostgreSQL/Redis/MinIO：

```bash
docker compose up -d postgres redis minio   # 或整体 docker compose up -d
```

> 无 Docker 的机器可配置 `DATABASE_URL` 指向任意 PostgreSQL 16 实例，
> 建表：`npm run prisma:migrate:deploy`（正式迁移，见 `server/prisma/migrations`）；
> Windows 上也可以一键起便携 PostgreSQL：`powershell -ExecutionPolicy Bypass -File scripts\dev-db.ps1 init`。
> 演示数据：`npm run prisma:seed`。
> 联调自检：`node scripts/smoke-api.mjs`（22 步全链路）、`node scripts/sse-check.mjs`（SSE 实时推送）。

### 客户端

```bash
cd app
flutter pub get
flutter run                  # 真机/模拟器（默认 Demo 模式，无需后端）
flutter analyze              # 静态检查
flutter test                 # 组件/单元测试
```

## 技术栈（已确认）

| 层 | 选型 |
|---|---|
| 客户端 | Flutter 3.x + Riverpod + go_router + dio；手绘风 CustomPainter 组件库 `aa_design` |
| 服务端 | NestJS 10 (TypeScript) + Prisma + PostgreSQL 16 + Redis/BullMQ + MinIO + SSE |
| 部署 | Docker Compose 单机（api + postgres + redis + minio + nginx） |

- 金额一律 **整数分（int）** 存储与传输，展示层格式化 `¥xx.xx`
- 结算算法位于服务端，事务内保证一致性；响应统一 `{ code, message, data }`
- 详细设计见 [docs/](./docs/README.md)

## 文档

- 📦 [产品原型（31 页流程）](docs/AA分账App-产品原型.md)
- 🎨 [UI 设计规范](docs/AA分账App-UI设计规范.md)
- ⚙️ [技术方案（数据库/API/算法/排期）](docs/AA分账App-技术方案.md)
- 🖥️ [手绘风高保真 Demo（浏览器打开）](docs/ui-demo/index.html)
- 🏪 [商店上架准备（素材/文案/法务/手册）](docs/store/上架手册.md)
  - 上架包：`make app-release` → `dist/release/`（AAB + 多 ABI APK + SHA256 + 签名指纹）
  - 素材：商店图标（`docs/store/icons/`）、截图（`docs/store/screenshots/`）
  - 法务：隐私政策 <https://api.hotpot1993.top/privacy.html> · 用户协议 <https://api.hotpot1993.top/agreement.html>

## 合规声明

本 App 不托管资金、不代收代付；用户间转账走微信/支付宝自有功能。详见技术方案 §8。
