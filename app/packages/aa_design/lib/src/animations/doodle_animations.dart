import 'dart:math';

import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 通用弹性曲线（UI规范 §8.1：所有"落下/弹起"类动效必须用它）
const springCurve = Cubic(0.34, 1.56, 0.64, 1);

/// 手绘动效集（UI规范 §8.1 参数）
/// 原则：不均匀关键帧模拟逐帧手绘、飞行类必配虚线笔触轨迹、尊重系统减弱动态
abstract final class DoodleAnimations {
  /// 页面切换：像翻动速写本（轻微旋转 + 平移 + 淡入），300ms
  static Route<T> pageRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final turn = Tween<double>(begin: -0.021, end: 0).animate(animation);
        final slide =
            Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
                .animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: slide,
            child: Transform.rotate(angle: turn.value, child: child),
          ),
        );
      },
    );
  }
}

/// 对勾"画出来"（路径描边动画），600ms · ease-out
class CheckDraw extends StatefulWidget {
  const CheckDraw({super.key, this.color = AAColors.ink, this.size = 72, this.strokeWidth = 4});

  final Color color;
  final double size;
  final double strokeWidth;

  @override
  State<CheckDraw> createState() => _CheckDrawState();
}

class _CheckDrawState extends State<CheckDraw> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _CheckPainter(_t.value, widget.color, widget.strokeWidth),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.progress, this.color, this.strokeWidth);
  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.18, h * 0.52)
      ..lineTo(w * 0.42, h * 0.76)
      ..lineTo(w * 0.84, h * 0.26);
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.progress != progress;
}

/// 印章落下：scale 2.2→1 + rotate -24°→-8°，450ms · 弹性曲线
class StampDrop extends StatefulWidget {
  const StampDrop({super.key, required this.child});

  final Widget child;

  @override
  State<StampDrop> createState() => _StampDropState();
}

class _StampDropState extends State<StampDrop> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: springCurve);

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final scale = 2.2 - 1.2 * _t.value;
        final angle = (-24 + 16 * _t.value) * pi / 180;
        return Transform.rotate(
          angle: angle,
          child: Transform.scale(scale: scale, child: widget.child),
        );
      },
    );
  }
}

/// 纸飞机飞出：沿弧线飞离 + 虚线笔触轨迹边飞边描出，500ms
class PaperPlaneFly extends StatefulWidget {
  const PaperPlaneFly({super.key, this.onCompleted});

  final VoidCallback? onCompleted;

  @override
  State<PaperPlaneFly> createState() => _PaperPlaneFlyState();
}

class _PaperPlaneFlyState extends State<PaperPlaneFly> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() => widget.onCompleted?.call());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 120,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _PlanePainter(_c.value),
        ),
      ),
    );
  }
}

class _PlanePainter extends CustomPainter {
  _PlanePainter(this.t);
  final double t;

  // 起点右下 → 终点左上（弧线）
  Offset _pos(Size s) {
    final p = CurveTween(curve: Curves.easeOut).transform(t);
    final x = s.width * (0.9 - 0.7 * p);
    final y = s.height * (0.75 - 0.25 * sin(p * pi));
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = AAColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // 虚线轨迹（逐步描出）
    const steps = 24;
    final shown = (steps * t).floor();
    for (var i = 0; i < shown; i++) {
      final p0 = _posAt(size, i / steps);
      final p1 = _posAt(size, (i + 1) / steps);
      canvas.drawLine(p0, p1, ink);
    }

    // 纸飞机（旋转抖动"逐帧感"）
    final plane = _pos(size);
    canvas.save();
    canvas.translate(plane.dx, plane.dy);
    canvas.rotate(-pi / 4 - 0.15 * sin(t * pi * 6));
    final body = Path()
      ..moveTo(12, 0)
      ..lineTo(-10, 7)
      ..lineTo(-5, 0)
      ..lineTo(-10, -7)
      ..close();
    canvas.drawPath(body, ink);
    canvas.restore();
  }

  Offset _posAt(Size s, double tt) {
    final p = CurveTween(curve: Curves.easeOut).transform(tt);
    return Offset(s.width * (0.9 - 0.7 * p), s.height * (0.75 - 0.25 * sin(p * pi)));
  }

  @override
  bool shouldRepaint(covariant _PlanePainter old) => old.t != t;
}

/// 金币抛入罐：多枚金币旋转抛掷 + ✦星光，550ms/枚 · 交错 150-200ms
class CoinBurst extends StatefulWidget {
  const CoinBurst({
    super.key,
    this.count = 5,
    this.size = 160,
    this.onCompleted,
  });

  final int count;
  final double size;
  final VoidCallback? onCompleted;

  @override
  State<CoinBurst> createState() => _CoinBurstState();
}

class _CoinBurstState extends State<CoinBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: Duration(milliseconds: 550 + (widget.count - 1) * 175));

  @override
  void initState() {
    super.initState();
    _c.forward().whenComplete(() => widget.onCompleted?.call());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _CoinsPainter(_c.value, widget.count),
        ),
      ),
    );
  }
}

class _CoinsPainter extends CustomPainter {
  _CoinsPainter(this.t, this.count);
  final double t;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ink = Paint()
      ..color = AAColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final gold = Paint()
      ..color = AAColors.lemon
      ..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final local = (t - i * 0.32).clamp(0.0, 1.0);
      if (local <= 0 || local >= 1) continue;
      final drop = Curves.easeOut.transform(local);
      final x = w * 0.5 + sin(local * pi * i * 0.9) * w * 0.28;
      final y = h * (0.12 + 0.75 * drop);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(-2 * pi * local);
      canvas.drawCircle(Offset.zero, 7, gold);
      canvas.drawCircle(Offset.zero, 7, ink);
      canvas.drawLine(const Offset(-3, 0), const Offset(3, 0), ink);
      canvas.restore();
    }

    // ✦ 星光
    final sparkleT = t - 0.3;
    if (sparkleT > 0 && sparkleT < 1) {
      final a = (1 - sparkleT);
      final p = Paint()
        ..color = AAColors.berry.withValues(alpha: a)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      for (var k = 0; k < 3; k++) {
        final c = Offset(w * (0.3 + 0.2 * k), h * 0.18 + k * 4);
        canvas.drawLine(c - const Offset(4, 0), c + const Offset(4, 0), p);
        canvas.drawLine(c - const Offset(0, 4), c + const Offset(0, 4), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CoinsPainter old) => old.t != t;
}

/// 铃铛晃动：顶部为原点，晃动 2 次，600ms
class BellShake extends StatefulWidget {
  const BellShake({super.key, required this.child});

  final Widget child;

  @override
  State<BellShake> createState() => _BellShakeState();
}

class _BellShakeState extends State<BellShake> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 600));

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final v = _c.value;
        final angle = sin(v * pi * 4) * 0.22 * (1 - v * 0.5);
        return Transform.rotate(
          angle: angle,
          alignment: Alignment.topCenter,
          child: widget.child,
        );
      },
    );
  }
}
