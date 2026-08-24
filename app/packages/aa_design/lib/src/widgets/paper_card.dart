import 'dart:math';

import 'package:flutter/material.dart';
import '../shapes/sketchy_border.dart';
import '../tokens/aa_colors.dart';
import '../tokens/aa_tokens.dart';

/// 便签卡：手绘边框 + 实心涂鸦阴影 + 轻微旋转 + 可选纸胶带/图钉（UI规范 §7.1）
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.color = AAColors.cardWhite,
    this.padding = const EdgeInsets.all(16),
    this.withTape = false,
    this.tapeColor = AAColors.lemon,
    this.withPin = false,
    this.tiltSeed,
    this.borderSeed = 11,
    this.borderWidth = AATokens.stroke,
    this.onTap,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  /// 顶部纸胶带（半透明彩条 + 两端锯齿 + 旋转 ±3°）
  final bool withTape;
  final Color tapeColor;

  /// 左上角图钉
  final bool withPin;

  /// 轻微旋转种子（同名同转）；null = 不旋转
  final String? tiltSeed;

  /// 手绘边框种子（同形）
  final int borderSeed;
  final double borderWidth;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final angle = tiltSeed == null ? 0.0 : AATokens.tiltFor(tiltSeed!);
    Widget card = DecoratedBox(
      decoration: ShapeDecoration(
        color: color,
        shape: SketchyBorder(
          seed: borderSeed,
          side: BorderSide(color: AAColors.ink, width: borderWidth),
        ),
        shadows: const [
          BoxShadow(
            color: AAColors.ink,
            offset: AATokens.shadowOffset,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (withTape || withPin) {
      card = Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          if (withTape)
            Positioned(
              top: -11,
              left: 0,
              right: 0,
              child: Center(child: TapeDecorator(color: tapeColor)),
            ),
          if (withPin)
            const Positioned(
              top: -8,
              left: -6,
              child: PinDecorator(),
            ),
        ],
      );
    }

    Widget rotated = angle == 0
        ? card
        : Transform.rotate(angle: angle, child: card);

    if (onTap != null) {
      rotated = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: rotated,
      );
    }

    return Padding(padding: margin, child: rotated);
  }
}

/// 纸胶带（两端锯齿、旋转 ±3°）
class TapeDecorator extends StatelessWidget {
  const TapeDecorator({super.key, this.color = AAColors.lemon, this.width = 84, this.height = 22});

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -3 * pi / 180,
      child: CustomPaint(
        size: Size(width, height),
        painter: _TapePainter(color),
      ),
    );
  }
}

class _TapePainter extends CustomPainter {
  _TapePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final notch = h / 3.2;
    final path = Path()
      ..moveTo(0, notch)
      ..lineTo(notch, 0)
      ..lineTo(w - notch, 0)
      ..lineTo(w, notch)
      ..lineTo(w - notch, h)
      ..lineTo(notch, h)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.82));
  }

  @override
  bool shouldRepaint(covariant _TapePainter old) => old.color != color;
}

/// 左上角图钉
class PinDecorator extends StatelessWidget {
  const PinDecorator({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(16, 16),
      painter: _PinPainter(),
    );
  }
}

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = AAColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, 5.5, ink);
    canvas.drawLine(Offset(c.dx - 1.2, c.dy + 2), Offset(c.dx, size.height), ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
