"""抓取公开真实小票数据集作为 M4 验收语料（研究用途测量，不入库/不打包）。

来源（HuggingFace 公开数据集，流式取前 N 张，避免全量下载）：
  - Voxel51/scanned_receipts     真实扫描小票（RDLC 系），标注含 total
  - jsdnrs/ICDAR2019-SROIE       真实中文小票（ICDAR 2019 SROIE），标注含 total

用法：
  python scripts/fetch_public_receipts.py [--n 40] [--out samples/public-corpus]
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def _cents(value) -> int | None:
    """把数据集 total 字段转成「分」；解析不了返回 None（单独核对）。"""
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return round(float(value) * 100)
    s = str(value).strip()
    if not s:
        return None
    m = re.search(r"\d+(?:[.,]\d{2})?", s)
    if not m:
        return None
    raw = m.group(0)
    if "," in raw and "." in raw:
        raw = raw.replace(",", "")  # 1,234.56
    elif "," in raw:
        raw = raw.replace(",", ".")  # 欧洲/OCR 误读
    parts = raw.split(".")
    cents = int(parts[0]) * 100
    if len(parts) == 2:
        cents += int((parts[1] + "00")[:2])
    return cents


def fetch_voxel51(out: Path, n: int, entries: list[dict]) -> None:
    """Voxel51/scanned_receipts：HF 数据集只有图片无标注 → 仅收集图片（不进入验收）。"""
    import datasets  # noqa: PLC0415

    ds = datasets.load_dataset("Voxel51/scanned_receipts", split="train", streaming=True)
    got = 0
    for i, sample in enumerate(ds):
        img = sample.get("image")
        if img is None:
            continue
        img.save(out / f"v51_{i:03d}.jpg")
        got += 1
        if got >= n:
            break


def fetch_sroie(out: Path, n: int, entries: list[dict]) -> None:
    """jsdnrs/ICDAR2019-SROIE：真实小票，entities.total 为总额标注（真值来源）。"""
    import datasets  # noqa: PLC0415

    ds = datasets.load_dataset("jsdnrs/ICDAR2019-SROIE", split="train", streaming=True)
    got = 0
    for i, sample in enumerate(ds):
        img = sample.get("image")
        if img is None:
            continue
        entities = sample.get("entities") or {}
        if isinstance(entities, str):
            try:
                entities = json.loads(entities)
            except Exception:
                entities = {}
        cents = _cents(entities.get("total")) if isinstance(entities, dict) else None
        name = f"sroie_{i:03d}.jpg"
        img.save(out / name)
        entries.append({"file": name, "amount_cents": cents, "currency": "CNY"})
        got += 1
        if got >= n:
            break


def main() -> int:
    ap = argparse.ArgumentParser(description="抓取公开真实小票语料")
    ap.add_argument("--n", type=int, default=40, help="每来源取前 N 张")
    ap.add_argument("--out", default="samples/public-corpus")
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    entries: list[dict] = []

    # 无标注图片（仅观察用，不进验收）
    nolabel = Path("samples/public-corpus-nolabel")
    nolabel.mkdir(parents=True, exist_ok=True)
    print(f"[1/2] Voxel51/scanned_receipts -> {nolabel} (n={args.n})")
    fetch_voxel51(nolabel, args.n, entries)

    print(f"[2/2] jsdnrs/ICDAR2019-SROIE -> {out} (n={args.n})")
    fetch_sroie(out, args.n, entries)

    truth_path = out / "truth.json"
    truth_path.write_text(json.dumps(entries, ensure_ascii=False, indent=2), encoding="utf-8")
    none_cnt = sum(1 for e in entries if e["amount_cents"] is None)
    print(f"written {len(entries)} samples, {none_cnt} without parseable total -> {truth_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
