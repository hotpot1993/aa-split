import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

import '../theme/aa_fonts.dart';
/// "填空题"输入框：只有一条手抖下划线，聚焦时变珊瑚橙（UI规范 §7.3）
class HandTextField extends StatefulWidget {
  const HandTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.onChanged,
    this.keyboardType,
    this.textAlign,
    this.openLabel,
    this.inlineUnderline = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.obscure = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextAlign? textAlign;

  /// 左侧小标签（如"标题"）
  final String? openLabel;
  final bool inlineUnderline;
  final bool autofocus;
  final int maxLines;

  /// 密码掩码（•••）
  final bool obscure;

  @override
  State<HandTextField> createState() => _HandTextFieldState();
}

class _HandTextFieldState extends State<HandTextField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final ink = AAColors.ink;
    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscure,
          textAlign: widget.textAlign ?? TextAlign.start,
          maxLines: widget.maxLines,
          style: TextStyle(
            fontFamily: AAFonts.title,
            fontSize: widget.maxLines > 1 ? 15 : 17,
            color: AAColors.ink,
            height: 1.4,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontFamily: AAFonts.title,
              fontSize: widget.maxLines > 1 ? 15 : 17,
              color: AAColors.inkSoft.withValues(alpha: 0.7),
            ),
            isDense: true,
            border: InputBorder.none,
            focusedBorder: InputBorder.none,
            enabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.only(bottom: 4),
            filled: false,
          ),
          onTap: () => setState(() => _focused = true),
          onTapOutside: (_) => setState(() => _focused = false),
        ),
        CustomPaint(
          size: Size(double.infinity, 4),
          painter: _UnderlinePainter(
            color: _focused ? AAColors.coral : ink,
            wild: _focused,
          ),
        ),
      ],
    );

    if (widget.openLabel != null) {
      return Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              widget.openLabel!,
              style: TextStyle(
                fontFamily: AAFonts.title,
                fontSize: 15,
                color: AAColors.inkSoft,
              ),
            ),
          ),
          Expanded(child: field),
        ],
      );
    }
    return field;
  }
}

/// 手抖下划线：两条轻微弯曲二次贝塞尔
class _UnderlinePainter extends CustomPainter {
  _UnderlinePainter({required this.color, required this.wild});

  final Color color;
  final bool wild;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = wild ? 2.5 : 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..quadraticBezierTo(
          size.width * 0.25, size.height / 2 + (wild ? 2.2 : 1.4), size.width * 0.5, size.height / 2)
      ..quadraticBezierTo(
          size.width * 0.75, size.height / 2 - (wild ? 2.2 : 1.4), size.width, size.height / 2);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _UnderlinePainter old) =>
      old.color != color || old.wild != wild;
}
