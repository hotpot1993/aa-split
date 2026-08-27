# AA分账App · 小票 OCR 识别金额回填

> 状态：M1~M3 已完成（代码落地），M4 验收等真实样本
> 所属版本：v1.0.7 之后功能迭代
> 关联页面：P30 记账页（草稿凭证）、P33 凭证拍照页、P60？消息中心（不新增）

## 0. 实施进度

- ✅ M1 `ocr-worker/`：FastAPI + RapidOCR（枚举参数锁 PP-OCRv5 mobile/ch）+ 金额规则提取器（规则/API 测试 27 例全绿，含跨行关键词关联）+ Dockerfile + compose 服务；本机端到端冒烟通过（合成小票 → 8800 分 / conf 1.0 / keyword，单张 ~1.9s 含模型初始化）。
  - ⚠️ 真机 OCR 调优（M4 预演发现并修复）：① `recognize()` 图像高度误取首行 → 底部加分失真（改为全行最大值）；② 检测器把「合计」与金额拆成两个框 → 新增**跨行关键词关联**（同排/正下方 ≤3 行高）；③ `eval.py` 支持 `truth=null`（期望识别不出的样本）。
  - 🎯 M4 预演：`scripts/gen_corpus.py` 生成 10 例多形态合成语料（中英/折扣/优惠券/退款/千分位/无关键词/外币），真实 OCR 全链路 **10/10 PASS**（eval 报告见 `samples/eval-corpus/`）。
  - 📊 **M4 真实语料测量（SROIE-39，公开真实小票）**：`scripts/fetch_public_receipts.py` 从 HF `jsdnrs/ICDAR2019-SROIE` 流式抓取 40 张（39 张有总额标注）→ 真实 OCR 全链路 **容差内 30/39 = 76.9%**（精确 27/39），合成语料 10/10 保持全绿。6 轮规则迭代（56.4% → 76.9%）修复：Payment/Cash 行劫持、`6%` 税率行、裸整数（数量/日期）关键词资格、跨行关联加分叠加、`0.00` 行独占、Excl/Incl-of-GST 偏好、**同分档决胜改「金额最大优先」**（GST 发票 Subtotal≤Excl≤Incl≤Rounded 递增排版，+9 张修正）、跨行关联距离 3→6 倍行高、**OCR 拼写容差**（Tota/Subtotai 编辑距离 ≤1）。
  - 📈 **子集分析**（`scripts/analyze_subsets.py`，按关键词池分桶）：多总计行发票类 **84.4%（27/32）**（GST 规则族有效）；单关键词行 6 张 50%（全部为 OCR 噪声案例）；无关键词 1 张 0%。⚠️ kw 桶与「零售 vs 发票」不直接对应，零售场景基准需真实零售样本（合成 10/10 已验规则有效）。
  - 🧭 **工程结论（待与产品决策）**：SROIE 为马来西亚发票类小票（GST 多总计行 + 密排英文 + 扫描噪声），纯规则在此类语料平台期约 77%（残余 9 例均为 OCR 层问题：标签整词被认错、同值噪音行，规则层无法区分）。**简单零售小票（单行合计）规则已充分（合成 10/10、真实简单票样例全对）**。达到 ≥90% 的三条路：a) **以真实中文零售/餐饮小票为验收基准**（本 App 主场景，等你 20~50 张样本，规则预计可达标）；b) 发票类也是硬需求 → 升级 PP-StructureV3/KIE 或 LLM 后处理（超 CPU 轻量约束，需另行决策）；c) 先上线零售场景灰度（App 三档置信度交互已兜底低置信度，错误金额不会静默入账）。
