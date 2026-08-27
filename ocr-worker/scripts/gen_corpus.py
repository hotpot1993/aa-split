"""生成多形态合成小票语料 + 真值（M4 验收预演 / 真实样本模板）。

用法：
  python scripts/gen_corpus.py [out_dir]     # 默认 ocr-worker/samples/eval-corpus
生成：
  <out_dir>/<variant>.png   每例一张合成小票
  <out_dir>/truth.json      {file, amount_cents, currency}[]

变体覆盖 docs/AA分账App-小票OCR识别.md §7 规则分支：
  折扣/退款行降权、负号跳过、千分位、无关键词 bottom_max、
  英文 TOTAL/GRAND TOTAL/SUBTOTAL、外币符号警告、无金额（退款小票）、纯金额短票。
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

VARIANTS: list[dict] = [
    # (name, lines[(text, big)], truth_cents, currency, note)
    {"name": "zh_standard", "big_total": True, "lines": [("欢迎光临测试超市", 1), ("商品A          12.00", 0), ("合计：￥88.00", 1)], "truth": 8800, "currency": "CNY"},
    {"name": "zh_discount", "big_total": True, "lines": [("可乐            3.00", 0), ("面包            6.50", 0), ("折扣          -2.00", 0), ("合计          15.50", 1)], "truth": 1550, "currency": "CNY"},
    {"name": "zh_no_keyword", "big_total": False, "lines": [("牛奶 6.50", 0), ("苹果 4.50", 0), ("13.50", 1)], "truth": 1350, "currency": "CNY"},
    {"name": "zh_thousands", "big_total": True, "lines": [("果蔬            3.00", 0), ("合计       1,234.50", 1)], "truth": 123450, "currency": "CNY"},
    {"name": "zh_coupon", "big_total": True, "lines": [("商品B          45.30", 0), ("优惠券        -3.00", 0), ("实付          42.30", 1)], "truth": 4230, "currency": "CNY"},
    {"name": "zh_refund_only", "big_total": True, "lines": [("退款          -2.00", 1)], "truth": None, "currency": "CNY"},
    {"name": "zh_short_amount", "big_total": False, "lines": [("88.00", 1)], "truth": 8800, "currency": "CNY"},
    {"name": "en_total_usd", "big_total": True, "lines": [("MILK        2.50", 0), ("TOTAL    $12.34", 1)], "truth": 1234, "currency": "USD"},
    {"name": "en_grand_total", "big_total": True, "lines": [("BREAD        6.00", 0), ("GRAND TOTAL  56.00", 1)], "truth": 5600, "currency": "CNY"},
    {"name": "en_subtotal", "big_total": True, "lines": [("APPLE        1.20", 0), ("SUBTOTAL  9.90", 1)], "truth": 990, "currency": "CNY"},
]


def _font(size: int):
    for p in (
        r"C:\Windows\Fonts\msyh.ttc",
        r"C:\Windows\Fonts\simhei.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ):
        if Path(p).exists():
            try:
                return ImageFont.truetype(p, size)
            except OSError:
                continue
    return ImageFont.load_default(size)


def gen(out_path: Path, lines: list[tuple[str, int]], big_total: bool) -> None:
    W, H = 480, 160 + len((lines)) * 34
    img = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(img)
    f = _font(22)
    fs = _font(18)
    d.text((40, 18), "===== TEST STORE =====", fill=(120, 120, 120), font=fs)
    y = 60
    for text, is_total in lines:
        d.text((40, y), text, fill="black", font=f if (is_total or not big_total) else fs)
        y += 42
    img.save(out_path)


def main() -> int:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("samples/eval-corpus")
    out_dir.mkdir(parents=True, exist_ok=True)
    truth = []
    for v in VARIANTS:
        p = out_dir / f"{v['name']}.png"
        gen(p, v["lines"], v["big_total"])
        truth.append({"file": p.name, "amount_cents": v["truth"], "currency": v["currency"]})
        print(f"wrote {p}  truth={v['truth']}")
    (out_dir / "truth.json").write_text(
        json.dumps(truth, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"truth.json written ({len(truth)} samples) -> {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
