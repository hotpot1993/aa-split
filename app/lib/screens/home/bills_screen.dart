import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../providers/data_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';

enum _Filter { all, mine, toMe, pending }

/// P12 账单记录列表页 —— 对齐 docs/ui-demo/index.html
class BillsScreen extends ConsumerStatefulWidget {
  const BillsScreen({super.key});
  @override
  ConsumerState<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends ConsumerState<BillsScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider)?.id ?? 'me';
    final all = ref.watch(billsProvider).value ?? const <Bill>[];
    final filtered = all.where((b) {
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.mine:
          return b.payerId == me;
        case _Filter.toMe:
          return b.participants.any((p) => p.userId == me && !p.exempt);
        case _Filter.pending:
          return !b.fullySettled;
      }
    }).toList();

    // 按月分组
    final groups = <String, List<Bill>>{};
    for (final b in filtered) {
      final key = '${b.billDate.year}-${b.billDate.month.toString().padLeft(2, '0')}';
      groups.putIfAbsent(key, () => []).add(b);
    }
    final months = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final monthEmoji = [
      'assets/icons/sun.png',
      'assets/icons/flower.png',
      'assets/icons/coin.png',
    ];

    return AaScaffold(
      appBar: AaAppBar(
        title: '全部账单',
        headIcon: 'assets/icons/notebook.png',
        iconImage: 'assets/icons/chart.png',
        onIconTap: () => context.push('/stats'),
      ),
      body: filtered.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _FilterChips(selected: _filter, onChanged: (f) => setState(() => _filter = f)),
                SizedBox(height: 12),
                EmptyState(
                  title: '账本空空如也，记一笔吧！',
                  subtitle: '30秒搞定，以后回头翻账可开心了',
                  tag: 'P11/P12 账单列表',
                  artImage: 'assets/icons/notebook.png',
                  buttonLabel: '记一笔',
                  buttonImage: 'assets/icons/edit.png',
                  onButtonTap: () => context.push('/add'),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _FilterChips(selected: _filter, onChanged: (f) => setState(() => _filter = f)),
                for (var i = 0; i < months.length; i++) ...[
                  SectionTitle(
                    '${int.parse(months[i].split('-').last)}月',
                    emojiImage: monthEmoji[i % monthEmoji.length],
                  ),
                  for (final b in groups[months[i]]!)
                    _BillRow(bill: b, onTap: () => context.push('/bills/${b.id}')),
                ],
                SizedBox(height: 16),
              ],
            ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});
  final _Filter selected;
  final ValueChanged<_Filter> onChanged;

  static const _items = [
    (_Filter.all, '全部', ChipVariant.selected),
    (_Filter.mine, '我付款的', ChipVariant.plain),
    (_Filter.toMe, '摊给我的', ChipVariant.plain),
    (_Filter.pending, '待结算', ChipVariant.orange),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: _items
            .map((it) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => onChanged(it.$1),
                    child: HandTag(
                      it.$2,
                      selected: selected == it.$1,
                      fontSize: 12,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.bill, required this.onTap});
  final Bill bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CategoryIcon(category: bill.category, size: 44),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bill.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                SizedBox(height: 2),
                Text(
                  '${bill.groupName} · ${Fmt.dateShort(bill.billDate)}',
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          HandAmount(amountCents: bill.amountCents, size: 22, trimZero: true),
          SizedBox(width: 10),
          StampBadge(
            text: bill.fullySettled ? '已结清' : '待结算',
            color: bill.fullySettled ? AASemantic.stampDone : AASemantic.stampMoney,
          ),
        ],
      ),
    );
  }
}
