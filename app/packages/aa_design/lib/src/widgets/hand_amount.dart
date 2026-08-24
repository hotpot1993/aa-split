import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 金额字号档位
abstract final class AATokensAmountSize {
  static const amount = 40.0;
  static const large = 52.0;
  static const small = 26.0;
}

/// 金额大字（主角）：`¥` 小号上标 + 龙藏体数字（UI规范 §4 排印）
/// 金额单位：分（int），格式化 ¥xx.xx；负数显示 -¥xx.xx
class HandAmount extends StatelessWidget {
  const HandAmount({
    super.key,
    required this.amountCents,
    this.color = AAColors.ink,
    this.size = AATokensAmountSize.amount,
    this.showSign = false,
    this.maxLines = 1,
    this.style,
  });

  final int amountCents;
  final Color color;
  final double size;

  /// 正数也显示 +
  final bool showSign;
  final int maxLines;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final negative = amountCents < 0;
    final abs = amountCents.abs();
    final yuan = abs ~/ 100;
    final cents = (abs % 100).toString().padLeft(2, '0');
    final sign = negative ? '-' : (showSign ? '+' : '');

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontFamily: 'LongCang', color: color, height: 1.15),
          children: [
            if (sign.isNotEmpty)
              TextSpan(
                text: sign,
                style: TextStyle(fontSize: size * 0.72, color: color),
              ),
            TextSpan(
              text: '¥',
              style: TextStyle(fontSize: size * 0.62, color: color),
            ),
            TextSpan(
              text: '$yuan.$cents',
              style: TextStyle(fontSize: size, color: color),
            ),
          ],
        ),
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
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
    final color = amountCents >= 0 ? AAColors.mint : AAColors.coral;
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
