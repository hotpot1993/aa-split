import 'dart:math';

import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 手绘蜡笔柱状图（UI规范 §7.6：蜡笔质感柱 + 顶部小⭐/❤，柱顶圆头）
class CrayonBarChart extends StatelessWidget {
  const CrayonBarChart({
    super.key,
    required this.labels,
    required this.values,
    this.barColors = const [AAColors.coral, AAColors.mint, AAColors.sky, AAColors.lilac, AAColors.lemon],
    this.height = 180,
    this.topDoodles = const ['⭐', '❤'],
  });

  final List<String> labels;
  final List<double> values;
  final List<Color> barColors;
  final double height;
  final List<String> topDoodles;

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 1.0 : values.reduce(max);
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 8, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        topDoodles[i % topDoodles.length],
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: maxV == 0 ? 4 : max(6, height * 0.72 * values[i] / maxV - 18),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: barColors[i % barColors.length],
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(10),
                          ),
                          border: Border.all(color: AAColors.ink, width: 1.5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        labels[i],
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'ZCOOLKuaiLe',
                          fontSize: 11,
                          color: AAColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 手绘"甜甜圈+巧克力豆"环形图（UI规范 §7.6）
class CrayonDonutChart extends StatelessWidget {
  const CrayonDonutChart({
    super.key,
    required this.sections,
    this.size = 160,
    this.centerLabel = '总计',
  });

  final List<CrayonDonutSection> sections;
  final double size;
  final String centerLabel;

  @override
  Widget build(BuildContext context) {
    final total = sections.fold<double>(0, (s, e) => s + e.value);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(sections, total),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerLabel,
                style: const TextStyle(
                  fontFamily: 'ZCOOLKuaiLe',
                  fontSize: 12,
                  color: AAColors.inkSoft,
                ),
              ),
              Text(
                total.toStringAsFixed(0),
                style: const TextStyle(
                  fontFamily: 'LongCang',
                  fontSize: 30,
                  color: AAColors.ink,
                ),
              ),
            ],
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
  _DonutPainter(this.sections, this.total);
  final List<CrayonDonutSection> sections;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final ring = radius * 0.42;
    final rect = Rect.fromCircle(center: center, radius: radius);
    var start = -pi / 2;
    final rnd = Random(99);
    for (final s in sections) {
      final sweep = total == 0 ? 0.0 : s.value / total * 2 * pi;
      if (sweep <= 0) continue;
      // 蜡笔质感：两遍描边，第二遍细线抖动偏移
      for (var pass = 0; pass < 2; pass++) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring * (pass == 0 ? 1 : 0.75)
          ..strokeCap = StrokeCap.round
          ..color = s.color.withValues(alpha: pass == 0 ? 1 : 0.85);
        final wobble = pass == 0 ? 0.0 : (rnd.nextDouble() * 2 - 1) * 1.5;
        canvas.drawArc(rect.deflate(wobble).inflate(pass == 0 ? 0 : -ring * 0.09),
            start, sweep, false, paint);
      }
      start += sweep;
    }
    // 巧克力豆（分隔点）
    var a = -pi / 2;
    for (final s in sections) {
      final sweep = total == 0 ? 0.0 : s.value / total * 2 * pi;
      if (sweep <= 0) continue;
      a += sweep;
      final p = Offset(
        center.dx + radius * cos(a),
        center.dy + radius * sin(a),
      );
      canvas.drawCircle(
          p, 4,
          Paint()
            ..color = AAColors.ink
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          p, 2.2,
          Paint()..color = AAColors.paperDeep);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.sections != sections || old.total != total;
}
