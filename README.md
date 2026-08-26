# AA分账App 🐼

> 和朋友 AA 分账的手机 App：自定义账户名 + 密码登录，不碰真实资金。
> 风格：手绘风 · 可爱轻松（吉祥物：团团 🐼）

## ✅ 当前状态（代码已生成 · 最新版本 v1.0.5 已发布）

| 产物 | 状态 | 验收 |
|---|---|---|
| 服务端 `server/`（NestJS 10 + Prisma + PostgreSQL，全模块 + SSE + BullMQ + Swagger） | ✅ | `npm install` / `npx prisma generate` / `npm run build` / `npm test`（**51/51**，含群解散通知成员同步 / 默认免分摊人员校验等 5 例新增）全通过 |
| 客户端 `app/`（Flutter + Riverpod + go_router，31 页全量 + `aa_design` 手绘设计系统） | ✅ | `flutter analyze` 0 issues / `flutter test` **122/122**（8 张商店截图 golden 回归 + 21 屏视觉冒烟 + 功能回归测试；含本轮 9 项修复的 11 个新用例）/ 真机截屏逐页核对 |
| **UI 视觉基线**（严格对齐 `docs/ui-demo/index.html`） | ✅ | 组件/圆角/阴影/间距/配色/字体五级/交互逐项照搬；字体包前缀命中修复（见 开发进度 v1.6） |
| **图标素材系统**（`docs/pic` → `app/assets/icons`，40 枚全接入） | ✅ | `powershell -ExecutionPolicy Bypass -File scripts\process-icons.ps1`（透明度/水印/裁剪/启动图标一键重跑） |
| 结算算法（`server/src/settlement/`，含"已付份额排除"修复） | ✅ | 13 个金标准单测全绿 |
| 基础设施（docker-compose / Makefile / CI / 字体 asset） | ✅ | — |
| **真实联调**（线上 API smoke + SSE） | ✅ | `node scripts/smoke-api.mjs` **22/22** · `node scripts/sse-check.mjs` SSE 实时事件 ✅（v1.0.5 部署后 2026-08-26 复跑通过） |
| **发行**（v1.0.7+4000，GitHub Actions 正式签名） | ✅ | [GitHub Release](https://github.com/hotpot1993/aa-split/releases/tag/v1.0.7)：AAB + 通用 APK + arm64 APK；**更新包已上传 VPS `/apk/aa-split-v1.0.7-4000.apk`，`/app/version` 返回 VPS 下载 URL（1.0.7+4000）**；VPS 已部署：迁移 `20260901000000` 已应用、线上 smoke **22/22**；4000 = 版本冲突安全档（v1.0.6 系列在 HyperOS 4 出现 -25 降级误判，版本名+构建号双跳档规避） |
| **更新源（VPS 自托管）** | ✅ | 更新流程：GitHub 发布新版本（Actions 正式签名构建）→ 安装包上传至 VPS `/apk/`（nginx 静态托管）→ 服务端 `/app/version` 下发 VPS 下载 URL → 客户端从 VPS 拉取安装；客户端兜底 = API 同源 `/apk/`。Gitee 代码/发行版自动同步（mirror-gitee.yml / release-gitee.yml 及本地自托管 Runner）已移除 |

**说明**：客户端默认 **Demo 模式**（`--dart-define=AA_USE_MOCK=false` 切真实后端，见
[app/README.md](app/README.md) 联调清单）；服务端运行需要一个 PostgreSQL 实例
（Docker 不可用时 `npx prisma db push` 建表——本机无 Docker 环境）

## 仓库结构（monorepo）

```
aa-dsh/
├── docs/                     # 产品原型 / UI设计规范 / 技术方案 / 可交互Demo / 图标素材库(pic/)
├── scripts/                  # build-release.ps1 / process-icons.ps1（图标素材流水线）/ sync-docs.mjs（文档自动同步）/ smoke 等
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
    ├── assets/icons/         # 图标素材产物（透明底 512px，由脚本生成）
    └── packages/aa_design/   # 手绘风设计系统（组件库 + 四套手写字体）
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
- 🎨 [UI 设计规范（含图标素材系统 §6.3）](docs/AA分账App-UI设计规范.md)
- ⚙️ [技术方案（数据库/API/算法/排期）](docs/AA分账App-技术方案.md)
- 🖥️ [手绘风高保真 Demo（浏览器打开）](docs/ui-demo/index.html)
- 📈 [开发进度存档](docs/开发进度.md)（UI 对齐 / 字体 / 图标系统 / 9 项需求修复轮 / 发版 SOP / v1.0.6 修复轮）
- 🔄 **文档自动同步**：每次 `master` 推送后由 [docs-sync.yml](.github/workflows/docs-sync.yml) 自动完成——用真实测试数刷新 README 状态表计数、同步版本串（pubspec → ui-demo）、重新生成 [API 端点清单](docs/api-endpoints.generated.md)；本地可 `node scripts/sync-docs.mjs` 手动执行
- 🖼️ [自定义图标素材库 docs/pic](docs/pic/)（**文件名 = 对应 emoji** → `app/assets/icons`，脚本：`powershell -ExecutionPolicy Bypass -File scripts\process-icons.ps1`）
- 🏪 [商店上架准备（素材/文案/法务/手册）](docs/store/上架手册.md)
  - 上架包：`make app-release` → `dist/release/`（AAB + 多 ABI APK + SHA256 + 签名指纹）
  - 素材：商店图标（`docs/store/icons/`）、截图（`docs/store/screenshots/`）
  - 法务：隐私政策 <https://api.hotpot1993.top/privacy.html> · 用户协议 <https://api.hotpot1993.top/agreement.html>

## 合规声明

本 App 不托管资金、不代收代付；用户间转账走微信/支付宝自有功能。详见技术方案 §8。
