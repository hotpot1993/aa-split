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
# 含日式繁体写法：合計/総計/税込 等（PDF 小票常用，简体「合计/总计」匹配不到日文「合計/総計」）
KEYWORDS_ZH = (
    "价税合计", "小写金额", "小写合计", "付款金额", "应付金额", "合計金額", "合計", "総計", "総額",
    "税込金額", "税込",
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
PENALTY_ZH = ("优惠", "折扣", "打折", "退款", "返还", "返现", "找零", "退", "券",
              "お預り", "お釣り", "預り", "釣り")  # 日式「收款(お預り)/找零(お釣り)」非总额

# 现金收付（tendered/change）标签词：标签行与其金额常分框，需跨行降权。
# 注意：不含「現金/现金」——它常作为「现付总额」出现（如 現金等 20,900），不能一律降权。
CASH_HANDLING = ("お預り", "お釣り", "預り", "釣り", "おつり", "找零")
PENALTY_EN = (
    "discount", "refund", "change", "off", "coupon", "cash back",
    "cash", "cashier", "paid", "payment", "return", "promo", "trade",
    "qty", "quantity",
)

SYMBOL_CURRENCY = {
    "¥": "CNY", "￥": "CNY",
    "$": "USD", "€": "EUR", "£": "GBP",
}

# 金额候选：前置可选货币符号。三种形态（括号优先级从高到低）：
#   千分位（逗号或点，3 位一组）：1,234 / 1.000 / 1,234.50 —— 点千分位是 OCR 把逗号误读成点
#   欧式小数逗号：30,90（逗号后 2 位 = 小数）
#   普通点小数/整数：12.34 / 23344 / 1450.00
AMOUNT_RE = re.compile(
    r"([¥￥$€£])?\s*((?:\d{1,3}(?:[.,]\d{3})+)(?:\.\d{1,2})?|\d+,\d{2}|\d+(?:\.\d{1,2})?)"
)
# 电话号码/单号形态（4008-567-728 / 020-23558888）：其内数字不是金额
PHONE_RE = re.compile(r"\d{3,4}-\d{3,4}(?:-\d{3,4})?")
# 日期形态（25.05.2024 / 2024年7月21日 / 11/19/2024）：其内数字不是金额
DATE_RE = re.compile(r"\d{2,4}\s*[./\-年]\s*\d{1,2}\s*[./\-月]\s*\d{1,4}")
# 超长纯数字串（交易号/订单号/会员卡号，如 0100024720231028365401）：不是金额
LONG_NUMBER_RE = re.compile(r"\d{8,}")
# 日文假名（ひらがな/カタカナ）：用于 ¥/￥ 符号的币种判别（JPY vs CNY）
KANA_RE = re.compile(r"[\u3040-\u30ff\u31f0-\u31ff]")

# 币种文本标记（按优先级）：金额框无符号时从整票文本推断币种（欧式/美式小票常见）
CURRENCY_TOKENS = (("€", "EUR"), ("EUR", "EUR"), ("£", "GBP"), ("GBP", "GBP"), ("$", "USD"), ("USD", "USD"))


def _infer_currency(ocr_lines: list[OcrLine]) -> str:
    """从整票文本推断币种（金额框无货币符号时的兜底；欧式/美式小票常见）。"""
    text = " ".join(ln.text for ln in ocr_lines if ln.text.strip())
    for token, cur in CURRENCY_TOKENS:
        if token in text:
            return cur
    if any(KANA_RE.search(ln.text) for ln in ocr_lines):
        return "JPY"
    return "CNY"
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
    """解析金额字符串 → (分, 是否恰好两位小数)。

    兼容多种分隔符形态（对畸形多点多逗号结果做尽力解析，绝不抛异常）：
      - 逗号千分位（1,234 / 20,900）；逗号+点（1,234.50：逗号千分位、点小数）
      - 点千分位（1.000 / 10.000，OCR 把逗号误读成点；恰 3 位小数）
      - 欧式小数逗号（30,90：逗号后恰 2 位 = 小数）
      - 普通点小数（12.34）与纯整数
    """
    s = raw.strip()
    if "," in s and "." in s:
        # 逗号=千分位；最后一个小数点是小数分隔，其余点当千分位
        whole, _, frac = s.replace(",", "").rpartition(".")
        whole = whole.replace(".", "")
    elif "," in s:
        parts = s.split(",")
        if len(parts) == 2 and len(parts[1]) == 2:
            # 欧式小数逗号：30,90
            return int(parts[0]) * 100 + int(parts[1]), True
        # 千分位逗号：1,234 / 20,900
        return int(s.replace(",", "")) * 100, False
    elif "." in s:
        parts = s.split(".")
        if len(parts) > 2:
            # 多点（日期/畸形）：最后一个小数点是小数分隔，其余当千分位
            whole = "".join(parts[:-1])
            frac = parts[-1]
        else:
            whole, frac = parts
        # 点千分位：恰 3 位小数
        if len(frac) == 3:
            return int("".join(parts).replace(".", "")) * 100, False
    else:
        return int(s) * 100, False

    # 统一处理「点小数」尾段
    if not frac.isdigit():
        return int(whole or "0") * 100, False
    if len(frac) == 2:
        return int(whole) * 100 + int(frac), True
    frac = (frac + "0")[:2]
    return int(whole) * 100 + int(frac), False


def _is_valid_candidate(cand: _Candidate, keyword_hit: bool) -> bool:
    """候选有效性：有符号 / 关键词行 / 恰好两位小数。"""
    return cand.symbol is not None or keyword_hit or _cents_hint_ok(cand)


def _cents_hint_ok(cand: _Candidate) -> bool:
    # 两位小数是强证据；底部区域的「较短裸整数」（¥10~¥9,999，如 451/800）也是金额形。
    # 更长者多为单号/数量，且 ≥8 位的交易号已在提取阶段被 LONG_NUMBER 剔除；
    # 人民币小票总额几乎都带两位小数，能走到裸整数的都是整数金额票（日式/K 简单小票）。
    if cand.has_cents:
        return True
    yuan = cand.value_cents // 100
    return cand.y_norm > 0.5 and 10 <= yuan <= 9_999


def _extract_candidates(
    line: OcrLine,
    keyword_hit: bool,
    penalty_hit: bool,
    y_norm: float,
) -> list[_Candidate]:
    out: list[_Candidate] = []
    text = line.text
    phone_spans = [(m.start(), m.end()) for m in PHONE_RE.finditer(text)]
    date_spans = [(m.start(), m.end()) for m in DATE_RE.finditer(text)]
    for m in AMOUNT_RE.finditer(text):
        # 跳过：空匹配 / 纯日期片段（长度不足且无符号）
        if not m.group(2):
            continue
        # 电话号码/单号内的数字不是金额（4008-567-728）
        s, e = m.start(2), m.end(2)
        if any(ps <= s and e <= pe for ps, pe in phone_spans):
            continue
        # 日期形态内的数字不是金额（25.05.2024 → 25.05 会被误当金额）
        if any(ds <= s and e <= de for ds, de in date_spans):
            continue
        # 超长纯数字串（交易号/单号/会员卡号，如 0100024720231028365401）：不是金额
        if not m.group(1) and "," not in m.group(2) and "." not in m.group(2) \
                and len(m.group(2)) >= 8 and LONG_NUMBER_RE.fullmatch(m.group(2)):
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
            # 关键词行自身带折扣/退款等降权词（如「商品优惠合计」含「优惠」）时，
            # 跨行关联也必须同样降权，否则该「小计类折扣行」会误拿关键词加分混入总额池。
            if _has_penalty(kw_line.text):
                bonus -= 2.0
            for c in line_candidates[best_idx][1]:
                if c.keyword_hit:
                    continue  # 已关联过一次的关键词行不再叠加（防双词行堆分）
                # 裸整数候选：小值（数量/日期/单价等，<¥1000）跳过；「金额级」保留以便被合计关键词关联
                if not c.has_cents and c.symbol is None and c.value_cents < 100000:
                    continue
                c.extras += bonus
                c.keyword_hit = True


def _link_cash_penalty_across_lines(
    ocr_lines: list[OcrLine],
    line_candidates: list[tuple[OcrLine, list[_Candidate]]],
) -> None:
    """现金收付标签跨行降权。

    检测器常把「現金お預り」「お釣り」（现金收付/找零）与金额拆成两个框：
    这类金额是「顾客付的钱/找零」，不是账单总额。对含收付标签但本行无金额的标签行，
    找到其同行/紧邻的金额行，把该行的候选降权，避免它们被当成合计（如 現金お預り ¥5,977）。
    注意：不含「現金」，因为「現金等 20,900」这类「现付总额」恰是计总额，不能降权。
    """
    if not line_candidates:
        return
    has_cands = {id(line) for line, _ in line_candidates}
    for label_line in ocr_lines:
        t = label_line.text
        if not any(k in t for k in CASH_HANDLING):
            continue
        # 标签行自身有金额候选：同行走 _extract_candidates 已按里边的收付词降权，交由它处理
        if id(label_line) in has_cands:
            continue
        ky, kh = _line_metric(label_line)
        best_idx = -1
        best_key: tuple[float, float] | None = None
        for idx, (line, _cands) in enumerate(line_candidates):
            ly, _lh = _line_metric(line)
            dy = ly - ky
            # 仅同行或正下方就近（收付行通常紧贴其金额，不必像关键词那样容忍 6 倍行高）
            if dy < -0.5 * kh or dy > 3 * kh:
                continue
            dist = abs(dy) if dy <= 0.5 * kh else 3 * kh + (dy - 0.5 * kh)
            key = (dist, abs(dy))
            if best_key is None or key < best_key:
                best_key = key
                best_idx = idx
        if best_idx >= 0:
            for c in line_candidates[best_idx][1]:
                if c.keyword_hit:
                    continue  # 已被「合计」等强关键词判为总额，不因收付标签降权
                c.extras -= 2.0


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
        # 先不在本行过滤有效性：让「金额框 + 关键词框分离」的裸整数总额
        # 有机会被跨行关键词关联救回（日式小票「合計」与金额常分两个框且无小数位）。
        if cands:
            line_candidates.append((line, cands))

    # 跨行关键词关联：关键词框与金额框被检测器拆开时补偿（会写入 keyword_hit）
    _link_keyword_across_lines(ocr_lines, line_candidates)
    # 现金收付标签跨行降权：「お預り/お釣り」等收付行金额不是总额（如 現金お預り ¥5,977）
    _link_cash_penalty_across_lines(ocr_lines, line_candidates)

    # 关联后再按有效性过滤：有符号 / 被关键词命中 / 恰好两位小数
    line_candidates = [
        (line, [c for c in cands if _is_valid_candidate(c, c.keyword_hit)])
        for line, cands in line_candidates
    ]
    line_candidates = [(line, cs) for line, cs in line_candidates if cs]

    candidates = [c for _, cands in line_candidates for c in cands]

    # 「应收」≠ 实付：小票常同时打印「应收：A」「实收/实付：B」，实际支付额为 B。
    # 一旦全票出现实收/实付，应收（发票应收/未折前金额）行必须让位，
    # 否则「应收往往更大」会让 largest-wins 决胜选成 A（如 1141.80 误判为 822.60）。
    if any("实收" in ln.text or "实付" in ln.text for ln in ocr_lines):
        for c in candidates:
            if "应收" in c.text and "实收" not in c.text and "实付" not in c.text:
                c.extras -= 2.0

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
    if symbol in ("¥", "￥"):
        # ￥/¥ 符号在中/日通用：日式小票带假名视为日元，否则视为人民币
        currency = "JPY" if any(KANA_RE.search(ln.text) for ln in ocr_lines) else "CNY"
    elif symbol:
        currency = SYMBOL_CURRENCY.get(symbol, None) or "CNY"
    else:
        # 金额框无货币符号（如德国 REWE「30,90」与 EUR 分行）：从文本推断币种
        currency = _infer_currency(ocr_lines)
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
