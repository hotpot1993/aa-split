import 'package:flutter/material.dart';

import '../core/utils/format.dart';
import '../models/bill.dart';
import 'package:aa_design/aa_design.dart';

/// 涂鸦头像：墨线圆 + emoji/首字（P23/P24/P25/P32 成员头像）
class SketchAvatar extends StatelessWidget {
  const SketchAvatar({
    super.key,
    required this.emoji,
    this.size = 44,
    this.name = '',
  });

  final String emoji;
  final double size;
  final String name;

  @override
  Widget build(BuildContext context) {
    final text = emoji.trim().isEmpty
        ? (name.isEmpty ? '?' : name.substring(0, 1))
        : emoji;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AAColors.cardWhite,
        shape: BoxShape.circle,
        border: Border.all(color: AAColors.ink, width: 2),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: size * 0.5, color: AAColors.ink),
      ),
    );
  }
}

/// 分类小圆图标（流水行用）
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.category, this.size = 40});

  final BillCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = switch (category) {
      BillCategory.food => AAColors.coral,
      BillCategory.traffic => AAColors.sky,
      BillCategory.hotel => AAColors.lilac,
      BillCategory.shopping => AAColors.lemon,
      BillCategory.fun => AAColors.berry,
      BillCategory.other => AAColors.mint,
    };
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        Cat.emoji(category),
        style: TextStyle(fontSize: size * 0.46),
      ),
    );
  }
}
