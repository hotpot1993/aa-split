import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 金额字号档位（对应 Demo 内联 font-size）
abstract final class AATokensAmountSize {
  /// .amount 基准 42px
  static const amount = 42.0;

  /// 首页净额大字（同 42）
  static const large = 42.0;

  /// 记账页 ¥220 特大体（Demo P30 = 58px）
  static const hero = 58.0;

  /// 列表行金额（Demo P11/P12 = 24/22px）
  static const row = 24.0;
  static const small = 22.0;

  /// 统计/群账金额
  static const medium = 34.0;
}

/// 金额大字 —— 严格照搬 Demo `.amount`：
/// `font-family:'Long Cang';font-size:42px;line-height:1;letter-spacing:1px`
/// `.amount .yen{font-size:20px;vertical-align:6px;margin-right:2px}`
/// `.amount.pos{color:#5FA876}`（应收） `.amount.neg{color:var(--coral)}`（应付）
class HandAmount extends StatelessWidget {
  const HandAmount({
    super.key,
    required this.amountCents,
    this.color = AAColors.ink,
    this.size = AATokensAmountSize.amount,
    this.showSign = false,
    this.trimZero = false,
    this.maxLines = 1,
    this.style,
  });

  final int amountCents;
  final Color color;
  final double size;

  /// 正数也显示 +
  final bool showSign;

  /// 整数金额省略 .00（Demo 列表行 ¥55 / ¥1,500）
  final bool trimZero;
  final int maxLines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final negative = amountCents < 0;
    final abs = amountCents.abs();
    final yuan = abs ~/ 100;
    final cents = (abs % 100).toString().padLeft(2, '0');
    final sign = negative ? '-' : (showSign ? '+' : '');
    final numText = trimZero && cents == '00' ? '$yuan' : '$yuan.$cents';

    // 人民币符号：0.47 倍字号、上移 approx 6px（vertical-align:6px）、右距 2px
    const yenScale = 0.476;
    final yenLift = size * 0.14; // 42px → ~6px

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (sign.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 1),
              child: Text(
                sign,
                style: TextStyle(
                  fontFamily: 'LongCang',
                  fontSize: size * 0.72,
                  color: color,
                  height: 1.0,
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(0, -yenLift),
            child: Text(
              '¥',
              style: TextStyle(
                fontFamily: 'LongCang',
                fontSize: size * yenScale,
                color: color,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 2),
          Text(
            numText,
            style: TextStyle(
              fontFamily: 'LongCang',
              fontSize: size,
              color: color,
              height: 1.0,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// 金额带语义色小标签（应收绿/应付橙）—— 净额卡用
class HandAmountWithLabel extends StatelessWidget {
  const HandAmountWithLabel({
    super.key,
    required this.amountCents,
    this.label = '应收',
    this.size = 40,
  });

  final int amountCents;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = amountCents >= 0 ? AASemantic.amountPos : AAColors.coral;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        HandAmount(
          amountCents: amountCents,
          color: color,
          size: size,
          showSign: true,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 4),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'ZCOOLKuaiLe',
              fontSize: 12,
              color: AAColors.inkSoft,
            ),
          ),
        ),
      ],
    );
  }
}
