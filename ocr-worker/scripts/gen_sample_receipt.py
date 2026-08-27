"""生成合成测试小票图片（用于本地冒烟 / 演示 / eval 样例）。

用法：python scripts/gen_sample_receipt.py [out.png] [total]
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


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


def gen(path: Path, total: float):
    W, H = 480, 640
    img = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(img)
    f = _font(22)
    fs = _font(18)

    lines = [
        ("欢迎光临测试超市", f, 30),
        ("----------------", fs, 70),
        ("商品A          12.00", fs, 110),
        ("商品B           6.50", fs, 140),
        ("面包           15.50", fs, 170),
        ("----------------", fs, 200),
        (f"合计：￥{total:.2f}", f, 240),
        ("谢谢光临", fs, 300),
    ]
    for text, font, y in lines:
        d.text((40, y), text, fill="black", font=font)
    img.save(path)
    print(f"wrote {path}")


if __name__ == "__main__":
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("samples/sample_zh.png")
    total = float(sys.argv[2]) if len(sys.argv) > 2 else 88.00
    out.parent.mkdir(parents=True, exist_ok=True)
    gen(out, total)
