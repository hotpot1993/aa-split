"""子集分析：按关键词池大小分桶统计准确率（单总额行 vs 多总计行发票）。

用法：python scripts/analyze_subsets.py [--images samples/public-corpus] [--truth .../truth.json]
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


def within_tolerance(got: int, truth: int) -> bool:
    return abs(got - truth) <= max(1, round(truth * 0.001))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--images", default="samples/public-corpus")
    ap.add_argument("--truth", default="samples/public-corpus/truth.json")
    args = ap.parse_args()

    truth = json.loads(Path(args.truth).read_text(encoding="utf-8"))
    images_dir = Path(args.images)

    buckets: dict[str, list[dict]] = {
        "simple(单总额行)": [],
        "multi(多总计行)": [],
        "none(无关键词)": [],
    }
    for t in truth:
        if t["amount_cents"] is None:
            continue
        path = images_dir / t["file"]
        lines, h = recognize(path.read_bytes())
        r = extract_amount(lines, img_height=h)
        kw = r.get("kw_count", 0)
        key = "none(无关键词)" if kw == 0 else ("simple(单总额行)" if kw == 1 else "multi(多总计行)")
        buckets[key].append(
            {"file": t["file"], "truth": t["amount_cents"], "got": r["amount_cents"],
             "method": r["method"], "kw": kw}
        )

    print(f"{'子集':<16}{'样本':>5}{'容差内':>7}{'准确率':>8}")
    gran = 0.0
    gran_n = 0
    for key, rows in buckets.items():
        n = len(rows)
        ok = sum(
            1 for r in rows
            if r["got"] is not None and within_tolerance(r["got"], r["truth"])
        )
        print(f"{key:<16}{n:>5}{ok:>7}{(ok / n * 100 if n else 0):>7.1f}%")
        if key != "none(无关键词)":
            gran += ok
            gran_n += n
    print(f"{'合计(有关键词)':<16}{gran_n:>5}{gran:>7}{(gran / gran_n * 100 if gran_n else 0):>7.1f}%")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
