import 'package:flutter/material.dart';

/// 基础色板 —— UI规范 §3.1
abstract final class AAColors {
  /// 纸张米（全局背景）
  static const paper = Color(0xFFFBF3E4);

  /// 深纸米（卡片垫底/浅色块）
  static const paperDeep = Color(0xFFF4E8D3);

  /// 墨色（线条/文字/图标）
  static const ink = Color(0xFF443A32);

  /// 淡墨（次要文字）
  static const inkSoft = Color(0xFF8A7A68);

  /// 纸胶带柠檬
  static const lemon = Color(0xFFFFD166);

  /// 珊瑚橙（主色）
  static const coral = Color(0xFFFF8C69);

  /// 薄荷绿（应收/成功/已付）
  static const mint = Color(0xFF8FCE9F);

  /// 天空蓝（信息/链接）
  static const sky = Color(0xFF7EC4E8);

  /// 藕芋紫（装饰）
  static const lilac = Color(0xFFB79CE0);

  /// 草莓粉（腮红/心形/催款）
  static const berry = Color(0xFFF49CB4);

  /// 荧光笔黄（划重点）
  static const marker = Color(0xFFFFE8A3);

  /// 白色（卡片纸面/拍立得框）
  static const cardWhite = Color(0xFFFFFDF8);
}

/// 语义色 —— UI规范 §3.2
abstract final class AASemantic {
  /// 应收（别人欠我）→ 薄荷绿
  static const receivable = AAColors.mint;

  /// 应付（我欠别人）→ 珊瑚橙
  static const payable = AAColors.coral;

  /// 已结清 → 淡墨 60%
  static const settled = Color(0x998A7A68);

  /// 警告/催款 → 草莓粉
  static const warn = AAColors.berry;
}
