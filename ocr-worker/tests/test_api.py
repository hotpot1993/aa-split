"""/v1/ocr API 层测试（mock 引擎，验证 main.py 接线与错误路径）。"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from fastapi.testclient import TestClient  # noqa: E402

from app import main as main_mod  # noqa: E402
from app.main import app  # noqa: E402

client = TestClient(app)


def _fake_recognize(data):
    return (
        [
            {"text": "欢迎光临", "box": [[0, 0], [10, 0], [10, 10], [0, 10]], "confidence": 0.9},
            {"text": "合计 ￥88.00", "box": [[0, 900], [200, 900], [200, 930], [0, 930]], "confidence": 0.98},
        ],
        1000.0,
    )


def test_ocr_endpoint(monkeypatch):
    monkeypatch.setattr(main_mod, "recognize", _fake_recognize)
    r = client.post("/v1/ocr", files={"file": ("a.png", b"fakeimage", "image/png")})
    assert r.status_code == 200
    d = r.json()
    assert d["amount_cents"] == 8800
    assert d["method"] == "keyword"
    assert d["currency"] == "CNY"
    assert d["confidence"] is not None and d["confidence"] >= 0.9
    assert any(l["text"] == "合计 ￥88.00" for l in d["lines"])
    assert d["elapsed_ms"] >= 0


def test_ocr_empty_image_400(monkeypatch):
    r = client.post("/v1/ocr", files={"file": ("a.png", b"", "image/png")})
    assert r.status_code == 400


def test_ocr_engine_error_502(monkeypatch):
    def boom(data):
        raise RuntimeError("model dead")

    monkeypatch.setattr(main_mod, "recognize", boom)
    r = client.post("/v1/ocr", files={"file": ("a.png", b"img", "image/png")})
    assert r.status_code == 502
    assert "ocr engine error" in r.json()["detail"]


def test_ocr_not_found_amount(monkeypatch):
    def no_amount(data):
        return ([{"text": "祝您生活愉快", "box": [[0, 0], [10, 0], [10, 10], [0, 10]], "confidence": 0.9}], 1000.0)

    monkeypatch.setattr(main_mod, "recognize", no_amount)
    r = client.post("/v1/ocr", files={"file": ("a.png", b"img", "image/png")})
    d = r.json()
    assert d["amount_cents"] is None
    assert d["method"] == "none"


def test_healthz():
    r = client.get("/healthz")
    assert r.status_code == 200
    assert r.json() == {"ok": True}
