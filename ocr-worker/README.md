# ocr-worker —— 小票 OCR 微服务（RapidOCR + 金额规则提取）

## 职责

接收 NestJS 转发的图片字节，返回：

```json
{
  "amount_cents": 8800,
  "currency": "CNY",
  "confidence": 0.97,
  "method": "keyword",
  "matched_text": "合计 ￥88.00",
  "warning": null,
  "lines": [{"text": "...", "box": [[x,y],...], "confidence": 0.98}]
}
```

- 无第三方服务依赖（存储仍由 NestJS 侧负责，本服务收字节）。
- 模型：RapidOCR，显式锁定 PP-OCRv5 mobile（ONNX，CPU）。
- License：仓库与权重均为 Apache-2.0。

## 本地运行

```bash
pip install -r requirements.txt
uvicorn app.main:app --port 8000          # http://127.0.0.1:8000/docs
```

## 测试

```bash
pip install -r requirements-dev.txt
python -m pytest tests/ -q
```

## Docker

```bash
docker build -t aa-split-ocr-worker .
```

## 验收（M4）

```bash
# 提供真实小票图片目录 + 真值 JSON（见 scripts/eval.py 头部说明）
python scripts/eval.py --images samples/ --truth samples/truth.json --url http://127.0.0.1:8000
```
