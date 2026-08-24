import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 荧光笔划重点（UI规范 §5：background: linear-gradient(transparent 55%, #FFE8A3 55%)）
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
    return Text(
      text,
      style: (style ?? const TextStyle(fontSize: 14)).copyWith(
        backgroundColor: highlightAll
            ? markerColor.withValues(alpha: 0.75)
            : null,
      ),
    );
  }
}

/// 仅对子字符串高亮（如搜索结果命中词）
class HighlightPartText extends StatelessWidget {
  const HighlightPartText({
    super.key,
    required this.text,
    required this.parts,
    this.style,
  });

  final String text;
  final List<String> parts;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final s = style ?? const TextStyle(fontSize: 14, color: AAColors.ink);
    final base = s;
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
      spans.add(TextSpan(
        text: hit,
        style: base.copyWith(
          backgroundColor: AAColors.marker.withValues(alpha: 0.75),
        ),
      ));
      idx = next + hit!.length;
    }
    return Text.rich(TextSpan(style: base, children: spans));
  }
}
