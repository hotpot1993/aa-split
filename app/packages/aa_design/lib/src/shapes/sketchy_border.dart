import 'dart:math';

import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';
import '../tokens/aa_tokens.dart';

/// 手绘"手抖"不规则圆角边框（UI规范 §5 手绘边框）
///
/// 每条边用两段二次贝塞尔（Q 曲线）绘制：中点沿法线偏移 bow，
/// 四角按 jitter 随机偏移，产生"纸面上画歪了"的手绘感。
///
/// **同 seed 同形**：传入相同 seed 时形状完全一致（卡牌/按钮全局统一），
/// 传不同 seed 则每个形状都"抖"得不一样。
class SketchyBorder extends ShapeBorder {
  const SketchyBorder({
    this.side = const BorderSide(color: AAColors.ink, width: AATokens.stroke),
    this.seed = 7,
    this.jitter = 2.5,
    this.bow = 3.5,
    this.stepVariance = false,
  });

  /// 边框线
  final BorderSide side;

  /// 手绘随机种子（固定 → 同形）
  final int seed;

  /// 四角随机偏移量（像素）
  final double jitter;

  /// 边线弯曲幅度（像素）
  final double bow;

  /// true：角落交错偏移更大（更"手抖"）
  final bool stepVariance;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _buildPath(Rect rect) {
    final r = Random(seed);
    final j = jitter * (stepVariance ? 1.6 : 1.0);

    double rnd(double amp) => (r.nextDouble() * 2 - 1) * amp;

    // 四角抖动
    final tl = Offset(rect.left + rnd(j), rect.top + rnd(j));
    final tr = Offset(rect.right + rnd(j), rect.top + rnd(j));
    final br = Offset(rect.right + rnd(j), rect.bottom + rnd(j));
    final bl = Offset(rect.left + rnd(j), rect.bottom + rnd(j));

    final path = Path()..moveTo(tl.dx, tl.dy);

    void edge(Offset a, Offset b) {
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      // 法线方向偏移
      final dx = a.dy - b.dy;
      final dy = b.dx - a.dx;
      final len = max(dx.abs() + dy.abs(), 0.001);
      final amp = rnd(bow);
      final ctrl = Offset(mid.dx + dx / len * amp, mid.dy + dy / len * amp);
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
    }

    edge(tl, tr);
    edge(tr, br);
    edge(br, bl);
    edge(bl, tl);
    path.close();
    return path;
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _buildPath(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final d = side.width;
    return _buildPath(rect.deflate(d));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = side.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(getOuterPath(rect), paint);
  }

  @override
  ShapeBorder scale(double t) => SketchyBorder(
        side: side.scale(t),
        seed: seed,
        jitter: jitter * t,
        bow: bow * t,
        stepVariance: stepVariance,
      );
}

/// 常见速写边框样式常量
abstract final class SketchyStyles {
  /// 墨线卡片
  static const card = SketchyBorder(
    side: BorderSide(color: AAColors.ink, width: AATokens.stroke),
    seed: 11,
  );

  /// 主按钮（珊瑚橙填充时描边）
  static const button = SketchyBorder(
    side: BorderSide(color: AAColors.ink, width: AATokens.stroke),
    seed: 23,
    bow: 4.5,
  );

  /// 输入框下划线风格用（细线）
  static const thin = SketchyBorder(
    side: BorderSide(color: AAColors.ink, width: AATokens.strokeThin),
    seed: 5,
    jitter: 1.5,
    bow: 2.0,
  );

  /// 印章（双圈粗线，由 StampBadge 自行绘制）
  static const stamp = SketchyBorder(
    side: BorderSide(color: AAColors.ink, width: AATokens.strokeBold),
    seed: 31,
    bow: 6,
  );
}
