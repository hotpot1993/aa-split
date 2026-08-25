import 'package:flutter/material.dart';

import '../core/utils/format.dart';
import '../models/bill.dart';
import 'package:aa_design/aa_design.dart';

/// 涂鸦头像 —— 严格照搬 Demo `.ava`：
/// `width:44px;height:44px;border:2.5px solid var(--ink);border-radius:50%;
///  font-size:22px;background:#fff`
/// 成员行按 Demo 使用淡彩底（#FFF1EA / #EDF7EE / #F0F6FB / #F7F0FB 等）。
class SketchAvatar extends StatelessWidget {
  const SketchAvatar({
    super.key,
    required this.emoji,
    this.size = 44,
    this.name = '',
    this.background = AAColors.cardWhite,
    this.dimmed = false,
  });

  final String emoji;
  final double size;
  final String name;

  /// 头像底色（默认白；成员行传淡彩）
  final Color background;

  /// 未选中参与者：`opacity:.5`（Demo P32 王五）
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final text = emoji.trim().isEmpty
        ? (name.isEmpty ? '?' : name.substring(0, 1))
        : emoji;
    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: AAColors.ink, width: 2.5),
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: size * 0.5, color: AAColors.ink),
        ),
      ),
    );
  }
}

/// 分类小圆图标（流水行用）—— Demo 账单行的 `.ava`（白底墨线圆 + emoji）
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.category, this.size = 40});

  final BillCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AAColors.cardWhite,
        shape: BoxShape.circle,
        border: Border.all(color: AAColors.ink, width: 2.5),
      ),
      child: Text(
        Cat.emoji(category),
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }
}
