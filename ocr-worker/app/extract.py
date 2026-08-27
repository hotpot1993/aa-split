"""金额规则提取器：从 OCR 文本行中提取小票「总金额」。

纯逻辑模块，无第三方依赖，可独立测试。

输入约定（与 RapidOCR 输出对齐）：
  - text: 行文本
  - box: 四角坐标 [[x1,y1],[x2,y2],[x3,y3],[x4,y4]]（像素）
  - confidence: 0~1

设计要点（对应 docs/AA分账App-小票OCR识别.md §7）：
  - 关键词行优先：合计/总计/应付/... / TOTAL/AMOUNT DUE/...
  - 位置加分：图片下部 1/3
  - 金额形态加分：恰好两位小数
  - 短行加分：行内除金额与货币符号外的文本极短
  - 折扣/退款行降权；负号前缀金额跳过
  - 无关键词 → 取下部区域最大金额（bottom_max）
  - 币种：符号识别，无符号默认 CNY；非 CNY 挂 warning
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any

# ---------------------------------------------------------------- 常量

# 中文关键词（substring 匹配；越靠前越具体）
KEYWORDS_ZH = (
    "价税合计", "小写金额", "小写合计", "付款金额", "应付金额",
    "实付金额", "应收金额", "折后合计", "合计", "总计", "应付", "实付",
    "应收", "总额", "折后", "实收", "金额",
)
# 英文关键词（词边界匹配；payment/cash 等是「收款行」而非总额，归入降权）
KEYWORDS_EN = (
    "grand total", "amount due", "balance due", "final sale",
    "total amount", "total", "total incl of gst", "net total",
)
# 弱关键词：小计类（有更强 TOTAL 时应让位）
WEAK_KEYWORDS_EN = ("subtotal",)
# 折扣/退款/收款行降权关键词
PENALTY_ZH = ("优惠", "折扣", "打折", "退款", "返还", "返现", "找零", "退", "券")
PENALTY_EN = (
    "discount", "refund", "change", "off", "coupon", "cash back",
    "cash", "cashier", "paid", "payment", "return", "promo", "trade",
    "qty", "quantity",
)

SYMBOL_CURRENCY = {
    "¥": "CNY", "￥": "CNY",
    "$": "USD", "€": "EUR", "£": "GBP",
}

# 金额候选：前置可选货币符号；优先匹配「带千分位」形式（1,234.56），
# 否则任意位数数字（中文小票无千分位：1450.00 / 23344.00 必须整段匹配，
# 不能先取 \d{1,3} 截断）+ 可选 1~2 位小数。
AMOUNT_RE = re.compile(
    r"([¥￥$€£])?\s*((?:\d{1,3}(?:,\d{3})+)(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)"
)
# 电话号码/单号形态（4008-567-728 / 020-23558888）：其内数字不是金额
PHONE_RE = re.compile(r"\d{3,4}-\d{3,4}(?:-\d{3,4})?")
# 行内负号前缀（退款/扣减），跳过该候选
NEG_PREFIX_RE = re.compile(r"[-−–]\s*$")

# 结果置信度归一化：score_raw / SCORE_NORM，上限 1.0
SCORE_NORM = 4.0


@dataclass
class OcrLine:
    text: str
    box: list[list[float]] = field(default_factory=list)
    confidence: float = 1.0  # OCR 置信度

    @staticmethod
    def from_dict(d: dict[str, Any]) -> "OcrLine":
        return OcrLine(
            text=str(d.get("text", "")),
            box=[[float(v) for v in p] for p in (d.get("box") or [])],
            confidence=float(d.get("confidence", 1.0)),
        )


@dataclass
class _Candidate:
    value_cents: int
    symbol: str | None
    text: str          # 整行文本（用于展示 matched_text）
    line_conf: float
    y_norm: float      # 行底部 y 的归一化位置（0=顶，1=底）
    keyword_hit: bool  # 关键词命中（池选择的唯一依据，不依赖分数）
    has_cents: bool    # 恰好两位小数（数量/日期等裸整数为 False）
    extras: float = 0.0

    @property
    def score_raw(self) -> float:
        return self.line_conf + self.extras


def _kw_token_match(tokens: set[str], keywords: tuple[str, ...]) -> str | None:
    """token（≥4 字符、小写）与关键词编辑距离 ≤1 的模糊命中；返回命中的关键词。"""
    for token in tokens:
        if len(token) < 4:
            continue
        for kw in keywords:
            if token == kw:
                return kw
            if abs(len(token) - len(kw)) > 1:
                continue
            if _edit_distance(token, kw) <= 1:
                return kw
    return None


def _edit_distance(a: str, b: str) -> int:
    if len(a) > len(b):
        a, b = b, a
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[-1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def _has_keyword(text: str) -> bool:
    t = text.lower()
    if any(k in text for k in KEYWORDS_ZH):
        return True
    if any(re.search(r"\b" + re.escape(k) + r"\b", t) for k in KEYWORDS_EN + WEAK_KEYWORDS_EN):
        return True
    # OCR 拼写容差：Tota Incl / Subtotai 等（仅英文关键词，编辑距离 ≤1）
    tokens = set(re.findall(r"[a-z]{4,}", t))
    return _kw_token_match(tokens, KEYWORDS_EN + WEAK_KEYWORDS_EN) is not None


def _is_strong_keyword(text: str) -> bool:
    """强关键词（总计/合计类）；小计（subtotal/小计）为弱关键词。"""
    t = text.lower()
    if any(re.search(r"\b" + re.escape(k) + r"\b", t) for k in KEYWORDS_EN):
        return True
    tokens = set(re.findall(r"[a-z]{4,}", t))
    if _kw_token_match(tokens, KEYWORDS_EN) is not None:
        return True
    if "小计" not in text and any(k in text for k in KEYWORDS_ZH):
        return True
    return False


def _keyword_bonus(text: str) -> float:
    """关键词加分：强关键词 +2.0（多字中文 +0.4 细分权）；弱关键词（小计类）+1.5。"""
    if not _is_strong_keyword(text):
        return 1.5
    bonus = 2.0
    if any(len(k) >= 3 and k in text for k in KEYWORDS_ZH):
        bonus += 0.4
    return bonus


def _has_penalty(text: str) -> bool:
    t = text.lower()
    if any(k in text for k in PENALTY_ZH):
        return True
    if any(re.search(r"\b" + re.escape(k) + r"\b", t) for k in PENALTY_EN):
        return True
    return False


def _parse_amount(raw: str) -> tuple[int, bool]:
    """解析金额字符串 → (分, 是否恰好两位小数)。"""
    normalized = raw.replace(",", "")
    if "." in normalized:
        whole, frac = normalized.split(".", 1)
        if len(frac) == 2:
            return int(whole) * 100 + int(frac), True
        frac = (frac + "0")[:2]
        return int(whole) * 100 + int(frac), False
    return int(normalized) * 100, False


def _is_valid_candidate(cand: _Candidate, keyword_hit: bool) -> bool:
    """候选有效性：有符号 / 关键词行 / 恰好两位小数。"""
    return cand.symbol is not None or keyword_hit or _cents_hint_ok(cand)


def _cents_hint_ok(cand: _Candidate) -> bool:
    # value_cents % 100 可判定，但两位小数信息在 parse 时丢失；
    # 通过文本回查：其实这里用 extras 里的小数位标记更准，见 _extract_candidates。
    return cand.extras >= 0.5  # 两位小数加分已写入 extras


def _extract_candidates(
    line: OcrLine,
    keyword_hit: bool,
    penalty_hit: bool,
    y_norm: float,
) -> list[_Candidate]:
    out: list[_Candidate] = []
    text = line.text
    phone_spans = [(m.start(), m.end()) for m in PHONE_RE.finditer(text)]
    for m in AMOUNT_RE.finditer(text):
        # 跳过：空匹配 / 纯日期片段（长度不足且无符号）
        if not m.group(2):
            continue
        # 电话号码/单号内的数字不是金额（4008-567-728）
        s, e = m.start(2), m.end(2)
        if any(ps <= s and e <= pe for ps, pe in phone_spans):
            continue
        # 百分号后缀跳过（税率/折扣率行：GST 6%、-5%）
        after = text[m.end(2):]
        if after.lstrip()[:1] in ("%", "%", "％"):
            continue
        # 负号前缀跳过（退款/折扣行常见：-2.00）
        prefix = text[: m.start(1) if m.group(1) else m.start(2)]
        if NEG_PREFIX_RE.search(prefix):
            continue

        raw = m.group(2)
        # 过滤明显非金额：两位小数缺失时必须有符号或关键词行（由调用方复核）
        value_cents, has_cents = _parse_amount(raw)

        extras = 0.0
        if has_cents:
            extras += 0.5
        if m.group(1):  # 有货币符号
            extras += 0.25
        # 含税/不含税偏好：Invoice 常见 Total Excl. / Total Incl. of GST 双行
        t = text.lower()
        if "excl" in t:
            extras -= 0.5
        elif "incl" in t:
            extras += 0.3
        if keyword_hit and (has_cents or m.group(1)):
            # 裸整数（无小数位、无货币符号）不给关键词加分：数量/日期/税率干扰太多
            bonus = _keyword_bonus(text)
            extras += bonus
        if penalty_hit:
            extras -= 2.0
        if y_norm and y_norm > 2 / 3:
            extras += 1.0
        # 短行：去掉金额与符号后剩余 ≤6 字符
        remainder = text[: m.start(2)] + text[m.end(2):]
        remainder = re.sub(r"[¥￥$€£\s:：,，.。]", "", remainder)
        if len(remainder) <= 6:
            extras += 0.5

        out.append(
            _Candidate(
                value_cents=value_cents,
                symbol=m.group(1),
                text=text,
                line_conf=line.confidence if 0 <= line.confidence <= 1 else 1.0,
                y_norm=y_norm,
                keyword_hit=keyword_hit,
                has_cents=has_cents,
                extras=extras,
            )
        )
    return out


def _y_norm(line: OcrLine, img_height: float | None) -> float:
    """行底部 y 的归一化位置；无图像高度时按行排序秩近似。"""
    ys = [p[1] for p in line.box if len(p) >= 2]
    if not ys:
        return 0.0
    bottom = max(ys)
    if img_height and img_height > 0:
        return min(1.0, bottom / img_height)
    return 0.5  # 缺高度时不给位置分，交由关键词与形态决定


def _line_metric(line: OcrLine) -> tuple[float, float]:
    """行的 (中心 y, 高度)：用于跨行关键词关联的距离计算。"""
    ys = [p[1] for p in line.box if len(p) >= 2]
    if not ys:
        return 0.0, 30.0
    return (max(ys) + min(ys)) / 2, max(30.0, max(ys) - min(ys))


def _link_keyword_across_lines(
    ocr_lines: list[OcrLine],
    line_candidates: list[tuple[OcrLine, list[_Candidate]]],
) -> None:
    """跨行关键词关联（检测器常把「合计」「TOTAL」与金额拆成两个文本框）。

    对「含关键词但本行无金额候选」的行：
      - 优先关联同排（|dy| <= 0.5 行高）的金额行；
      - 否则关联正下方（0 < dy <= 3 行高）最近的金额行；
    命中后给该行全部候选加上关键词加分并标记 keyword_hit。
    """
    has_cands = {id(line) for line, _ in line_candidates}
    if not line_candidates:
        return
    for kw_line in ocr_lines:
        if not _has_keyword(kw_line.text) or id(kw_line) in has_cands:
            continue
        ky, kh = _line_metric(kw_line)
        best_idx = -1
        best_key: tuple[float, float] | None = None  # (dist, |dy|)
        for idx, (line, _cands) in enumerate(line_candidates):
            ly, _lh = _line_metric(line)
            dy = ly - ky
            if dy < -0.5 * kh or dy > 6 * kh:
                continue
            # 同排（|dy|<=0.5 行高）优先；跨排按垂直距离（扫描件行距大，容忍 6 倍行高）
            dist = abs(dy) if dy <= 0.5 * kh else 6 * kh + (dy - 0.5 * kh)
            key = (dist, abs(dy))
            if best_key is None or key < best_key:
                best_key = key
                best_idx = idx
        if best_idx >= 0:
            bonus = _keyword_bonus(kw_line.text)
            for c in line_candidates[best_idx][1]:
                if c.keyword_hit:
                    continue  # 已关联过一次的关键词行不再叠加（防双词行堆分）
                if not c.has_cents and c.symbol is None:
                    continue  # 裸整数候选不给关键词加分（数量/日期干扰）
                c.extras += bonus
                c.keyword_hit = True


def _pick_best(pool: list[_Candidate]) -> _Candidate:
    """同分档决胜：先取金额更大者，再取位置更靠下的。

    依据（真实发票语料校验）：GST 发票常排版 Subtotal ≤ Total Excl ≤ Total Incl ≤
    Total Rounded（金额递增、行序靠下），「最终应付总额 = 关键词行里最大的那个」；
    位置优先在单金额小票上等价，但在多总计行上会选中 Excl 之前/之后的旧值。
    score_raw 相差 < 0.05 视为同分档（容忍 OCR 置信度噪声）。
    """
    best_score = max(c.score_raw for c in pool)
    near = [c for c in pool if c.score_raw >= best_score - 0.05]
    near.sort(key=lambda c: (c.value_cents, c.y_norm), reverse=True)
    return near[0]


def extract_amount(
    lines: list[dict[str, Any]] | list[OcrLine],
    img_height: float | None = None,
    *,
    min_cents: int = 0,
) -> dict[str, Any]:
    """从 OCR 行集合提取总金额。

    返回：
      amount_cents  int | None      金额（分）；None=识别不到
      currency      str             CNY/USD/EUR/GBP
      confidence    float | None    0~1
      method        "keyword" | "bottom_max" | "none"
      matched_text  str | None      命中的整行文本
      warning       str | None      "symbol_non_cny" / "negative_row" 等
    """
    ocr_lines = [OcrLine.from_dict(l) if isinstance(l, dict) else l for l in lines]

    line_candidates: list[tuple[OcrLine, list[_Candidate]]] = []
    for line in ocr_lines:
        if not line.text.strip():
            continue
        kw = _has_keyword(line.text)
        pen = _has_penalty(line.text)
        yn = _y_norm(line, img_height)
        cands = _extract_candidates(line, kw, pen, yn)
        valid = [c for c in cands if _is_valid_candidate(c, kw)]
        if valid:
            line_candidates.append((line, valid))

    # 跨行关键词关联：关键词框与金额框被检测器拆开时补偿
    _link_keyword_across_lines(ocr_lines, line_candidates)

    candidates = [c for _, cands in line_candidates for c in cands]

    if not candidates:
        return {
            "amount_cents": None, "currency": "CNY", "confidence": None,
            "method": "none", "matched_text": None, "warning": None,
        }

    # ---- 主选：关键词命中行 ----
    keyword_cands = [c for c in candidates if c.keyword_hit]
    pool = keyword_cands or []
    method = "keyword"
    if not pool:
        # ---- 兜底：下部区域（y_norm>0.5）最大金额，要求两位小数 ----
        bottom = [c for c in candidates if c.y_norm > 0.5 and c.has_cents]
        if bottom:
            pool = bottom
            method = "bottom_max"
        else:
            # 最后兜底：全部候选按分数最大（仅两位小数者）
            pool = [c for c in candidates if c.has_cents] or candidates
            method = "bottom_max"

    # 防止「0.00」类行（如 Weight/Tax 0.00）独占关键词池：有非零候选则剔除零值
    nonzero = [c for c in pool if c.value_cents > min_cents]
    best = _pick_best(nonzero or pool)
    # 诊断字段（debug/验收用）：关键词池与最终池大小
    pool_size = len(nonzero or pool)
    kw_count = len(keyword_cands)

    # 金额不允许为伪 0（如识别到 0.00 行）
    if best.value_cents <= min_cents:
        return {
            "amount_cents": None, "currency": "CNY", "confidence": None,
            "method": "none", "matched_text": best.text, "warning": None,
        }

    confidence = round(min(1.0, best.score_raw / SCORE_NORM), 2)
    symbol = best.symbol or ""
    currency = SYMBOL_CURRENCY.get(symbol, None) or "CNY"
    warning = "symbol_non_cny" if currency != "CNY" else None

    return {
        "amount_cents": best.value_cents,
        "currency": currency,
        "confidence": max(confidence, 0.05),
        "method": method,
        "matched_text": best.text,
        "warning": warning,
        "kw_count": kw_count,  # 诊断字段：关键词池大小（1=单总额行简单票，>1=多总计行发票）
        "pool_size": pool_size,
    }
