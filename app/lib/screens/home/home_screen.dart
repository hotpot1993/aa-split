import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/balance.dart';
import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../providers/data_providers.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P11 总览首页
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final bills = ref.watch(billsProvider);
    final groups = ref.watch(groupsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final name = user?.nickname ?? '朋友';

    final bal = personalBalance(bills, user?.id ?? 'me');
    final recent = bills.take(5).toList();

    return AaScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Header(name: name, themeMode: themeMode),
          const SizedBox(height: 16),
          _NetCard(
            balance: bal,
            onSettle: () => _goSettle(context, ref, groups, bills, user?.id ?? 'me'),
            onDetail: () => context.push('/bills'),
          ),
          const SizedBox(height: 20),
          SectionTitle('快捷入口'),
          _QuickActions(
            onAdd: () => context.push('/add'),
            onInvite: () => _goInvite(context, groups),
            onRemind: () => _goRemind(context, groups, bills, user?.id ?? 'me'),
          ),
          const SizedBox(height: 8),
          SectionTitle('最近账单', trailing: TextButton(
            onPressed: () => context.push('/bills'),
            child: const Text('查看更多 →',
                style: TextStyle(color: AAColors.sky, fontFamily: 'ZCOOLKuaiLe', fontSize: 13)),
          )),
          if (recent.isEmpty)
            EmptyState(
              title: '账本空空如也，记一笔吧！',
              compact: true,
              emotion: TuanTuanEmotion.sleepy,
              buttonLabel: '✏️ 记一笔',
              onButtonTap: () => context.push('/add'),
            )
          else
            ...recent.map((b) => _RecentRow(bill: b, onTap: () => context.push('/bills/${b.id}'))),
          const SizedBox(height: 8),
          Center(
            child: Text('— 下拉刷新 & 搜索 🔍 —',
                style: Theme.of(context).textTheme.bodySmall),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _goSettle(BuildContext context, WidgetRef ref, groups, List<Bill> bills, String myId) {
    // 找净额最大的未结清群组
    String? target;
    var maxAbs = 0;
    for (final g in groups) {
      final gb = bills.where((b) => b.groupId == g.id).toList();
      final b = personalBalance(gb, myId);
      if (gb.any((x) => !x.fullySettled) && b.netCents.abs() > maxAbs) {
        maxAbs = b.netCents.abs();
        target = g.id;
      }
    }
    if (target != null) {
      context.push('/groups/$target/settlement');
    } else {
      showAaToast(context, '都清账啦，两不相欠 🎉');
    }
  }

  void _goInvite(BuildContext context, groups) {
    if (groups.isEmpty) {
      context.push('/groups/create');
    } else {
      context.push('/groups/${groups.first.id}/invite');
    }
  }

  void _goRemind(BuildContext context, groups, List<Bill> bills, String myId) {
    String? target;
    for (final g in groups) {
      final hasUnpaid = bills.any((b) => b.groupId == g.id && b.hasUnpaid &&
          b.participants.any((p) => p.userId == myId && !p.paid));
      if (hasUnpaid) {
        target = g.id;
        break;
      }
    }
    if (target != null) {
      context.push('/groups/$target/remind');
    } else {
      showAaToast(context, '没有欠款要催，大家都超靠谱！');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.themeMode});
  final String name;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${Fmt.greeting()}，$name 👋',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('今天也把账算明白～', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        InkWell(
          onTap: () => context.push('/search'),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              border: Border.fromBorderSide(BorderSide(color: AAColors.ink, width: 2)),
            ),
            child: const Icon(Icons.search, color: AAColors.ink, size: 22),
          ),
        ),
      ],
    );
  }
}

class _NetCard extends StatelessWidget {
  const _NetCard({required this.balance, required this.onSettle, required this.onDetail});
  final PersonalBalance balance;
  final VoidCallback onSettle;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final net = balance.netCents;
    final color = net >= 0 ? AAColors.mint : AAColors.coral;
    final label = net >= 0 ? '你应收' : '你应付';
    return PaperCard(
      withTape: true,
      tapeColor: AAColors.lemon,
      tiltSeed: 'net-card',
      color: AAColors.paperDeep,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('我的净额', style: text.titleSmall),
              const SizedBox(height: 6),
              Text(
                '$label ',
                style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 13, color: AAColors.inkSoft),
              ),
              const SizedBox(height: 2),
              HandAmount(amountCents: net, color: color, size: 44),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Mini(label: '应收', cents: balance.receivableCents, color: AAColors.mint),
                  const SizedBox(width: 14),
                  _Mini(label: '应付', cents: balance.payableCents, color: AAColors.coral),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DoodleButton(
                      label: '去结算',
                      type: DoodleButtonType.secondary,
                      expand: true,
                      onPressed: onSettle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DoodleButton(label: '查看明细', expand: true, onPressed: onDetail),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: -6,
            bottom: -6,
            child: Transform.rotate(
              angle: 0.08,
              child: const TuanTuan(size: 90, emotion: TuanTuanEmotion.happy),
            ),
          ),
        ],
      ),
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.cents, required this.color});
  final String label;
  final int cents;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HandAmount(amountCents: cents, color: color, size: 20, showSign: true),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 11, color: AAColors.inkSoft)),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onAdd, required this.onInvite, required this.onRemind});
  final VoidCallback onAdd;
  final VoidCallback onInvite;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuickCircle(emoji: '✏️', label: '记一笔', color: AAColors.coral, onTap: onAdd),
        const SizedBox(width: 10),
        _QuickCircle(emoji: '👥', label: '邀请', color: AAColors.mint, onTap: onInvite),
        const SizedBox(width: 10),
        _QuickCircle(emoji: '📢', label: '催款', color: AAColors.berry, onTap: onRemind),
      ],
    );
  }
}

class _QuickCircle extends StatelessWidget {
  const _QuickCircle({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 13, color: AAColors.ink)),
          ],
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.bill, required this.onTap});
  final Bill bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final statusColor = bill.fullySettled ? AASemantic.settled : AAColors.coral;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            CategoryIcon(category: bill.category, size: 40),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bill.title, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    '${bill.groupName} · ${Fmt.relative(bill.billDate)} · ${SplitText.label(bill.splitType)}',
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
                if (!bill.fullySettled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AAColors.marker.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: HandAmount(
                      amountCents: -bill.amountCents,
                      color: statusColor,
                      size: 18,
                    ),
                  )
                else
                  HandAmount(amountCents: -bill.amountCents, color: statusColor, size: 18),
                Text(
                  bill.fullySettled ? '已结清' : '待结算',
                  style: TextStyle(
                    fontFamily: 'ZCOOLKuaiLe',
                    fontSize: 11,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
