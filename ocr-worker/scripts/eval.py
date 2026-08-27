"""验收脚本：批量真实小票 → 金额准确率评估（M4）。

用法：
  python scripts/eval.py --images samples/ --truth samples/truth.json --url http://127.0.0.1:8000
  python scripts/eval.py --images samples/ --truth samples/truth.json --local   # 直接进程内调用引擎

truth.json 格式：
  [{"file": "a.jpg", "amount_cents": 8800, "currency": "CNY"}, ...]

通过标准（docs/AA分账App-小票OCR识别.md D14）：
  金额字段「容差 ±0.1% 且不少于 1 分」的准确率 >= 90%。

输出：
  - 总览：总数 / 精确 / 容差内 / 识别不到 / 准确率
  - 明细表：每张的 真值 vs 识别值 / 差异 / 方法 / 置信度 / 命中文本
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

# Windows 控制台/重定向统一 UTF-8，避免 GBK 乱码与编码异常
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
sys.stderr.reconfigure(encoding="utf-8", errors="replace")


def within_tolerance(got: int, truth: int) -> bool:
    diff = abs(got - truth)
    tol = max(1, round(truth * 0.001))
    return diff <= tol


def main() -> int:
    ap = argparse.ArgumentParser(description="小票 OCR 金额验收")
    ap.add_argument("--images", required=True, help="小票图片目录（jpg/png）")
    ap.add_argument("--truth", required=True, help="真值 JSON (详见文件头)")
    ap.add_argument("--url", default="http://127.0.0.1:8000", help="ocr-worker 地址")
    ap.add_argument("--local", action="store_true", help="进程内直接调用（不启服务）")
    args = ap.parse_args()

    truth = json.loads(Path(args.truth).read_text(encoding="utf-8"))
    images_dir = Path(args.images)

    if args.local:
        from app.engine import recognize
        from app.extract import extract_amount

        def call(path: Path):
            data = path.read_bytes()
            lines, h = recognize(data)
            r = extract_amount(lines, img_height=h)
            return r
    else:
        import requests

        def call(path: Path):
            with path.open("rb") as f:
                resp = requests.post(
                    f"{args.url}/v1/ocr",
                    files={"file": (path.name, f)},
                    timeout=30,
                )
            resp.raise_for_status()
            return resp.json()

    rows = []
    for t in truth:
        path = images_dir / t["file"]
        if not path.exists():
            print(f"!! 缺失样本: {t['file']}", file=sys.stderr)
            continue
        r = call(path)
        rows.append((t, r))

    # 仅统计有真值的样本（truth=None 表示「期望识别不到」，单独展示）
    scored = [(t, r) for t, r in rows if t["amount_cents"] is not None]
    total = len(scored)
    exact = sum(1 for t, r in scored if r.get("amount_cents") == t["amount_cents"])
    ok = sum(
        1 for t, r in scored
        if r.get("amount_cents") is not None
        and within_tolerance(r["amount_cents"], t["amount_cents"])
    )
    none_ = sum(1 for _, r in scored if r.get("amount_cents") is None)

    print("=" * 72)
    print(f"样本总数      : {total}")
    print(f"精确匹配      : {exact}  ({exact / max(total, 1):.1%})")
    print(f"容差内(±0.1%) : {ok}  ({ok / max(total, 1):.1%})  ← 通过标准 >= 90%")
    print(f"识别不到      : {none_}")
    print("=" * 72)
    print(f"{'file':<28}{'truth':>10}{'got':>10}{'diff':>9}  method  conf    matched")
    for t, r in rows:
        got = r.get("amount_cents")
        diff = (
            ""
            if got is None or t["amount_cents"] is None
            else str(got - t["amount_cents"])
        )
        conf = r.get("confidence")
        print(
            f"{t['file']:<28}{str(t['amount_cents']):>10}{str(got):>10}{diff:>9}  "
            f"{str(r.get('method')):<8}{str(conf):<7}{str(r.get('matched_text'))[:24]}"
        )
    # 期望「识别不到」（truth=None）的样本单独核对
    no_money = [(t, r) for t, r in rows if t["amount_cents"] is None]
    if no_money:
        wrong = [t for t, r in no_money if r.get("amount_cents") is not None]
        print(f"\n期望无金额样本: {len(no_money)} 个，其中误识别出金额: {len(wrong)} 个")
    verdict = "PASS" if total > 0 and ok / max(total, 1) >= 0.9 else "FAIL（阈值/规则需调优）"
    print(f"\n验收结论: {verdict}")
    return 0 if total > 0 and ok / max(total, 1) >= 0.9 else 1


if __name__ == "__main__":
    raise SystemExit(main())
