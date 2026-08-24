import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 分类/状态小胶囊标签（UI规范 §7.4：圆头小胶囊 + 图标）
class HandTag extends StatelessWidget {
  const HandTag({
    super.key,
    required this.label,
    this.icon,
    this.color = AAColors.sky,
    this.textColor = AAColors.ink,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'ZCOOLKuaiLe',
              fontSize: 12,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
