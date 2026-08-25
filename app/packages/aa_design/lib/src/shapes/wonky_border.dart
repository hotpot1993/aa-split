import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';
import '../tokens/aa_tokens.dart';

/// 「手抖不对称圆角」边框 —— 严格照搬 docs/ui-demo/index.html 的
/// border-radius 数值（如 .card `16px 6px 14px 7px/7px 14px 6px 16px`）。
///
/// 用 RRect 逐角椭圆圆角 + 2.5px 墨色描边复现 Demo 的手绘感。
class WonkyBorder extends ShapeBorder {
  const WonkyBorder({
    this.side = const BorderSide(color: AAColors.ink, width: AATokens.stroke),
    this.radius = AARadii.card,
  });

  final BorderSide side;
  final BorderRadius radius;

  RRect _rr(Rect rect) => RRect.fromRectAndCorners(
        rect,
        topLeft: radius.topLeft,
        topRight: radius.topRight,
        bottomRight: radius.bottomRight,
        bottomLeft: radius.bottomLeft,
      );

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rr(rect));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final d = side.width;
    return Path()..addRRect(_rr(rect.deflate(d)));
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
  ShapeBorder scale(double t) => WonkyBorder(side: side.scale(t), radius: radius);
}

/// 虚线“手抖不对称圆角”边框 —— Demo `.btn.ghost{border:2.5px dashed var(--ink)}`
class DashedWonkyBorder extends ShapeBorder {
  const DashedWonkyBorder({
    this.side = const BorderSide(color: AAColors.ink, width: AATokens.stroke),
    this.radius = AARadii.card,
    this.dash = 7,
    this.gap = 5,
  });

  final BorderSide side;
  final BorderRadius radius;
  final double dash;
  final double gap;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(RRect.fromRectAndCorners(
        rect,
        topLeft: radius.topLeft,
        topRight: radius.topRight,
        bottomRight: radius.bottomRight,
        bottomLeft: radius.bottomLeft,
      ));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = side.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in getOuterPath(rect).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + gap;
      }
    }
  }

  @override
  ShapeBorder scale(double t) => DashedWonkyBorder(
        side: side.scale(t),
        radius: radius,
        dash: dash * t,
        gap: gap * t,
      );
}

/// 便捷样式常量（对应 Demo 组件类）
abstract final class WonkyStyles {
  /// .card / .btn / .emptyc
  static const card = WonkyBorder(radius: AARadii.card);

  /// .opt
  static const opt = WonkyBorder(radius: AARadii.opt);

  /// .toast
  static const toast = WonkyBorder(radius: AARadii.toast);

  /// .qr
  static const qr = WonkyBorder(radius: AARadii.qr);

  /// .ghost 按钮虚线
  static const ghost = DashedWonkyBorder(radius: AARadii.card);
}
