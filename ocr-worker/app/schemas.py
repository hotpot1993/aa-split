"""Pydantic 响应模型：/v1/ocr 输出。"""

from __future__ import annotations

from pydantic import BaseModel, Field


class OcrLineOut(BaseModel):
    text: str
    box: list[list[float]] = Field(default_factory=list)
    confidence: float = 0.0


class OcrResultOut(BaseModel):
    """识别结果（字段名与 server 端消费方约定一致，见 docs/AA分账App-小票OCR识别.md §6）。"""

    amount_cents: int | None = None   # 金额（分）；None=识别不到
    currency: str = "CNY"             # CNY/USD/EUR/GBP
    confidence: float | None = None   # 0~1；null=未识别
    method: str = "none"              # keyword | bottom_max | none
    matched_text: str | None = None
    warning: str | None = None        # symbol_non_cny 等
    lines: list[OcrLineOut] = Field(default_factory=list)
    elapsed_ms: float = 0.0
