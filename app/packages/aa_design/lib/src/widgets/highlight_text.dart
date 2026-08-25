import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 荧光笔划重点 —— 严格照搬 Demo `.hl`：
/// `background:linear-gradient(transparent 55%, var(--marker) 55%)`
/// 即：只在文字下 45% 高度画荧光条（贴住文字底部），而不是整盒背景。
class HighlightText extends StatelessWidget {
  const HighlightText(
    this.text, {
    super.key,
    this.style,
    this.highlightAll = true,
    this.markerColor = AAColors.marker,
  });

  /// 需要高亮的文本（整段都高亮）
  final String text;
  final TextStyle? style;
  final bool highlightAll;
  final Color markerColor;

  @override
  Widget build(BuildContext context) {
    final st = style ?? const TextStyle(fontSize: 14, color: AAColors.ink);
    final painter = TextPainter(
      text: TextSpan(text: text, style: st),
      textDirection: TextDirection.ltr,
    )..layout();
    final lineH = painter.preferredLineHeight;
    painter.dispose();
    final fh = st.fontSize ?? 14;

    return Stack(
      children: [
        if (highlightAll)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: lineH * 0.45 + fh * 0.12,
            child: ColoredBox(color: markerColor),
          ),
        Text(text, style: st),
      ],
    );
  }
}

/// 仅对子字符串高亮（如搜索结果命中词）—— 同样只划底部荧光条
class HighlightPartText extends StatelessWidget {
  const HighlightPartText(
    this.text, {
    super.key,
    required this.parts,
    this.style,
  });

  final String text;
  final List<String> parts;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? const TextStyle(fontSize: 14, color: AAColors.ink);
    final spans = <TextSpan>[];

    var idx = 0;
    while (idx < text.length) {
      int next = text.length;
      String? hit;
      for (final p in parts) {
        if (p.isEmpty) continue;
        final i = text.indexOf(p, idx);
        if (i >= 0 && i < next) {
          next = i;
          hit = p;
        }
      }
      if (next == text.length) {
        spans.add(TextSpan(text: text.substring(idx)));
        break;
      }
      if (next > idx) spans.add(TextSpan(text: text.substring(idx, next)));
      spans.add(TextSpan(text: hit));
      idx = next + hit!.length;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _HighlightUnderPainter(
              text: text,
              style: base,
              parts: parts,
            ),
          ),
        ),
        Text.rich(TextSpan(style: base, children: spans)),
      ],
    );
  }
}

/// 在匹配子串下方画荧光条（基于 TextPainter 计算出的字形包围盒）
class _HighlightUnderPainter extends CustomPainter {
  _HighlightUnderPainter({
    required this.text,
    required this.style,
    required this.parts,
  });

  final String text;
  final TextStyle style;
  final List<String> parts;

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final lineH = tp.preferredLineHeight;
    for (final p in parts) {
      if (p.isEmpty) continue;
      var from = 0;
      while (true) {
        final start = text.indexOf(p, from);
        if (start < 0) break;
        final end = start + p.length;
        final boxes = tp.getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: end),
        );
        for (final b in boxes) {
          canvas.drawRect(
            Rect.fromLTRB(
              b.left,
              b.top + lineH * 0.55,
              b.right,
              b.bottom,
            ),
            Paint()..color = AAColors.marker,
          );
        }
        from = end;
      }
    }
    tp.dispose();
  }

  @override
  bool shouldRepaint(covariant _HighlightUnderPainter old) =>
      old.text != text || old.parts != parts;
}
