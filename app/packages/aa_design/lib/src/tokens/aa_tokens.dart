import 'package:flutter/material.dart';
import 'aa_colors.dart';

/// 演示库不规则圆角 —— 与 docs/ui-demo/index.html 逐条一致
///
/// Demo 以「四角不对称圆角」制造手绘感：
/// `.card/.btn/.emptyc` = 双值 `16px 6px 14px 7px/7px 14px 6px 16px`
/// `.opt` = `14px 5px 13px 6px`、`.toast` = `12px 5px 11px 6px`
/// `.qr` = `10px 4px 12px 5px`、`.bar` = `8px 3px 6px 4px/4px 6px 3px 8px`
/// `.cbx` = `7px 3px 8px 3px`
abstract final class AARadii {
  // .card / .btn / .emptyc：双值圆角
  static const card = BorderRadius.only(
    topLeft: Radius.elliptical(16, 7),
    topRight: Radius.elliptical(6, 14),
    bottomRight: Radius.elliptical(14, 6),
    bottomLeft: Radius.elliptical(7, 16),
  );

  // .opt：14px 5px 13px 6px
  static const opt = BorderRadius.only(
    topLeft: Radius.circular(14),
    topRight: Radius.circular(5),
    bottomRight: Radius.circular(13),
    bottomLeft: Radius.circular(6),
  );

  // .toast：12px 5px 11px 6px
  static const toast = BorderRadius.only(
    topLeft: Radius.circular(12),
    topRight: Radius.circular(5),
    bottomRight: Radius.circular(11),
    bottomLeft: Radius.circular(6),
  );

  // .qr：10px 4px 12px 5px
  static const qr = BorderRadius.only(
    topLeft: Radius.circular(10),
    topRight: Radius.circular(4),
    bottomRight: Radius.circular(12),
    bottomLeft: Radius.circular(5),
  );

  // .bar：8px 3px 6px 4px/4px 6px 3px 8px（双值）
  static const bar = BorderRadius.only(
    topLeft: Radius.elliptical(8, 4),
    topRight: Radius.elliptical(3, 6),
    bottomRight: Radius.elliptical(6, 3),
    bottomLeft: Radius.elliptical(4, 8),
  );

  // .cbx：7px 3px 8px 3px
  static const cbx = BorderRadius.only(
    topLeft: Radius.circular(7),
    topRight: Radius.circular(3),
    bottomRight: Radius.circular(8),
    bottomLeft: Radius.circular(3),
  );

  // 手机屏幕内页 .mstage：12px 5px 11px 6px
  static const stage = toast;
}

/// 设计令牌 —— 对应 docs/ui-demo/index.html 的样式数值
abstract final class AATokens {
  // ---- 线宽 ----
  /// 涂鸦线条统一宽度（Demo 红线：2.5px）
  static const stroke = 2.5;

  /// 细线（分隔/装饰）1.5px
  static const strokeThin = 1.5;

  /// 粗线（印章/强调）4.0px
  static const strokeBold = 4.0;

  // ---- 阴影（实心偏移"涂鸦阴影"）----
  /// 卡片阴影：`.card{box-shadow:3px 3px 0 rgba(68,58,50,.18)}`
  static const cardShadow = BoxShadow(
    color: Color(0x2E443A32), // rgba(68,58,50,.18)
    offset: Offset(3, 3),
  );

  /// 空状态卡片阴影：`.emptyc{box-shadow:3px 3px 0 rgba(68,58,50,.15)}`
  static const emptyShadow = BoxShadow(
    color: Color(0x26443A32), // rgba(68,58,50,.15)
    offset: Offset(3, 3),
  );

  /// 快捷入口圆阴影：`3px 3px 0 rgba(68,58,50,.2)`
  static const quickShadow = BoxShadow(
    color: Color(0x33443A32), // rgba(68,58,50,.2)
    offset: Offset(3, 3),
  );

  /// 拍立得阴影：`3px 3px 0 rgba(68,58,50,.2)`
  static const polaroidShadow = quickShadow;

  /// 选择项阴影：`3px 3px 0 rgba(68,58,50,.15)`
  static const optShadow = emptyShadow;

  /// 按钮阴影：`3px 3px 0 var(--ink)`（实心墨色）
  static const buttonShadow = BoxShadow(
    color: AAColors.ink,
    offset: Offset(3, 3),
  );

  /// 按钮按压阴影：`1px 1px 0 var(--ink)`
  static const buttonPressShadow = BoxShadow(
    color: AAColors.ink,
    offset: Offset(1, 1),
  );

  // ---- 纸胶带（.tape）----
  static const tapeWidth = 92.0;
  static const tapeHeight = 24.0;
  static const tapeBorderColor = Color(0x4D443A32); // rgba(68,58,50,.3)
  static const tapeLemon = Color(0xD9FFD166); // rgba(255,209,102,.85)
  static const tapeMint = Color(0xCC8FCE9F); // rgba(143,206,159,.8)
  static const tapeSky = Color(0xCC7EC4E8); // rgba(126,196,232,.8)
  static const tapePink = Color(0xCCF49CB4); // rgba(244,156,180,.8)

  // ---- 网格点纸（.screen 背景）----
  static const dotSpacing = 22.0; // 22px 22px
  static const dotRadius = 1.0; // radial-gradient 1px
  static const dotAlpha = 0.05; // rgba(68,58,50,.05)

  // ---- 卡片轻微旋转（Demo .card.tilt -0.4deg）----
  static const cardTilt = 0.008; // rad ≈ 0.46°

  /// 基于固定种子的卡片轻微旋转（同名卡片同转同形）
  static double tiltFor(String seed) {
    final h = seed.hashCode.clamp(-1000, 1000) / 1000.0;
    return h * cardTilt * 2;
  }
}
