import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../providers/data_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';

/// P13 统计页 —— 对齐 docs/ui-demo/index.html
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  /// Demo 甜甜圈配色：珊瑚橙34% 柠檬18% 薄荷22% 天空14% 藕芋12%
  static const _demoPalette = [
    AAColors.coral,
    AAColors.lemon,
    AAColors.mint,
    AAColors.sky,
    AAColors.lilac,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = ref.watch(billsProvider).value ?? const <Bill>[];

    // 分类占比
    final catMap = <BillCategory, int>{};
    for (final b in bills) {
      catMap[b.category] = (catMap[b.category] ?? 0) + b.amountCents;
    }
    final totalCents = catMap.values.fold<int>(0, (s, e) => s + e);
    final entries = catMap.entries.toList();
    // 按金额排序 + Demo 配色（未覆盖分类循环使用）
    entries.sort((a, b) => b.value.compareTo(a.value));
    final sections = [
      for (var i = 0; i < entries.length; i++)
        CrayonDonutSection(
          Cat.label(entries[i].key),
          entries[i].value / 100,
          _demoPalette[i % _demoPalette.length],
        ),
    ];

    // 月度趋势（近 6 个月）—— 与演示数据同一时钟，统计口径跨时段一致
    final labels = <String>[];
    final values = <double>[];
    final now = Fmt.clock();
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      labels.add('${d.month}月');
      final total = bills
          .where((b) => b.billDate.year == d.year && b.billDate.month == d.month)
          .fold<int>(0, (s, b) => s + b.amountCents);
      values.add((total / 100).toDouble());
    }
    var hi = 0;
    for (var i = 1; i < values.length; i++) {
      if (values[i] > values[hi]) hi = i;
    }

    return AaScaffold(
      appBar: AaAppBar(
        title: '统计',
        headIcon: 'assets/icons/chart.png',
        iconImage: 'assets/icons/moon.png',
        backLabel: '‹ 返回',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              HandTag('本季', fontSize: 12),
              SizedBox(width: 8),
              HandTag('本年', fontSize: 12, selected: true),
            ],
          ),
          PaperCard(
            withTape: true,
            tapeColor: AATokens.tapeMint,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AaIconImage('assets/icons/calendar.png', size: 16),
                    SizedBox(width: 4),
                    Text('月度消费趋势',
                        style: TextStyle(
                            fontFamily: AAFonts.title, fontSize: 14, color: AAColors.ink)),
                  ],
                ),
                SizedBox(height: 4),
                CrayonBarChart(
                  labels: labels,
                  values: values,
                  highlightIndex: hi,
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          PaperCard(
            withTape: true,
            tapeColor: AATokens.tapeSky,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AaIconImage('assets/icons/donut.png', size: 16),
                    SizedBox(width: 4),
                    Text('分类占比（甜甜圈）',
                        style: TextStyle(
                            fontFamily: AAFonts.title, fontSize: 14, color: AAColors.ink)),
                  ],
                ),
                SizedBox(height: 10),
                if (sections.isEmpty)
                  SizedBox(height: 132)
                else
                  Row(
                    children: [
                      CrayonDonutChart(
                        sections: sections,
                        centerLabel: centerLabel(totalCents),
                      ),
                      SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < entries.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 1),
                                child: Row(
                                  children: [
                                    Text(
                                      '${Cat.emoji(entries[i].key)} ${Cat.label(entries[i].key)}',
                                      style: TextStyle(
                                          fontFamily: AAFonts.title,
                                          fontSize: 12,
                                          color: AAColors.ink,
                                          height: 2),
                                    ),
                                    Spacer(),
                                    Text(
                                      totalCents == 0
                                          ? '0%'
                                          : '${(entries[i].value / totalCents * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                          fontFamily: AAFonts.title,
                                          fontSize: 12,
                                          color: AAColors.ink,
                                          height: 2),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          SizedBox(height: 16),
          SectionTitle('我的大额账单', emojiImage: 'assets/icons/crown.png'),
          if (top5(bills).isEmpty)
            EmptyState(
              title: '还没有账单',
              tag: '统计',
              artImage: 'assets/icons/chart.png',
              compact: true,
            )
          else
            ...top5(bills).map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PaperCard(
                    onTap: null,
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CategoryIcon(category: b.category, size: 44),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontFamily: AAFonts.title,
                                      fontSize: 15,
                                      color: AAColors.ink)),
                              SizedBox(height: 2),
                              Text('${b.groupName} · ${Fmt.dateShort(b.billDate)}',
                                  style: TextStyle(
                                      fontFamily: AAFonts.title,
                                      fontSize: 12,
                                      color: AAColors.inkSoft)),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        HandAmount(amountCents: b.amountCents, size: 22, trimZero: true),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }

  static List<Bill> top5(List<Bill> bills) {
    final top = List.of(bills)..sort((a, b) => b.amountCents.compareTo(a.amountCents));
    return top.take(5).toList();
  }

  /// 中心金额（Demo：「¥3,420」）
  static String centerLabel(int totalCents) {
    final yuan = totalCents / 100;
    final s = totalCents % 100 == 0
        ? yuan.toStringAsFixed(0)
        : yuan.toStringAsFixed(2);
    return '¥${_thousands(s)}';
  }

  static String _thousands(String s) {
    final dot = s.indexOf('.');
    final intPart = dot < 0 ? s : s.substring(0, dot);
    final dec = dot < 0 ? '' : s.substring(dot);
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      buf.write(intPart[i]);
      final remain = intPart.length - i - 1;
      if (remain > 0 && remain % 3 == 0) buf.write(',');
    }
    return '$buf$dec';
  }
}
