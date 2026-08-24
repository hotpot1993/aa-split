import 'dart:math';

import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 双线圆圈印章（✅已结清 / 📢已催2次），默认旋转 -8°（UI规范 §7.4）
class StampBadge extends StatelessWidget {
  const StampBadge({
    super.key,
    required this.text,
    this.color = AASemantic.settled,
    this.rotate = -8,
    this.size = 56,
  });

  final String text;
  final Color color;

  /// 旋转角度（度）
  final double rotate;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate * pi / 180,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _StampPainter(color),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(size * 0.18),
              child: FittedBox(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'ZCOOLKuaiLe',
                    fontSize: size * 0.26,
                    height: 1.3,
                    color: color,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StampPainter extends CustomPainter {
  _StampPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = min(size.width, size.height) / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final rnd = Random(31);
    final wobble = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    // 外圈（轻微手抖）
    final outer = Path();
    const steps = 26;
    for (var i = 0; i <= steps; i++) {
      final a = i / steps * 2 * pi - pi / 2;
      final jitter = 1.0 + (rnd.nextDouble() - 0.5) * 0.05;
      final p = Offset(c.dx + r * jitter * cos(a), c.dy + r * jitter * sin(a));
      if (i == 0) {
        outer.moveTo(p.dx, p.dy);
      } else {
        outer.lineTo(p.dx, p.dy);
      }
    }
    outer.close();
    canvas.drawPath(outer, wobble);
    canvas.drawCircle(c, r - 2.5, wobble);
  }

  @override
  bool shouldRepaint(covariant _StampPainter old) => old.color != color;
}
