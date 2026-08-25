import 'package:flutter/material.dart';
import '../shapes/wonky_border.dart';
import '../tokens/aa_colors.dart';
import '../tokens/aa_tokens.dart';

import '../theme/aa_fonts.dart';
/// 涂鸦按钮 —— 严格照搬 Demo `.btn`：
/// `font-size:15px;padding:10px 18px;border:2.5px solid var(--ink);
///  border-radius:16px 6px 14px 7px/7px 14px 6px 16px;background:#FFFDF6;color:var(--ink);
///  box-shadow:3px 3px 0 var(--ink)`
/// 按压：`translate(2.5px,2.5px)` + 阴影收缩为 `1px 1px 0`
///
/// 变体（Demo）：
/// `.primary{background:var(--coral);color:#fff}` `.danger{background:var(--pink);color:#fff}`
/// `.mini{padding:6px 12px;font-size:13px}` `.big{width:100%;padding:13px;font-size:18px}`
/// `.ghost{background:transparent;box-shadow:none;border:2.5px dashed var(--ink)}`
class DoodleButton extends StatefulWidget {
  const DoodleButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = DoodleButtonType.primary,
    this.icon,
    this.expand = false,
    this.mini = false,
    this.big = false,
    this.color,
    this.textColor,
    this.borderSeed,
    this.size = const Size(56, 14),
  });

  final String label;
  final VoidCallback? onPressed;
  final DoodleButtonType type;
  final IconData? icon;

  /// 拉伸到可用宽度（.btn.big width:100%；普通按钮 expand=true 时同样占满）
  final bool expand;

  /// 小号（.btn.mini：padding 6/12、13px）
  final bool mini;

  /// 大号（.btn.big：padding 13、18px、占满宽度）
  final bool big;

  /// 覆盖主色（primary / danger 时）
  final Color? color;
  final Color? textColor;
  final int? borderSeed;
  final Size size;

  @override
  State<DoodleButton> createState() => _DoodleButtonState();
}

enum DoodleButtonType { primary, secondary, ghost, danger, text }

class _DoodleButtonState extends State<DoodleButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _down(dynamic _) => setState(() => _pressed = _enabled);
  void _up(dynamic _) => setState(() => _pressed = false);

  double get _fontSize => widget.big ? 18 : (widget.mini ? 13 : 15);
  EdgeInsets get _padding => widget.big
      ? const EdgeInsets.all(13)
      : widget.mini
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
          : const EdgeInsets.symmetric(horizontal: 18, vertical: 10);

  @override
  Widget build(BuildContext context) {
    final Color textColor = widget.textColor ??
        (widget.type == DoodleButtonType.primary ||
                widget.type == DoodleButtonType.danger
            ? Colors.white
            : AAColors.ink);
    final Color fill = widget.type == DoodleButtonType.primary
        ? (widget.color ?? AAColors.coral)
        : widget.type == DoodleButtonType.danger
            ? (widget.color ?? AAColors.berry)
            : AAColors.cardWhite;
    final Color stroke = _enabled ? AAColors.ink : AAColors.inkSoft;

    Widget content;
    if (widget.type == DoodleButtonType.text) {
      content = Text(
        widget.label,
        style: TextStyle(
          fontFamily: AAFonts.title,
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
            Icon(widget.icon, size: _fontSize - 2, color: textColor),
            SizedBox(width: 6),
          ],
          Text(
            widget.label,
            style: TextStyle(
              fontFamily: AAFonts.title,
              fontSize: _fontSize,
              color: textColor,
              height: 1.3,
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
      child: SizedBox(
        width: widget.expand || widget.big ? double.infinity : null,
        child: Transform.translate(
          offset: _pressed ? Offset(2.5, 2.5) : Offset.zero,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: widget.type == DoodleButtonType.ghost
                  ? Colors.transparent
                  : (_enabled ? fill : fill.withValues(alpha: 0.5)),
              shape: widget.type == DoodleButtonType.ghost
                  ? DashedWonkyBorder()
                  : WonkyBorder(
                      side: BorderSide(color: stroke, width: AATokens.stroke),
                    ),
              shadows: widget.type == DoodleButtonType.ghost
                  ? []
                  : [
                      _pressed ? AATokens.buttonPressShadow : AATokens.buttonShadow,
                    ],
            ),
            child: Padding(padding: _padding, child: content),
          ),
        ),
      ),
    );
  }
}
