# AA分账App — 项目文档中心 📚

> 产品：和朋友 AA 分账的手机 App（自定义账户名+密码登录，不碰真实资金）
> 风格：手绘风 · 可爱轻松（吉祥物：团团🐼）

## 交付物清单

| # | 文档/产物 | 说明 | 状态 |
|---|---|---|---|
| 1 | [产品原型（完整页面流程）](./AA分账App-产品原型.md) | 31 个页面：信息架构、流程图、逐页线框图、关键流程走查、数据字段 | ✅ |
| 2 | [UI 设计规范（手绘风）](./AA分账App-UI设计规范.md) | 色彩/字体（五级）/材质/组件/动效执行细则/空状态与异常态设计/**图标素材系统（docs/pic 约定）**/逐页视觉 | ✅ |
| 3 | [手绘风高保真交互 Demo](./ui-demo/index.html) | **双击浏览器打开**：33 页可交互原型 + 动效实验室 + 空状态画廊 | ✅ |
| 4 | [技术方案](./AA分账App-技术方案.md) | Flutter + NestJS + PostgreSQL；数据库/API/结算算法/开发排期/成本 | ✅ |
| 5 | [开发进度存档](./开发进度.md) | v1.8：UI 全量对齐 Demo / 字体系统 / 图标素材系统 / 真机修复记录 / **9 项需求修复轮 + 发版 SOP（v1.0.5 已发布）** | ✅ |
| 6 | [自定义图标素材库](./pic/) | **文件名 = 对应 emoji**；`powershell -ExecutionPolicy Bypass -File scripts\process-icons.ps1` 一键处理 | ✅ |
| 7 | [API 端点清单（自动生成）](./api-endpoints.generated.md) | 由 `scripts/sync-docs.mjs` 扫描控制器生成（40 端点，含鉴权/注释摘要）；`docs-sync.yml` 每次 master 推送自动刷新，勿手改 | ✅ |

## 快速入口

- 💡 **想看效果** → `docs/ui-demo/index.html`（浏览器打开）
- 📋 **想确认需求** → 产品原型文档尾部「待确认问题」
- ⚙️ **想开工** → 技术方案 §7 开发计划（M0~M6，共 12 周）

## 技术栈（已确认）

```
客户端  Flutter + Riverpod + go_router（手绘风 CustomPainter 组件库）
服务端  NestJS + Prisma + PostgreSQL + Redis/BullMQ + MinIO
部署    Docker Compose 单机（轻量云服务器 ≈ ¥100/月）
```
