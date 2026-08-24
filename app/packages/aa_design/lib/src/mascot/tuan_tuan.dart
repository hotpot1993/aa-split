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
