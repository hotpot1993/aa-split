import 'package:flutter/material.dart';
import 'aa_colors.dart';

/// 设计令牌 —— 对应 UI规范 全局参数
abstract final class AATokens {
  // ---- 线宽 ----
  /// 涂鸦线条统一宽度（规范红线：2.5px）
  static const stroke = 2.5;

  /// 细线（分隔/装饰）1.5px
  static const strokeThin = 1.5;

  /// 粗线（印章/强调）4.0px
  static const strokeBold = 4.0;

  // ---- 阴影（实心偏移"涂鸦阴影"）----
  static const shadowOffset = Offset(3, 3);
  static const shadowPressOffset = Offset(1, 1);
  static const shadowColor = AAColors.ink;

  // ---- 圆角手抖基准（不规则圆角，正反变化制造手绘感）----
  static const squiggleRadius = BorderRadius.only(
    topLeft: Radius.circular(255),
    topRight: Radius.circular(15),
    bottomRight: Radius.circular(225),
    bottomLeft: Radius.circular(15),
  );

  // ---- 间距（4 的倍数）----
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space5 = 20.0;
  static const space6 = 24.0;
  static const space8 = 32.0;
  static const space10 = 40.0;

  // ---- 高度参考（规范 §10 P30：金额区占屏幕 1/3）----
  static const amountAreaRatio = 1 / 3;

  // ---- 卡片轻微旋转（3张以内不齐平才可爱）----
  static const cardTilt = 0.008; // rad ≈ 0.46°

  /// 基于固定种子的卡片轻微旋转（同名卡片同转同形）
  static double tiltFor(String seed) {
    final h = seed.hashCode.clamp(-1000, 1000) / 1000.0;
    return h * cardTilt * 2;
  }
}
