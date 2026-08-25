import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 筛选/状态胶囊 —— 严格照搬 Demo `.chip`：
/// `border:2px solid var(--ink);border-radius:999px;padding:3px 11px;
///  font-size:12px;background:#fff`
/// 变体：`.chip.g{bg #EDF7EE,#44795B}` `.chip.o{bg #FFF1EA,#D9592F}`
/// `.chip.t{bg #F0F6FB,#3E7CA6}` `.chip.sel{bg var(--marker)}`
class HandTag extends StatelessWidget {
  const HandTag(
    this.label, {
    super.key,
    this.icon,
    this.color,
    this.textColor,
    this.fontSize = 12,
    this.selected = false,
    this.dense = false,
    this.hpad = 11,
    this.vpad = 3,
    this.variant,
  });

  /// 兼容旧调用：`HandTag(label: ...)`、`HandTag('...')` 均可
  const HandTag.label({
    required this.label,
    super.key,
    this.icon,
    this.color,
    this.textColor,
    this.fontSize = 12,
    this.selected = false,
    this.dense = false,
    this.hpad = 11,
    this.vpad = 3,
    this.variant,
  });

  final String label;
  final IconData? icon;

  /// 兼容旧调用：按 Demo 配色映射（mint→g、coral→o、sky→t、lemon→sel）
  final Color? color;
  final Color? textColor;

  /// 大号（.chip.sel 用于筛选条时 Demo 会放大字体，这里仅字号控制）
  final double fontSize;

  /// 选中态（.chip.sel：荧光笔黄底）
  final bool selected;

  /// 紧凑（Demo 行内小胶囊 padding:2px 8px）
  final bool dense;

  /// 内边距覆盖（默认 11/3；Demo 大号 chip 用 14/7）
  final double hpad;
  final double vpad;

  /// 显式指定 Demo 变体
  final ChipVariant? variant;

  @override
  Widget build(BuildContext context) {
    final v = variant ?? (selected ? ChipVariant.selected : _mapVariant(color));
    final (bg, fg) = switch (v) {
      ChipVariant.green => (AASemantic.chipGreenBg, AASemantic.chipGreenText),
      ChipVariant.orange => (AASemantic.chipOrangeBg, AASemantic.chipOrangeText),
      ChipVariant.blue => (AASemantic.chipBlueBg, AASemantic.chipBlueText),
      ChipVariant.selected => (AAColors.marker, AAColors.ink),
      ChipVariant.plain => (const Color(0xFFFFFFFF), AAColors.ink),
    };
    return Container(
      padding: dense
          ? EdgeInsets.symmetric(horizontal: 8, vertical: 2)
          : EdgeInsets.symmetric(horizontal: hpad, vertical: vpad),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AAColors.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon,
                size: fontSize - 1,
                color: textColor ?? fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'ZCOOLKuaiLe',
              fontSize: fontSize,
              height: 1.2,
              color: textColor ?? fg,
            ),
          ),
        ],
      ),
    );
  }

  static ChipVariant _mapVariant(Color? color) {
    if (color == null) return ChipVariant.plain;
    if (color == AAColors.mint || color == AASemantic.chipGreenText) {
      return ChipVariant.green;
    }
    if (color == AAColors.coral || color == AASemantic.chipOrangeText) {
      return ChipVariant.orange;
    }
    if (color == AAColors.sky || color == AASemantic.chipBlueText) {
      return ChipVariant.blue;
    }
    if (color == AAColors.lemon || color == AAColors.marker) {
      return ChipVariant.selected;
    }
    return ChipVariant.plain;
  }
}

enum ChipVariant { plain, green, orange, blue, selected }
