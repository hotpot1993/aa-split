import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';
import 'aa_fonts.dart';

/// 主题 —— 同一套 token 换背景色（暗色模式）
ThemeData buildAaTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;

  // 暗色：暖夜墨纸感，色相不变、明度下调
  final background = isDark ? const Color(0xFF262019) : AAColors.paper;
  final surface = isDark ? const Color(0xFF342C24) : AAColors.cardWhite;
  final surfaceAlt = isDark ? const Color(0xFF3E352B) : AAColors.paperDeep;
  final ink = isDark ? const Color(0xFFEDE4D6) : AAColors.ink;
  final inkSoft = isDark ? const Color(0xFFA69784) : AAColors.inkSoft;

  final textTheme = buildAaTextTheme(ThemeData(brightness: brightness).textTheme)
      .apply(bodyColor: ink, displayColor: ink);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: AAColors.coral,
    onPrimary: Colors.white,
    secondary: AAColors.mint,
    onSecondary: ink,
    tertiary: AAColors.sky,
    onTertiary: ink,
    error: AAColors.berry,
    onError: AAColors.ink,
    surface: surface,
    onSurface: ink,
    surfaceContainerHighest: surfaceAlt,
    onSurfaceVariant: inkSoft,
    outline: inkSoft,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: ink, size: 26),
      titleTextStyle: textTheme.headlineMedium,
      foregroundColor: ink,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: textTheme.bodyMedium?.copyWith(color: inkSoft),
    ),
    dividerTheme: DividerThemeData(color: ink.withValues(alpha: 0.15)),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
  );
}

/// 默认浅色主题
final ThemeData aaTheme = buildAaTheme();