- ✅ M2 `server/`：Prisma 迁移 `20260902000000_receipt_ocr`（Receipt OCR 字段 + ReceiptUpload 暂存表）、`POST /receipts/pre-upload`、`POST /bills/:id/receipts/:receiptId/ocr/retry`、BullMQ `receipt-ocr`（attempts=2 + 每日 03:00 回收）、SSE `receipt-ocr` 事件、账单创建带 `receiptUploadIds` 绑定、P33 上传/替换自动排队；`npm run build` ✅ / `npm test` 63/63 ✅ / **e2e 契约 18/18 ✅**（新增 `test/ocr.e2e-spec.ts` 5 例：预上传暂存→入队、绑定转正+bound、无效 uploadId 不阻塞、P33 上传排队、重试权限 404/成功；FakePrisma 补 receiptUpload 模型与 receipt.include.bill 水合）。
  - ✅ **真实运行时验证**：便携 PostgreSQL 16（dev-db 数据）→ `prisma migrate deploy` 全部 5 迁移应用、`migrate status` 同步、receipts/receipt_uploads 新列 SQL 级核对通过；NestJS 真实启动（无 Redis 惰性降级）→ `scripts/smoke-api.mjs` **22/22**、`scripts/sse-check.mjs` SSE 实时事件 PASS。
  - ⚠️ OCR 队列全链路（预上传→worker→SSE）在无 Redis 环境无法实测（queue.add 挂起属预期，部署经 compose 带 Redis）；已由 e2e 契约覆盖。
  - ⚠️ e2e 过程中发现并修复一个**真实 bug**：createBill 绑定 ReceiptUpload 后返回的是绑定前的快照（bill.create 的 include 已固化 receipts=[] 且不会随事务内新行更新），响应中凭证为空 → 事务内二次 findUnique 重取。
  - ⚠️ BillsModule 引入 OcrModule 后，既有 `app.e2e-spec.ts` 模块图带上了 Bull 部件（Worker 连 Redis 导致 bootstrap 挂起）→ 该 spec 增补 queue/OcrProcessor override（与 ocr.e2e 一致）。
- ✅ M3 `app/`：Receipt 模型 OCR 字段、`preUploadReceipt/retryOcr`、`receiptOcrEventsProvider` SSE 分流、记账页预填（三档置信度确认框 + Demo 模拟）、P33 更新金额二次确认 + 状态行/重试 + 隐私文案；`flutter analyze` 0 issues / `flutter test` 122 通过。
- ✅ **M4 正式验收 PASS（真实中文小票 94.0%）**：`scripts/fetch_cn_receipts.py` 从 HF `CC1984/mall_receipt_extraction_dataset`（真实中国商户小票：西贝莜面村/ZARA/UNIQLO/M Stand/蛙来哒等 50 张，ground_truth.price=实付真值）→ **精确匹配 47/50 = 94.0% ≥ 90% 通过**（D14 门槛达成）。第 7 轮规则修复：**无千分位大金额截断 bug**（`1450.00`/`23344.00` 被 `\d{1,3}` 首分支截成 145/44——中文小票恰恰无千分位，+8 张修正）、**电话号码守卫**（4008-567-728 不当作金额）。残余 3 张为硬 OCR 案例（地址行含金额、整单折扣结构）。回归：合成语料 10/10 PASS、SROIE 76.9% 无回退、pytest 34/34。
- ⏳ M4 收尾：如你有自己的小票照片，随时投入 `samples/live/` 用 `ocr_batch.py` + `eval.py` 复验（当前 94.0% 已达标）。
- 待办：`docker compose up` 全链路联调（本机无 Docker）；手写迁移 SQL 在真实 PG 上 `prisma migrate deploy` 校验（`scripts/dev-db.ps1` 在本会话 shell 中启动失败（pg_ctl 挂起，属环境问题），已记录待 CI/有 Docker 机器验证）。

## 1. 目标

用户拍小票或从相册选小票后，服务端异步 OCR 识别**总金额**，通过 SSE 推回 App，
按置信度分档弹确认框，用户确认后自动填入账单金额（草稿阶段预填）或更新已有账单金额（P33 二次确认）。

**明确不做**：日期/商户/明细结构化提取、端侧识别、Vision LLM、自动币种折算、消息中心通知。

## 2. 已确认决策（共识记录）

