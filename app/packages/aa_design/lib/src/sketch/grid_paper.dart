import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 速写本点阵纸背景（UI规范 §5：点距 24px，5% 墨色）
class GridPaperPainter extends CustomPainter {
  const GridPaperPainter({this.spacing = 24, this.inkAlpha = 0.05});

  final double spacing;
  final double inkAlpha;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AAColors.ink.withValues(alpha: inkAlpha);
    for (double x = spacing / 2; x <= size.width; x += spacing) {
      for (double y = spacing / 2; y <= size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPaperPainter old) =>
      old.spacing != spacing || old.inkAlpha != inkAlpha;
}

/// 铺满的点阵纸 widget（放在页面根 Stack 底座）
/// 命名与 Flutter 自带 GridPaper 区分：SketchPaper
class SketchPaper extends StatelessWidget {
  const SketchPaper({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: const GridPaperPainter()),
        if (child != null) child!,
      ],
    );
  }
}
