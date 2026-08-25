import 'dart:math';

import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 吉祥物情绪
enum TuanTuanEmotion { happy, sleepy, excited, celebrate }

/// 吉祥物「团团」涂鸦小熊猫（UI规范 §2）
/// 简笔线条 + 平涂淡彩（≤4色）：墨线、白脸、粉腮红、柠檬黄道具。
/// 使用场景：空状态插画、净额卡陪伴、庆祝、引导提示。
class TuanTuan extends StatelessWidget {
  const TuanTuan({
    super.key,
    this.emotion = TuanTuanEmotion.happy,
    this.size = 120,
    this.withPencil = false,
  });

  final TuanTuanEmotion emotion;
  final double size;
  final bool withPencil;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TuanTuanPainter(emotion, withPencil)),
    );
  }
}

class _TuanTuanPainter extends CustomPainter {
  _TuanTuanPainter(this.emotion, this.withPencil);

  final TuanTuanEmotion emotion;
  final bool withPencil;

  final _w = 2.5;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120; // 以 120 为设计基准
    final ink = Paint()
      ..color = AAColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _w * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final blush = Paint()..color = AAColors.berry.withValues(alpha: 0.65);
    final lemon = Paint()
      ..color = AAColors.lemon.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    final rnd = Random(emotion.index * 31 + 7);

    // 头顶"财"字呆毛（招财）：一条弧线 + 字
    final antennaY = 14 * s;
    canvas.drawPath(
      Path()
        ..moveTo(60 * s, 30 * s)
        ..quadraticBezierTo(58 * s, 20 * s, 62 * s, 12 * s),
      ink,
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: '财',
        style: TextStyle(
          fontFamily: 'ZCOOLKuaiLe',
          fontSize: 12,
          color: AAColors.ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(56 * s, antennaY - 12 * s));

    // 耳朵
    canvas.drawArc(Rect.fromLTWH(22 * s, 26 * s, 20 * s, 22 * s), pi * 0.9, pi * 1.2, false, ink);
    canvas.drawArc(Rect.fromLTWH(78 * s, 26 * s, 20 * s, 22 * s), pi * 0.9, pi * 1.2, false, ink);

    // 头（大圆）
    canvas.drawCircle(Offset(60 * s, 58 * s), 30 * s, ink);

    // 眼睛（按情绪）
    final eyeL = Offset(49 * s, 56 * s);
    final eyeR = Offset(71 * s, 56 * s);
    final dot = Paint()..color = AAColors.ink;
    switch (emotion) {
      case TuanTuanEmotion.happy: // 弯眼
        canvas.drawArc(Rect.fromCenter(center: eyeL, width: 10 * s, height: 8 * s), pi, pi, false, ink);
        canvas.drawArc(Rect.fromCenter(center: eyeR, width: 10 * s, height: 8 * s), pi, pi, false, ink);
      case TuanTuanEmotion.sleepy: // 豆豆眼
        canvas.drawCircle(eyeL, 2.4 * s, dot);
        canvas.drawCircle(eyeR, 2.4 * s, dot);
      case TuanTuanEmotion.excited: // > <
        canvas.drawLine(Offset(44 * s, 56 * s), Offset(53 * s, 52 * s), ink);
        canvas.drawLine(Offset(44 * s, 56 * s), Offset(53 * s, 60 * s), ink);
        canvas.drawLine(Offset(76 * s, 56 * s), Offset(67 * s, 52 * s), ink);
        canvas.drawLine(Offset(76 * s, 56 * s), Offset(67 * s, 60 * s), ink);
      case TuanTuanEmotion.celebrate: // 弯眼 + 张嘴
        canvas.drawArc(Rect.fromCenter(center: eyeL, width: 10 * s, height: 8 * s), pi, pi, false, ink);
        canvas.drawArc(Rect.fromCenter(center: eyeR, width: 10 * s, height: 8 * s), pi, pi, false, ink);
        canvas.drawArc(Rect.fromCenter(center: Offset(60 * s, 62 * s), width: 10 * s, height: 8 * s), 0, pi, false, ink);
    }

    // 鼻嘴：小三角 + 弧线
    final mouth = Path()
      ..moveTo(60 * s, 60 * s)
      ..quadraticBezierTo(58 * s, 64 * s, 52 * s, 62.5 * s);
    canvas.drawPath(mouth, ink);
    canvas.drawLine(Offset(60 * s, 60 * s), Offset(60 * s, 66 * s), ink);

    // 腮红
    canvas.drawOval(Rect.fromLTWH(36 * s, 60 * s, 9 * s, 5 * s), blush);
    canvas.drawOval(Rect.fromLTWH(75 * s, 60 * s, 9 * s, 5 * s), blush);

    // 身体（小椭圆）
    canvas.drawArc(Rect.fromLTWH(40 * s, 80 * s, 40 * s, 34 * s), pi * 0.05, pi * 0.9, false, ink);

    // 手里的铅笔（记账本命）
    if (withPencil) {
      canvas.save();
      canvas.translate(60 * s, 76 * s);
      canvas.rotate(-pi / 5);
      final pencil = Paint()
        ..color = AAColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * s
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(-12 * s, 0), Offset(14 * s, 0), pencil);
      canvas.drawCircle(Offset(14 * s, 0), 1.8 * s, Paint()..color = AAColors.ink);
      canvas.restore();
    }

