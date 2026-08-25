import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 字体风格（设置页「字体风格」切换）
///
/// - [hand]     手绘风格：正文站酷快乐体 + 金额数字龙藏体，货币符号统一 JetBrains Mono（默认）
/// - [standard] 标准风格：金额 JetBrains Mono，其余文字 Noto Sans SC
enum AaFontStyle {
  hand(
    '手绘风格',
    '站酷快乐体正文 + 龙藏体金额数字；货币符号 ¥ 统一 JetBrains Mono，品牌字知音漫兴体',
  ),
  standard(
    '标准风格',
    '金额及货币符号使用 JetBrains Mono，其余文字使用 Noto Sans SC',
  );

  const AaFontStyle(this.label, this.description);

  /// 设置页展示名
  final String label;

  /// 设置页说明文案
  final String description;
}

/// 字体系统 —— 与 docs/AA分账App-UI设计规范.md §4 分级字体系统 + docs/ui-demo/index.html 一致：
/// 标题/导航（22-26px）= ZCOOL KuaiLe（站酷快乐体）；
/// 金额大字（36-44px）= Long Cang（龙藏体）；
/// 正文（14-16px 墨色）= ZCOOL KuaiLe；辅助小字（11-12px 淡墨）= 同正文；
/// 英文/数字点缀 = Caveat 手写体。
/// 随包内置（免网络加载，双端一致），均免费商用（OFL）。
///
/// 通过 [useStyle] 切换「手绘风格 / 标准风格」：
/// - 货币符号与正负号（¥ / + -，[currency]）**两种风格统一 JetBrains Mono**；
/// - 标准风格下，金额数字（[hand]）同样 → JetBrains Mono；
/// - 其余文字（[title]/[brand]/[accent]）→ Noto Sans SC。
abstract final class AAFonts {
  // ---------- 手绘风格家族（原始资产注册名） ----------

  /// App 标题 / 导航栏 / 正文：站酷快乐体
  static const String titleHand = 'ZCOOLKuaiLe';

  /// 金额大字数字（主角）：龙藏体手写
  static const String amountHand = 'LongCang';

  /// 品牌字（AA分账）：知音漫兴体
  static const String brandHand = 'ZhiMangXing';

  /// 英文/数字点缀：Caveat 手写体
  static const String accentHand = 'Caveat';

  // ---------- 标准风格家族 ----------

  /// 标准风格正文/标题：Noto Sans SC
  static const String bodyStandard = 'NotoSansSC';

  /// 金额数字 / 货币符号（两种风格统一）：JetBrains Mono
  static const String amountStandard = 'JetBrainsMono';

  /// 当前生效的字体风格（默认手绘风格）。
  /// 由 App 启动（main.dart 恢复持久化偏好）与设置页切换时经 [useStyle] 注入。
  static AaFontStyle currentStyle = AaFontStyle.hand;

  /// 设置当前生效的字体风格。
  static void useStyle(AaFontStyle style) {
    currentStyle = style;
  }

  /// App 标题 / 导航栏 / 正文：站酷快乐体（手绘）| Noto Sans SC（标准）
  static String get title =>
      currentStyle == AaFontStyle.standard ? bodyStandard : titleHand;

  /// 金额大字（数字；人民币符号见 [currency]）：龙藏体（手绘）| JetBrains Mono（标准）
  static String get hand =>
      currentStyle == AaFontStyle.standard ? amountStandard : amountHand;

  /// 品牌字（AA分账）：知音漫兴体（手绘）| Noto Sans SC（标准）
  static String get brand =>
      currentStyle == AaFontStyle.standard ? bodyStandard : brandHand;

  /// 货币符号与正负号（¥ / + -）：**两种风格统一 JetBrains Mono**（手绘/标准一致）
  static String get currency => amountStandard;

  /// 英文/数字点缀：Caveat（手绘）| Noto Sans SC（标准）
  static String get accent =>
      currentStyle == AaFontStyle.standard ? bodyStandard : accentHand;

  /// 正文/标题字号基准
  static const titleSize = 24.0;

  /// 金额大字字号（Demo .amount = 42px）
  static const amountSize = 42.0;

  /// 行高基准
  static const lineHeight = 1.5;
}

/// 构建全局 TextTheme（Demo 全站手写体；回退链 Kaiti/STKaiti/KaiTi）。
/// 字体家族经 [AAFonts.useStyle] 切换（见 [AaFontStyle]）。
TextTheme buildAaTextTheme(TextTheme base) {
  return base
      .copyWith(
        displayLarge: TextStyle(
          fontFamily: AAFonts.hand,
          fontSize: 44,
          color: AAColors.ink,
          height: 1.2,
        ),
        displayMedium: TextStyle(
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
