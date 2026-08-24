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

/// P12 账单记录列表页
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

    return AaScaffold(
      appBar: AppBar(
        title: const Text('账单记录'),
        actions: [
          TextButton(
            onPressed: () => context.push('/stats'),
            child: const Text('统计',
                style: TextStyle(color: AAColors.sky, fontFamily: 'ZCOOLKuaiLe', fontSize: 15)),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterChips(selected: _filter, onChanged: (f) => setState(() => _filter = f)),
          Expanded(
            child: filtered.isEmpty
                ? EmptyState(
                    title: '还没有记录',
                    subtitle: '账本空空如也，记一笔吧！',
                    buttonLabel: '✏️ 记一笔',
                    onButtonTap: () => context.push('/add'),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      for (final m in months) ...[
                        _MonthTag(label: m),
                        for (final b in groups[m]!)
                          _BillRow(bill: b, onTap: () => context.push('/bills/${b.id}')),
                      ],
                    ],
                  ),
          ),
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
    (_Filter.all, '全部'),
    (_Filter.mine, '我付款的'),
    (_Filter.toMe, '摊给我的'),
    (_Filter.pending, '待结算'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: _items
            .map((it) => Expanded(
                  child: GestureDetector(
                    onTap: () => onChanged(it.$1),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected == it.$1
                            ? AAColors.lemon.withValues(alpha: 0.55)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: selected == it.$1 ? AAColors.coral : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        it.$2,
                        style: TextStyle(
                          fontFamily: 'ZCOOLKuaiLe',
                          fontSize: 13,
                          color: selected == it.$1 ? AAColors.coral : AAColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _MonthTag extends StatelessWidget {
  const _MonthTag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, size: 14, color: AAColors.inkSoft),
          const SizedBox(width: 6),
          Text('${label.split('-').last}月',
              style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 14, color: AAColors.inkSoft)),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: AAColors.inkSoft, height: 1)),
        ],
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
    final text = Theme.of(context).textTheme;
    final statusColor = bill.fullySettled
        ? AASemantic.settled
        : (bill.hasUnpaid ? AAColors.coral : AAColors.mint);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: (!bill.fullySettled)
              ? AAColors.berry.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            CategoryIcon(category: bill.category, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bill.title, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${bill.groupName} · ${Fmt.dateShort(bill.billDate)} · ${SplitText.label(bill.splitType)}',
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                HandAmount(amountCents: -bill.amountCents, color: statusColor, size: 18),
                Text(
                  bill.fullySettled ? '已结清' : '待结算',
                  style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 11, color: AAColors.inkSoft),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
