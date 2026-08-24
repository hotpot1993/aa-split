import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 字体系统 —— UI规范 §4
/// 随包内置（免网络加载，双端一致）：ZCOOL KuaiLe（站酷快乐体）/ Long Cang（龙藏体），均免费商用（OFL）
abstract final class AAFonts {
  /// 标题/导航/强调：站酷快乐体
  static const title = 'ZCOOLKuaiLe';

  /// 金额大字（主角）：龙藏体手写
  static const hand = 'LongCang';

  /// 正文：系统默认（规范：正文尽量不用手写体，保证可读性）
  static const body = null;

  /// 应用标题/导航 字号区间
  static const titleSize = 24.0;

  /// 金额大字字号区间（36-44）
  static const amountSize = 40.0;
}

/// 构建全局 TextTheme
TextTheme buildAaTextTheme(TextTheme base) {
  return base
      .copyWith(
        displayLarge: const TextStyle(
          fontFamily: AAFonts.hand,
          fontSize: 44,
          color: AAColors.ink,
          height: 1.2,
        ),
        displayMedium: const TextStyle(
          fontFamily: AAFonts.hand,
          fontSize: 36,
          color: AAColors.ink,
          height: 1.25,
        ),
        headlineLarge: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 26,
          color: AAColors.ink,
          height: 1.4,
          letterSpacing: 0.5,
        ),
        headlineMedium: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 22,
          color: AAColors.ink,
          height: 1.4,
          letterSpacing: 0.5,
        ),
        headlineSmall: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 18,
          color: AAColors.ink,
          height: 1.45,
        ),
        titleLarge: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 18,
          color: AAColors.ink,
          height: 1.45,
        ),
        titleMedium: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 16,
          color: AAColors.ink,
          height: 1.5,
        ),
        titleSmall: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 14,
          color: AAColors.ink,
          height: 1.5,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: AAColors.ink,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: AAColors.ink,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: AAColors.inkSoft,
          height: 1.5,
        ),
        labelLarge: const TextStyle(
          fontSize: 15,
          color: AAColors.ink,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: const TextStyle(
          fontSize: 13,
          color: AAColors.inkSoft,
        ),
      )
      .apply(fontSizeFactor: 1, bodyColor: AAColors.ink);
}