    // 情绪道具
    switch (emotion) {
      case TuanTuanEmotion.excited: // 蒸汽
        for (var i = 0; i < 3; i++) {
          final x = 42.0 + i * 18;
          final yy = 18.0 - i * 2;
          canvas.drawArc(Rect.fromLTWH(x * s, yy * s, 8 * s, 14 * s), pi * 0.8, pi * 1.4, false, ink);
        }
      case TuanTuanEmotion.celebrate: // 撒花
        for (var i = 0; i < 6; i++) {
          final x = rnd.nextDouble() * 118 + 1;
          final y = rnd.nextDouble() * 40 + 2;
          if (i % 3 == 0) {
            canvas.drawLine(Offset(x * s, y * s - 3 * s), Offset(x * s, y * s + 3 * s), lemon);
            canvas.drawLine(Offset(x * s - 3 * s, y * s), Offset(x * s + 3 * s, y * s), lemon);
          } else {
            canvas.drawCircle(Offset(x * s, y * s), 1.6 * s, Paint()..color = AAColors.berry);
          }
        }
      case TuanTuanEmotion.happy:
      case TuanTuanEmotion.sleepy:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _TuanTuanPainter old) =>
      old.emotion != emotion || old.withPencil != withPencil;
}

/// 团团熊猫 —— 严格照搬 docs/ui-demo/index.html 的吉祥物 SVG（viewBox 0 0 100 100）：
/// 墨线 3px 天线、墨色填充耳朵、白脸圆头、墨色眼圈、纸米眼点、粉腮红。
/// 可选 `.wob` 摇晃动画（±3° · 2.4s）。
class TuanTuanPanda extends StatefulWidget {
  const TuanTuanPanda({
    super.key,
    this.size = 110,
    this.wobble = false,
  });

  final double size;

  /// Demo `.wob`：0/100% -3°，50% 3°
  final bool wobble;

  @override
  State<TuanTuanPanda> createState() => _TuanTuanPandaState();
}

class _TuanTuanPandaState extends State<TuanTuanPanda>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.wobble) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: widget.wobble
          ? AnimatedBuilder(
              animation: _c!,
              builder: (context, _) {
                final t = _c!.value;
                // 0%,100% → -3deg；50% → 3deg
                final angle = -3 + 6 * (1 - (2 * t - 1).abs() / 1);
                return Transform.rotate(
                  angle: angle * pi / 180,
                  child: CustomPaint(painter: _PandaPainter()),
                );
              },
            )
          : CustomPaint(painter: _PandaPainter()),
    );
  }
}

class _PandaPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.scale(s);
    // 让线条宽度随缩放系数还原到 100 基准
    final ink3 = Paint()
      ..color = AAColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final inkFill = Paint()
      ..color = AAColors.ink
      ..style = PaintingStyle.fill;
    final ink25 = Paint()
      ..color = AAColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final white = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    final paper = Paint()
      ..color = AAColors.paper
      ..style = PaintingStyle.fill;
    final blush = Paint()
      ..color = AAColors.berry.withValues(alpha: 0.75)
      ..style = PaintingStyle.fill;

    // 天线 M50 15 Q52 6 57 4
    canvas.drawPath(
      Path()
        ..moveTo(50, 15)
        ..quadraticBezierTo(52, 6, 57, 4),
      ink3,
    );

    // 左耳 M31 26 Q21 9 37 11 Q36 19 31 26 Z
    final earL = Path()
      ..moveTo(31, 26)
      ..quadraticBezierTo(21, 9, 37, 11)
      ..quadraticBezierTo(36, 19, 31, 26)
      ..close();
    canvas.drawPath(earL, inkFill);
    canvas.drawPath(earL, ink25);

    // 右耳 M69 26 Q79 9 63 11 Q64 19 69 26 Z
    final earR = Path()
      ..moveTo(69, 26)
      ..quadraticBezierTo(79, 9, 63, 11)
      ..quadraticBezierTo(64, 19, 69, 26)
      ..close();
    canvas.drawPath(earR, inkFill);
    canvas.drawPath(earR, ink25);

    // 头圆 cx50 cy45 r26 白脸 + 3px 墨线
    canvas.drawCircle(const Offset(50, 45), 26, white);
    canvas.drawCircle(const Offset(50, 45), 26, ink3);

    // 眼圈 M35 41 Q40 33 47 40 Q46 48 40 49 Q35 47 35 41 Z
    final patchL = Path()
      ..moveTo(35, 41)
      ..quadraticBezierTo(40, 33, 47, 40)
      ..quadraticBezierTo(46, 48, 40, 49)
      ..quadraticBezierTo(35, 47, 35, 41)
      ..close();
    canvas.drawPath(patchL, inkFill);

    // 眼圈 M65 41 Q60 33 53 40 Q54 48 60 49 Q65 47 65 41 Z
    final patchR = Path()
      ..moveTo(65, 41)
      ..quadraticBezierTo(60, 33, 53, 40)
      ..quadraticBezierTo(54, 48, 60, 49)
      ..quadraticBezierTo(65, 47, 65, 41)
      ..close();
    canvas.drawPath(patchR, inkFill);

    // 眼珠 纸米小点
    canvas.drawCircle(const Offset(42, 43.5), 2.6, paper);
    canvas.drawCircle(const Offset(58, 43.5), 2.6, paper);

    // 嘴 M47 57 Q50 60 53 57
    canvas.drawPath(
      Path()
        ..moveTo(47, 57)
        ..quadraticBezierTo(50, 60, 53, 57),
      ink3,
    );

    // 腮红椭圆
    canvas.drawOval(const Rect.fromLTWH(28.5, 49.2, 9, 5.6), blush);
    canvas.drawOval(const Rect.fromLTWH(62.5, 49.2, 9, 5.6), blush);
  }

  @override
  bool shouldRepaint(covariant _PandaPainter old) => false;
}