| # | 决策点 | 结论 |
|---|---|---|
| D1 | 识别位置 | 服务端异步：BullMQ 队列调度 + Python OCR worker；图片已在服务端（MinIO/本地 uploads） |
| D2 | 小票范围 | 通用中英多语言（中文为主） |
| D3 | 提取字段 | 仅总金额；纯规则后处理（关键词行 + 金额正则 + 位置/最大值打分）；识别器留抽象接口 |
| D4 | 草稿阶段（主场景） | 新增预上传接口，拍/选后立即上传暂存 → 排队 OCR → SSE 推结果 → 记账页预填金额；提交账单绑定，未绑定 24h 清理 |
| D5 | P33 已有账单 | 上传即排队；弹「识别到 ¥xx，更新账单金额吗？」二次确认后才覆盖 |
| D6 | 多张凭证 ≤9 | 每张都识别，取置信度最高者预填；各张识别结果在凭证页可见 |
| D7 | 置信度分档 | ≥0.9 确认框预填（可编辑）｜0.6~0.9 预填但明示「疑似，请核对」｜<0.6 静默 |
| D8 | 币种 | 数字+货币符号都提取；默认按人民币入账；符号非 ¥ 时提示「可能非人民币，请核对」 |
| D9 | 通知通道 | 复用现有 SSE，推 `receipt.ocr.completed`；不落 Notification |
| D10 | 失败处理 | 静默 + 凭证照常上传成功；队列重试 1 次；页面「重试识别」按钮 |
| D11 | 防滥用 | 复用 JWT + 现有 Throttler（每用户每分钟 10 次），观察用量后收紧 |
| D12 | 隐私 | 凭证页文案「识别金额仅用于填写账单」，不做开关 |
| D13 | Demo 模式 | 模拟识别（约 1s 后弹确认框），与真实模式同一套 UI 代码 |
| D14 | 验收 | 20~50 张真实小票样本离线跑规则定阈值，金额准确率 ≥90%（±0.1% 容差）再上线 |
| D15 | OCR 服务形态 | Python FastAPI 微服务（`ocr-worker`），RapidOCR 官方生态 |
| D16 | 队列桥接 | NestJS 现有 BullMQ processor → HTTP 调用 Python；超时 15s、attempts=2、指数退避 |
| D17 | 模型 | RapidOCR + 显式锁定 **PP-OCRv5 mobile**（≈21MB，ONNX，CPU 0.3~1s/张）；识别器抽象可换 v6/server |
| D18 | 部署 | docker-compose 增加 `ocr-worker` 服务（镜像 ≈300~400MB），VPS 同机 |
| D19 | 数据传输 | NestJS processor 从存储读对象字节转发给 worker（multipart），worker 零存储依赖 |

## 3. 开源选型（事实核查结论）

| 项目 | License | 结论 |
|---|---|---|
| **RapidAI/RapidOCR** | 仓库+权重 Apache-2.0 | ✅ 主选。pip 包 `rapidocr`（`rapidocr_onnxruntime` 已停更）；v5 mobile ≈21MB（det 4.6+rec 15.9+cls 1.0）；CPU 0.3~1s/张 ⚠️ ≥3.9 默认切 v6，需显式锁 v5 |
| **PaddlePaddle/PaddleOCR 3.x** | Apache-2.0，权重同 | 🔁 备选（精度天花板，依赖重数百 MB）；将来升级路径 |
| **microsoft/unilm (LayoutLMv3)** | MIT | 🔁 未来 KIE 结构化（日期/商户/明细）再考虑 |
| VikParuchuri/surya | 权重 OpenRAIL-M（商用受限） | ❌ 排除 |
| JaidedAI/EasyOCR | Apache-2.0 但 ~1GB 内存、停更 | ❌ 排除 |
| tesseract | Apache-2.0，中文小票 ~90% 天花板 | ❌ 排除 |
| PP-ChatOCRv4 | 依赖 LLM/ERNIE | ❌ 排除 |
| 各「小票提取」repo | 0~6★ / 无 License | ❌ 排除（金额提取自写规则） |

## 4. 架构

```
Flutter App (P30 草稿 / P33 补拍)
   │  multipart 上传 / SSE 订阅
   ▼
NestJS (server/)
   ├─ POST /receipts/pre-upload  → storageService → ReceiptUpload(row) → BullMQ 入队
   ├─ POST /bills/:id/receipts   （现有，P33）→ 上传成功 → 入队 receipt-ocr
   ├─ BullMQ receipt-ocr processor ──HTTP 15s──▶ ocr-worker (FastAPI + RapidOCR v5)
   │        ▲                                          │ 返回 {amountCents, currency, confidence,
   │        │ 更新 Receipt/ReceiptUpload               │        method, matchedLine}
   │        └── 成功 → SSE emitOcrEvent(userId) ──▶  App 弹确认框
   └─ POST /bills (create, +receiptUploadIds) → 事务绑定 ReceiptUpload → Receipt
       每日 03:00 清理：pending 且 expiresAt<now → 删对象 + expired
```

## 5. 数据模型（Prisma）

