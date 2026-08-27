# M4 验收样本收集说明

把**真实小票照片**放进本目录（或任意子目录），按下方格式填真值，然后跑验收。

## 推荐流程（两步式，省去手填真值）

```bash
# 1) 把照片放到 samples/live/（.jpg/.png），然后：
python scripts/ocr_batch.py --images samples/live
#    → 自动生成 samples/live/draft_truth.json（含我识别出的金额+命中行，供你核对）

# 2) 打开 draft_truth.json 逐行核对：错的改成实际金额、识别不到或应付金额为零的填 null
#    然后另存为 truth.json，跑验收：
python scripts/eval.py --images samples/live --truth samples/live/truth.json --local
```

## 目录结构（推荐）

```
samples/                    # 或任意目录
 ├── 001-超市.jpg           # 直接放照片（清晰的手机拍照/相册原图即可）
 ├── 002-奶茶.jpg
 ├── ...
 └── truth.json             # 你填的真值（格式见下）
```

## truth.json 格式

```json
[
  { "file": "001-超市.jpg", "amount_cents": 8800,  "currency": "CNY" },
  { "file": "002-奶茶.jpg", "amount_cents": 1550,  "currency": "CNY" },
  { "file": "003-退款.jpg", "amount_cents": null }
]
```

- `file`：文件名（与图片同目录）
- `amount_cents`：小票**合计/实付金额（分）**；`null` 表示「这张票没有金额或识别不到才对」（如纯退款票、无合计行的小票）
- `currency`：金额币种（CNY/USD/EUR/GBP），可省略（默认 CNY）

## 跑验收（两种模式）

```bash
# 方式一：本地直连引擎（无需启动服务，推荐先跑这个）
python scripts/eval.py --images samples --truth samples/truth.json --local

# 方式二：通过 HTTP 服务
uvicorn app.main:app --port 8000
python scripts/eval.py --images samples --truth samples/truth.json --url http://127.0.0.1:8000
```

## 通过标准（docs/AA分账App-小票OCR识别.md D14）

金额字段「容差 ±0.1%（且不少于 1 分）」的准确率 **≥90%** 才算验收通过；报告会输出
`精确匹配 / 容差内 / 识别不到` 三档统计与逐张明细（真值 vs 识别值 / 方法 / 置信度 / 命中文本），
用于调阈值和规则分档。
