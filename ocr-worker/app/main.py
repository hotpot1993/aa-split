"""FastAPI 入口：POST /v1/ocr。

接收 NestJS 转发的图片字节 → RapidOCR（锁 PP-OCRv5 mobile + ch）→ 规则提取 → 返回金额。
"""

from __future__ import annotations

import time

from fastapi import FastAPI, File, HTTPException, UploadFile

from app.engine import recognize
from app.extract import extract_amount
from app.schemas import OcrResultOut

app = FastAPI(title="aa-split ocr-worker", version="0.1.0")

MAX_BYTES = 10 * 1024 * 1024  # 与服务端 multer 限制一致


@app.post("/v1/ocr", response_model=OcrResultOut)
async def ocr(file: UploadFile = File(...)) -> OcrResultOut:
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="empty image")
    if len(data) > MAX_BYTES:
        raise HTTPException(status_code=413, detail="image too large")

    t0 = time.perf_counter()
    try:
        ocr_lines, img_height = recognize(data)
    except Exception as exc:  # noqa: BLE001 —— 引擎异常统一 502，由调用方重试
        raise HTTPException(status_code=502, detail=f"ocr engine error: {exc}") from exc
    elapsed_ms = round((time.perf_counter() - t0) * 1000, 1)

    result = extract_amount(ocr_lines, img_height=img_height)
    return OcrResultOut(
        **result,
        elapsed_ms=elapsed_ms,
        lines=ocr_lines,
    )


@app.get("/healthz")
async def healthz() -> dict:
    return {"ok": True}
