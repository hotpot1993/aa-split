import 'dart:math';

import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';
import '../tokens/aa_tokens.dart';

import '../theme/aa_fonts.dart';
/// 手绘蜡笔柱状图 —— 严格照搬 Demo P13 `.bars`：
/// `.bar{border:2.5px solid var(--ink);border-radius:8px 3px 6px 4px/4px 6px 3px 8px;
///  background:repeating-linear-gradient(0deg,rgba(68,58,50,.10) 0 4px,transparent 4px 9px), var(--paper2)}`
/// `.bar i{top:-24px;font-size:14px}`（顶部 emoji） `.bar em{top:4px;font-size:11px}`（柱内数值）
class CrayonBarChart extends StatelessWidget {
  const CrayonBarChart({
    super.key,
    required this.labels,
    required this.values,
    this.barColors = const [AAColors.coral, AAColors.mint, AAColors.sky, AAColors.lilac, AAColors.lemon],
    this.height = 150,
    this.topDoodles = const ['💛', '⭐'],
    this.highlightIndex,
  });

  final List<String> labels;
  final List<double> values;
  final List<Color> barColors;

  /// 图表总高（Demo .bars height:130px + 顶部 emoji 24px）
  final double height;
  final List<String> topDoodles;

  /// 高亮柱子（Demo 6月：#FFE8C2 底色）
  final int? highlightIndex;

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 1.0 : values.reduce(max);
    // 柱体可用高度：总高 - 顶部 emoji(约17) - 底部标签(约22)
    final barMax = max(30.0, height - 46);
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      topDoodles[i % topDoodles.length],
                      style: TextStyle(fontSize: 14, height: 1.2),
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          height: maxV == 0
                              ? 6
                              : max(10.0, barMax * values[i] / maxV),
                          decoration: BoxDecoration(
                            color: i == highlightIndex
                                ? Color(0xFFFFE8C2)
                                : AAColors.paperDeep,
                            border: Border.all(color: AAColors.ink, width: 2.5),
                            borderRadius: AARadii.bar,
                          ),
                          child: CustomPaint(painter: _StripePainter()),
                        ),
                        Positioned(
                          top: 2,
                          left: 0,
                          right: 0,
                          child: Text(
                            values[i].toStringAsFixed(0),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                              fontSize: 11,
                              color: AAColors.ink,
                            ),
                          ),
                        ),
                        // 数值文字下的细墨色分隔线（.bar 条纹顶部）
                        Positioned(
                          top: 15,
                          left: 4,
                          right: 4,
                          child: Container(height: 1.5, color: AAColors.ink.withValues(alpha: 0.18)),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      labels[i],
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AAFonts.title,
                        fontSize: 12,
                        color: AAColors.inkSoft,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 横向条纹（repeating-linear-gradient(0deg, rgba(68,58,50,.10) 0 4px, transparent 4px 9px)）
class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AAColors.ink.withValues(alpha: 0.10);
    for (double y = 4; y < size.height; y += 9) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 4), p);
    }
  }

  @override
  bool shouldRepaint(covariant _StripePainter old) => false;
}

/// 手绘"甜甜圈" —— 严格照搬 Demo P13：
/// 外圈 132px 圆（border:2.5px 墨线）+ conic-gradient 五色扇区 +
/// 内圈 inset 27% 纸米圆（border:2.5px 墨线）+ 中心 12px 文字。
class CrayonDonutChart extends StatelessWidget {
  const CrayonDonutChart({
    super.key,
    required this.sections,
    this.size = 132,
    this.centerLabel = '总计',
  });

  final List<CrayonDonutSection> sections;
  final double size;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(sections),
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.46,
            heightFactor: 0.46,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AAColors.paper,
                shape: BoxShape.circle,
                border: Border.all(color: AAColors.ink, width: 2.5),
              ),
              child: FittedBox(
                child: Text(
                  centerLabel,
                  style: TextStyle(
                    fontFamily: AAFonts.title,
                    fontSize: 12,
                    color: AAColors.ink,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CrayonDonutSection {
  const CrayonDonutSection(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.sections);
  final List<CrayonDonutSection> sections;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.25;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final total = sections.fold<double>(0, (s, e) => s + e.value);
    var start = -pi / 2; // conic-gradient 默认从顶部（0deg）开始
    for (final s in sections) {
      final sweep = total == 0 ? 0.0 : s.value / total * 2 * pi;
      if (sweep <= 0) continue;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = s.color);
      start += sweep;
    }
    // 外圈墨线
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AAColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.sections != sections;
}
