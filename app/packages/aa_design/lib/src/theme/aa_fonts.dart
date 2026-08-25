import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 字体系统 —— 与 docs/AA分账App-UI设计规范.md §4 分级字体系统 + docs/ui-demo/index.html 一致：
/// 标题/导航（22-26px）= ZCOOL KuaiLe（站酷快乐体）；
/// 金额大字（36-44px）= Long Cang（龙藏体）；
/// 正文（14-16px 墨色）= ZCOOL KuaiLe；辅助小字（11-12px 淡墨）= 同正文；
/// 英文/数字点缀 = Caveat 手写体。
/// 随包内置（免网络加载，双端一致），均免费商用（OFL）。
abstract final class AAFonts {
  /// App 标题 / 导航栏 / 正文：站酷快乐体
  static const title = 'ZCOOLKuaiLe';

  /// 金额大字（主角）：龙藏体手写
  static const hand = 'LongCang';

  /// 品牌字（AA分账 / 记账页 ¥）：知音漫兴体
  static const brand = 'ZhiMangXing';

  /// 英文/数字点缀：Caveat 手写体
  static const accent = 'Caveat';

  /// 正文/标题字号基准
  static const titleSize = 24.0;

  /// 金额大字字号（Demo .amount = 42px）
  static const amountSize = 42.0;

  /// 行高基准
  static const lineHeight = 1.5;
}

/// 构建全局 TextTheme（Demo 全站手写体；回退链 Kaiti/STKaiti/KaiTi）
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
          height: AAFonts.lineHeight,
          letterSpacing: 0.5,
        ),
        headlineMedium: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 22,
          color: AAColors.ink,
          height: AAFonts.lineHeight,
          letterSpacing: 0.5,
        ),
        headlineSmall: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 18,
          color: AAColors.ink,
          height: AAFonts.lineHeight,
        ),
        titleLarge: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 18,
          color: AAColors.ink,
          height: AAFonts.lineHeight,
        ),
        titleMedium: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 16,
          color: AAColors.ink,
          height: AAFonts.lineHeight,
        ),
        titleSmall: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 14,
          color: AAColors.ink,
          height: AAFonts.lineHeight,
        ),
        bodyLarge: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 16,
          color: AAColors.ink,
          height: AAFonts.lineHeight,
        ),
        bodyMedium: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 14,
          color: AAColors.ink,
          height: AAFonts.lineHeight,
        ),
        bodySmall: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 12,
          color: AAColors.inkSoft,
          height: AAFonts.lineHeight,
        ),
        labelLarge: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 15,
          color: AAColors.ink,
          fontWeight: FontWeight.normal,
        ),
        labelMedium: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 13,
          color: AAColors.inkSoft,
        ),
      )
      .apply(
        fontSizeFactor: 1,
        bodyColor: AAColors.ink,
      );
}
