"""RapidOCR 引擎适配层（锁 PP-OCRv5 mobile，ch 中英混合）。

实现要点：
  - 通过配置显式锁定 PP-OCRv5（rapidocr>=3.9 默认已切换到 PP-OCRv6，必须锁版本）
  - engine_type=ONNXRUNTIME（CPU）
  - Rec.lang_type=ch → ch_PP-OCRv5_rec_mobile.onnx（简中+英文+日文混合）
  - 首次运行缺模型时自动从 ModelScope 下载；Docker 构建期用
    `rapidocr download_models --config app/config_ocr.yaml` 预下载 bake 进镜像
  - 新版 API：engine(img) → RapidOCROutput（.boxes/.txts/.scores），无 angle 字段
"""

from __future__ import annotations

import logging
from functools import lru_cache
from typing import Any

logger = logging.getLogger("ocr-worker.engine")

ConfigT = Any  # omegaconf DictConfig（不强制导入，避免类型耦合）


def _build_params() -> dict[str, Any]:
    """锁定 PP-OCRv5 mobile + ch 的配置字典（与 app/config_ocr.yaml 一致）。

    使用 rapidocr 官方枚举（EngineType/LangDet/LangRec/ModelType/OCRVersion），
    即调研确认的可运行写法；勿用旧版 params={'model_type': 'v5'}。
    """
    from rapidocr import EngineType, LangDet, LangRec, ModelType, OCRVersion

    return {
        "Det.engine_type": EngineType.ONNXRUNTIME, "Det.lang_type": LangDet.CH,
        "Det.model_type": ModelType.MOBILE, "Det.ocr_version": OCRVersion.PPOCRV5,
        "Cls.engine_type": EngineType.ONNXRUNTIME, "Cls.lang_type": LangDet.CH,
        "Cls.model_type": ModelType.MOBILE, "Cls.ocr_version": OCRVersion.PPOCRV5,
        "Rec.engine_type": EngineType.ONNXRUNTIME, "Rec.lang_type": LangRec.CH,
        "Rec.model_type": ModelType.MOBILE, "Rec.ocr_version": OCRVersion.PPOCRV5,
    }


@lru_cache(maxsize=1)
def _engine():
    from rapidocr import RapidOCR

    engine = RapidOCR(params=_build_params())
    logger.info("RapidOCR engine ready (PP-OCRv5 mobile / ch)")
    return engine


def recognize(image_bytes: bytes) -> tuple[list[dict[str, Any]], float | None]:
    """识别图片，返回 (ocr 行列表, 图片高度)。

    行格式与 app.extract.OcrLine 对齐：{text, box, confidence}
    失败抛异常（由 main 层转 502）。
    """
    engine = _engine()
    output = engine(image_bytes, use_det=True, use_cls=True, use_rec=True)
    if output is None or output.txts is None:
        return [], None

    boxes = output.boxes  # (N,4,2) float
    txts = output.txts    # list[str]
    scores = output.scores  # list[float]

    lines: list[dict[str, Any]] = []
    img_height: float | None = None
    for i, text in enumerate(txts):
        box = boxes[i] if boxes is not None else []
        if box is not None and len(box) > 0:
            ys = [float(p[1]) for p in box if len(p) >= 2]
            if ys:
                bottom = float(max(ys))
                # 图像高度 = 所有行框底部 y 的最大值（近似；行内像素坐标系）
                if img_height is None or bottom > img_height:
                    img_height = bottom
        lines.append(
            {
                "text": str(text),
                "box": [[float(p[0]), float(p[1])] for p in box] if box is not None else [],
                "confidence": float(scores[i]) if scores is not None and i < len(scores) else 1.0,
            }
        )
    return lines, img_height
