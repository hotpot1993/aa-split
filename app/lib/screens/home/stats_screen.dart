import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../providers/data_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';

/// P13 统计页
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(billsProvider);
    final text = Theme.of(context).textTheme;

    // 分类占比
    final catMap = <BillCategory, int>{};
    for (final b in bills) {
      catMap[b.category] = (catMap[b.category] ?? 0) + b.amountCents;
    }
    final totalCents = catMap.values.fold<int>(0, (s, e) => s + e);
    final sections = catMap.entries.map((e) {
      return CrayonDonutSection(Cat.label(e.key), (e.value / 100).toDouble(), _catColor(e.key));
    }).toList();

    // 月度趋势（近 6 个月）
    final labels = <String>[];
    final values = <double>[];
    final now = DateTime.now();
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      labels.add('${d.month}月');
      final total = bills
          .where((b) => b.billDate.year == d.year && b.billDate.month == d.month)
          .fold<int>(0, (s, b) => s + b.amountCents);
      values.add((total / 100).toDouble());
    }

    // 排行：前 5 笔大额
    final top = List.of(bills)..sort((a, b) => b.amountCents.compareTo(a.amountCents));
    final top5 = top.take(5).toList();

    return AaScaffold(
      appBar: AppBar(title: const Text('统计')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionTitle('月度趋势'),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: CrayonBarChart(labels: labels, values: values),
          ),
          const SizedBox(height: 16),
          SectionTitle('分类占比'),
          PaperCard(
            child: Row(
              children: [
                if (sections.isNotEmpty)
                  CrayonDonutChart(sections: sections, centerLabel: '共${bills.length}笔')
                else
                  const Spacer(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sections
                        .map((s) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Container(width: 12, height: 12, color: s.color, child: const SizedBox()),
                                  const SizedBox(width: 6),
                                  Text(s.label, style: text.bodySmall),
                                  const Spacer(),
                                  Text(
                                    totalCents == 0
                                        ? '0%'
                                        : '${(s.value / (totalCents / 100) * 100).toStringAsFixed(0)}%',
                                    style: text.bodySmall,
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle('我的大额账单 TOP5'),
          if (top5.isEmpty)
            const EmptyState(title: '还没有账单', compact: true)
          else
            ...top5.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CategoryIcon(category: b.category, size: 34),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.title, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text('${b.groupName} · ${Fmt.dateShort(b.billDate)}', style: text.bodySmall),
                          ],
                        ),
                      ),
                      HandAmount(amountCents: b.amountCents, color: AAColors.ink, size: 18),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Color _catColor(BillCategory c) => switch (c) {
        BillCategory.food => AAColors.coral,
        BillCategory.traffic => AAColors.sky,
        BillCategory.hotel => AAColors.lilac,
        BillCategory.shopping => AAColors.lemon,
        BillCategory.fun => AAColors.berry,
        BillCategory.other => AAColors.mint,
      };
}
