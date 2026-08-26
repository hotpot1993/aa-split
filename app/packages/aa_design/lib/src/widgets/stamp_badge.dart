import 'dart:math';

import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

import '../theme/aa_fonts.dart';
/// 圆圈印章 —— 严格照搬 Demo `.stamp`：
/// `border:2px solid var(--ink);border-radius:50%;padding:4px 10px;
///  font-size:11px;transform:rotate(-8deg);background:#FFFDF6`
/// 变体：`.stamp.done{color:#5FA876;border-color:#5FA876}`
/// `.stamp.money{color:var(--pink);border-color:var(--pink)}`
class StampBadge extends StatelessWidget {
  const StampBadge({
    super.key,
    required this.text,
    this.image,
    this.color = AAColors.ink,
    this.rotate = -8,
    this.size = 56,
  });

  final String text;

  /// 文字前的素材图标（替代文字 emoji，如「✅已清」→ check 图标 + 已清）
  final String? image;
  final Color color;

  /// 旋转角度（度）
  final double rotate;

  /// 兼容旧参数：不再约束尺寸（高度由 11px 文本 + 4px 内边距决定）
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: AAFonts.title,
        fontSize: 11,
        height: 1.2,
        color: color,
      ),
    );
    return Transform.rotate(
      angle: rotate * pi / 180,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AAColors.cardWhite,
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: image == null
            ? label
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(image!, width: 11, height: 11),
                  SizedBox(width: 4),
                  label,
                ],
              ),
      ),
    );
  }
}
