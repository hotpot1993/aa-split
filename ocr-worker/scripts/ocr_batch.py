"""OCR 批处理助手：对目录内所有图片跑识别，生成「草稿真值」供人工核对。

两步验收流程（配合 eval.py）：
  1) python scripts/ocr_batch.py --images samples/live
     → 生成 samples/live/draft_truth.json（file + 我识别出的金额 + 置信度 + 命中行）
  2) 人工打开 draft_truth.json 逐行核对（错的改成实际金额、识别不到的填 null），
     把文件另存为 truth.json，然后：
     python scripts/eval.py --images samples/live --truth samples/live/truth.json [--local]

用法：
  python scripts/ocr_batch.py [--images samples/live] [--prefix live]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

from app.engine import recognize  # noqa: E402
from app.extract import extract_amount  # noqa: E402

IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp", ".bmp"}


def main() -> int:
    ap = argparse.ArgumentParser(description="OCR 批处理 → 草稿真值")
    ap.add_argument("--images", default="samples/live")
    ap.add_argument("--prefix", default="live")
    args = ap.parse_args()

    images_dir = Path(args.images)
    images_dir.mkdir(parents=True, exist_ok=True)
    files = sorted(p for p in images_dir.iterdir() if p.suffix.lower() in IMAGE_EXT)
    if not files:
        print(f"目录 {images_dir} 没有图片。请把真实小票照片(.jpg/.png)放进去后重跑。")
        return 1
    print(f"找到 {len(files)} 张图片，开始识别…")

    draft = []
    for i, p in enumerate(files, 1):
        lines, h = recognize(p.read_bytes())
        r = extract_amount(lines, img_height=h)
        cents = r["amount_cents"]
        draft.append(
            {
                "file": p.name,
                "amount_cents": cents,  # 初值 = OCR 识别值（**人工核对后修正为真值**）
                "currency": r["currency"],
            }
        )
        tag = f"¥{cents / 100:.2f}" if cents is not None else "未识别到"
        print(f"  [{i}/{len(files)}] {p.name:<28} {tag:<12} conf={r['confidence']} "
              f"matched={str(r['matched_text'])[:28]!r}")

    out = images_dir / "draft_truth.json"
    out.write_text(json.dumps(draft, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n草稿真值已写入 {out}（amount_cents 请逐行核对后，另存为 truth.json)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