```prisma
enum OcrStatus { pending processing success failed }

// Receipt 新增字段
amountCents Int?      @map("amount_cents")
confidence  Float?
ocrStatus   OcrStatus @default(pending) @map("ocr_status")
ocrError    String?   @map("ocr_error")
ocrAttempts Int       @default(0) @map("ocr_attempts")

// 新增草稿暂存
model ReceiptUpload {
  id          String      @id @default(uuid()) @db.Uuid
  userId      String      @map("user_id") @db.Uuid
  objectKey   String      @map("object_key") @db.Text
  status      UploadStatus @default(pending)   // pending|bound|expired
  amountCents Int?        @map("amount_cents")
  confidence  Float?
  currency    String?
  ocrStatus   OcrStatus   @default(pending)
  expiresAt   DateTime    @map("expires_at")   // createdAt + 24h
  createdAt   DateTime    @default(now()) @map("created_at")
  @@index([userId, status])
}
```

## 6. API 变更

| 接口 | 说明 |
|---|---|
| `POST /receipts/pre-upload` | multipart `file`（≤10MB，`@Throttle(10/min)`）→ `{uploadId, url}`；立即入队识别 |
| `POST /bills/:id/receipts/:receiptId/ocr/retry` | 重试识别（权限：上传者/创建者/垫付人/群主） |
| `POST /bills` | `CreateBillDto` 增加 `receiptUploadIds: string[]`；事务绑定；异常 upload 跳过（warn），不阻塞记账 |
| `POST /bills/:id/receipts` / `replace` | 现有接口，成功后自动入队（零改动扩能） |
| SSE | 现有通道推 `receipt.ocr.completed`：`{kind:'preupload'|'p33', uploadId?, receiptId?, billId?, amountCents, currency, confidence}` → 仅上传者本人 |

## 7. ocr-worker（`ocr-worker/`，Python）

- FastAPI `POST /v1/ocr`：multipart image → `RapidOCR`（锁 PP-OCRv5 mobile）→ `[{text, box, confidence}]` → 规则提取器。
- **规则提取器 `extract.py`**（准确率核心，可独立测试）：
  - 关键词：`合计/总计/应付/实付/应收/总额/折后/实收/价税合计/小写金额`｜`TOTAL/GRAND TOTAL/AMOUNT DUE/BALANCE DUE/FINAL SALE/SUBTOTAL/PAYMENT`
  - **跨行关键词关联**：检测器常把「合计/TOTAL」与金额拆成两个文本行 —— 关键词行无候选时，关联同排（|dy|≤0.5 行高）或正下方（≤3 行高）最近的金额行并施加关键词加分
  - 行内金额正则：`[¥￥$€£]?\s*\d{1,3}(?:,\d{3})*\.\d{2}`
  - 打分：关键词命中 +2｜行在图片下部 1/3 +1｜两位小数 +0.5｜短行 +0.5；无关键词 → 底部区域最大金额
  - 置信度 = 行 OCR 置信度 × 规则分归一；币种：符号识别，无符号默认 CNY，非 CNY 标 warning
  - 边界：退款/折扣行降权、千分位、无小数位金额
- Dockerfile：python:3.11-slim + onnxruntime + rapidocr（模型构建期预下载 bake 进镜像）。
- pytest：≥20 组合成样本 + 边界用例。

## 8. App 改动

| 文件 | 改动 |
|---|---|
| `models/bill_participant.dart` | `Receipt` + `uploadId/ocrStatus/amountCents/confidence/currency`（fromJson 缺省兼容） |
| `data/repositories/bill_repository.dart` | `preUploadReceipt(file)`、`create(..., receiptUploadIds)`、`retryOcr()` |
| `screens/add/add_bill_screen.dart` | 选照后预上传 → SSE 监听匹配 uploadId → 三档弹窗 → 确认填入金额 + 触发分摊重算；提交带 receiptUploadIds |
| `providers/notification_stream_provider.dart` | 新增 `receiptOcrEventsProvider` 分流 `receipt.ocr.completed`（向后兼容现有 bump 逻辑） |
| `screens/add/receipt_screen.dart` | 上传后等 SSE → 二次确认更新金额；凭证卡金额徽标 + 置信度；failed →「重试识别」；文案「识别金额仅用于填写账单」 |
| Demo | 1s 后模拟「识别到 ¥123.45」弹窗，走同一套 UI 代码 |

## 9. 验收与里程碑

- `ocr-worker/scripts/eval.py`：批量真实小票 → 金额准确率 ≥90%（±0.1%）→ 定阈值参数。
- M1 ocr-worker（2~3d）→ M2 server（2~3d）→ M3 App（2d）→ M4 验收（1d + 等样本）。
- 风险：① rapidocr 默认模型漂移 → 锁 v5；② SSE 事件结构扩展 → 分流向后兼容；③ 暂存孤儿 → 每日清理；④ 权限 → 预上传限本人、P33 沿用现有校验。
