import 'package:flutter/material.dart';
import '../shapes/sketchy_border.dart';
import '../tokens/aa_colors.dart';
import '../tokens/aa_tokens.dart';

/// 涂鸦按钮（UI规范 §7.2）
/// primary：珊瑚橙填充 + 墨线手绘边框 + 3,3,0 涂鸦阴影，按压下沉 2px 影子缩小
/// secondary：纸底白 + 墨线边框
/// text：手绘文字按钮（可带下划线/星星点缀）
class DoodleButton extends StatefulWidget {
  const DoodleButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = DoodleButtonType.primary,
    this.icon,
    this.expand = false,
    this.color,
    this.textColor,
    this.borderSeed,
    this.size = const Size(56, 14),
  });

  final String label;
  final VoidCallback? onPressed;
  final DoodleButtonType type;
  final IconData? icon;

  /// 拉伸到可用宽度
  final bool expand;

  /// 覆盖主色（primary 时）
  final Color? color;
  final Color? textColor;
  final int? borderSeed;
  final Size size;

  @override
  State<DoodleButton> createState() => _DoodleButtonState();
}

enum DoodleButtonType { primary, secondary, text }

class _DoodleButtonState extends State<DoodleButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _down(dynamic _) => setState(() => _pressed = _enabled);
  void _up(dynamic _) => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final Color textColor = widget.textColor ??
        (widget.type == DoodleButtonType.primary
            ? Colors.white
            : AAColors.ink);
    final Color fill = widget.type == DoodleButtonType.primary
        ? (widget.color ?? AAColors.coral)
        : AAColors.cardWhite;
    final Color ink = _enabled ? AAColors.ink : AAColors.inkSoft;

    Widget content;
    if (widget.type == DoodleButtonType.text) {
      content = Text(
        widget.label,
        style: TextStyle(
          fontFamily: 'ZCOOLKuaiLe',
          fontSize: 15,
          color: _enabled ? AAColors.sky : AAColors.inkSoft,
          decoration: TextDecoration.underline,
          decorationColor: AAColors.sky,
          decorationThickness: 2,
        ),
      );
    } else {
      content = Row(
        mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontFamily: 'ZCOOLKuaiLe',
              fontSize: 16,
              color: textColor,
              height: 1.1,
            ),
          ),
        ],
      );
    }

    if (widget.type == DoodleButtonType.text) {
      return GestureDetector(
        onTapDown: _down,
        onTapUp: _up,
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: Transform.translate(
          offset: Offset(0, _pressed ? 1 : 0),
          child: content,
        ),
      );
    }

    return GestureDetector(
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: Transform.translate(
        offset: Offset(0, _pressed ? 2 : 0),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: _enabled ? fill : fill.withValues(alpha: 0.5),
            shape: SketchyBorder(
              side: BorderSide(color: ink, width: AATokens.stroke),
              seed: widget.borderSeed ?? 23,
              bow: 4.5,
            ),
            shadows: [
              BoxShadow(
                color: ink,
                offset: _pressed ? AATokens.shadowPressOffset : AATokens.shadowOffset,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.expand ? 0 : 22,
              vertical: 12,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
