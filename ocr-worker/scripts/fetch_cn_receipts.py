"""抓取中文真实小票语料（CC1984/mall_receipt_extraction_dataset）并构建真值。

来源：HuggingFace 公开数据集（真实中国商户小票：西贝莜面村/ZARA/UNIQLO/meland 等，
      手机截图/拍照，ground_truth 含 price = 实付金额）。
用途：M4 验收测量（研究用途，不入库/不打包）。

用法：python scripts/fetch_cn_receipts.py [--n 50] [--out samples/cn-corpus]
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=50)
    ap.add_argument("--out", default="samples/cn-corpus")
    args = ap.parse_args()

    import datasets  # noqa: PLC0415

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    ds = datasets.load_dataset(
        "CC1984/mall_receipt_extraction_dataset", split="train", streaming=True
    )
    entries = []
    shops: dict[str, int] = {}
    got = 0
    for i, sample in enumerate(ds):
        img = sample.get("image")
        try:
            import json as _json

            gt = sample.get("ground_truth")
            parse = (_json.loads(gt) if isinstance(gt, str) else gt) or {}
            parse = parse.get("gt_parse", parse)
            price = parse.get("price")
        except Exception:
            continue
        if img is None or price is None:
            continue
        name = f"cn_{i:04d}.jpg"
        img.convert("RGB").save(out / name, quality=92)
        shops[parse.get("shop_name", "?")] = shops.get(parse.get("shop_name", "?"), 0) + 1
        entries.append(
            {
                "file": name,
                "amount_cents": round(float(price) * 100),
                "currency": "CNY",
                "shop": parse.get("shop_name", ""),
            }
        )
        got += 1
        if got >= args.n:
            break

    truth = [{k: v for k, v in e.items()} for e in entries]
    (out / "truth.json").write_text(
        json.dumps(truth, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"written {len(entries)} samples -> {out}")
    for shop, cnt in sorted(shops.items(), key=lambda x: -x[1]):
        print(f"  {shop}: {cnt}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
