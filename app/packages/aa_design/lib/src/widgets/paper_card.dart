import 'dart:math';

import 'package:flutter/material.dart';
import '../shapes/wonky_border.dart';
import '../tokens/aa_colors.dart';
import '../tokens/aa_tokens.dart';

/// 便签卡 —— 严格照搬 Demo `.card`：
/// `background:#FFFDF6; border:2.5px solid var(--ink);
///  border-radius:16px 6px 14px 7px/7px 14px 6px 16px;
///  padding:16px 14px; box-shadow:3px 3px 0 rgba(68,58,50,.18)`
/// 可选：顶部纸胶带（.tape）、轻微旋转（.card.tilt）、按压下沉（.card.tap:active）
class PaperCard extends StatefulWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.color = AAColors.cardWhite,
    this.padding = const EdgeInsets.fromLTRB(14, 16, 14, 16),
    this.withTape = false,
    this.tapeColor = AATokens.tapeLemon,
    this.withPin = false,
    this.tiltSeed,
    this.borderSeed = 11,
    this.borderWidth = AATokens.stroke,
    this.borderColor = AAColors.ink,
    this.onTap,
    this.onLongPress,
    this.margin = EdgeInsets.zero,
    this.pressable = true,
    this.shadow = AATokens.cardShadow,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  /// 顶部纸胶带（Demo `.tape`：92x24、旋转 -3°、1.5px 描边圆角 2px）
  final bool withTape;
  final Color tapeColor;

  /// 左上角图钉
  final bool withPin;

  /// 轻微旋转种子（同名同转）；null = 不旋转
  final String? tiltSeed;

  /// 手绘边框种子（保留参数，圆角由 AARadii 决定）
  final int borderSeed;
  final double borderWidth;

  /// 边框颜色（Demo 粉卡 border-color:var(--pink)）
  final Color borderColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry margin;

  /// onTap 时是否启用按下下沉效果（.card.tap:active translate(2px,2px)）
  final bool pressable;

  /// 卡片阴影（.card = rgba(68,58,50,.18) 3,3；.emptyc = .15）
  final BoxShadow shadow;

  @override
  State<PaperCard> createState() => _PaperCardState();
}

class _PaperCardState extends State<PaperCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final angle = widget.tiltSeed == null ? 0.0 : AATokens.tiltFor(widget.tiltSeed!);
    final offset = (_pressed && widget.pressable) ? const Offset(2, 2) : Offset.zero;

    Widget card = DecoratedBox(
      decoration: ShapeDecoration(
        color: widget.color,
        shape: WonkyBorder(
          side: BorderSide(color: widget.borderColor, width: widget.borderWidth),
        ),
        shadows: [widget.shadow],
      ),
      child: Padding(padding: widget.padding, child: widget.child),
    );

    if (widget.withTape || widget.withPin) {
      card = Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          if (widget.withTape)
            Positioned(
              top: -12,
              left: 0,
              right: 0,
              child: Center(child: TapeDecorator(color: widget.tapeColor)),
            ),
          if (widget.withPin)
            const Positioned(
              top: -8,
              left: -6,
              child: PinDecorator(),
            ),
        ],
      );
    }

    if (offset != Offset.zero || angle != 0) {
      card = Transform.translate(
        offset: offset,
        child: Transform.rotate(angle: angle, child: card),
      );
    }

    if (widget.onTap != null || widget.onLongPress != null) {
      card = GestureDetector(
        onTapDown: widget.pressable ? (_) => setState(() => _pressed = true) : null,
        onTapUp: widget.pressable ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: widget.pressable ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }

    return Padding(padding: widget.margin, child: card);
  }
}

/// 纸胶带 —— Demo `.tape`：`width:92px;height:24px;rotate(-3deg);
/// background:rgba(255,209,102,.85);border:1.5px solid rgba(68,58,50,.3);border-radius:2px`
class TapeDecorator extends StatelessWidget {
  const TapeDecorator({
    super.key,
    this.color = AATokens.tapeLemon,
    this.width = AATokens.tapeWidth,
    this.height = AATokens.tapeHeight,
  });

  final Color color;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -3 * pi / 180,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
          border: Border.all(
            color: AATokens.tapeBorderColor,
            width: 1.5,
          ),
        ),
      ),
    );
  }
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
