import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../models/group.dart';
import '../../models/group_member.dart';
import '../../providers/data_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';

/// P23 群组详情页（核心页）
class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    Group? group;
    for (final g in groups) {
      if (g.id == groupId) {
        group = g;
        break;
      }
    }
    if (group == null) {
      return const AaScaffold(
        appBar: null,
        body: Center(child: EmptyState(title: '这个群组找不到啦')),
      );
    }
    final allBills = ref.watch(billsProvider).value ?? const <Bill>[];
    final bills = allBills.where((b) => b.groupId == groupId).toList();
    final members = (ref.watch(groupMembersProvider).value ?? const {})[groupId] ?? [];
    final me = ref.watch(currentUserProvider)?.id ?? 'me';

    final total = bills.fold<int>(0, (s, b) => s + b.amountCents);
    final perPerson = members.isEmpty ? 0 : total ~/ members.length;
    final allSettled = bills.isNotEmpty && bills.every((b) => b.fullySettled);
    final text = Theme.of(context).textTheme;

    return AaScaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            onPressed: () => context.push('/groups/$groupId/settings'),
            icon: const Icon(Icons.settings, size: 24, color: AAColors.ink),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 群总账卡
          PaperCard(
            withTape: true,
            tapeColor: AAColors.mint,
            tiltSeed: 'ledger-$groupId',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('群总账', style: text.titleSmall),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    HandAmount(amountCents: total, color: AAColors.ink, size: 34),
                    const Spacer(),
                    Text('人均 ${Fmt.yuan(perPerson)} / ${members.length}人',
                        style: text.bodySmall),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 96, // 手写体行高偏大；84 会溢出约 10px
                  child: members.isEmpty
                      ? const Center(child: Text('还没有成员'))
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: members.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (_, i) => _MemberNetCard(member: members[i]),
                        ),
                ),
                const SizedBox(height: 14),
                DoodleButton(
                  label: '✨ 一键智能结算',
                  expand: true,
                  onPressed: allSettled ? null : () => context.push('/groups/$groupId/settlement'),
                ),
                if (allSettled)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        StampBadge(text: '本群已清账'),
                        SizedBox(width: 6),
                        Text('✅ 两不相欠啦 🎉',
                            style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SectionTitle(
            '成员',
            trailing: TextButton(
              onPressed: () => context.push('/groups/$groupId/members'),
              child: const Text('管理成员 >',
                  style: TextStyle(color: AAColors.sky, fontFamily: 'ZCOOLKuaiLe', fontSize: 13)),
            ),
          ),
          SizedBox(
            height: 66, // 头像42 + 名称行高(手写体约16) + 间距2；54 会溢出约 11px
            child: members.isEmpty
                ? const SizedBox()
                : ListView(
                    scrollDirection: Axis.horizontal,
                    children: members
                        .map((m) => Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: Column(
                                children: [
                                  SketchAvatar(emoji: m.avatarUrl, size: 42, name: m.nickname),
                                  const SizedBox(height: 2),
                                  Text(m.nickname,
                                      style: const TextStyle(fontSize: 11, color: AAColors.ink)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
          ),
          SectionTitle('账单流水'),
          if (bills.isEmpty)
            EmptyState(
              title: '记第一笔账，开启AA之旅',
              compact: true,
              emotion: TuanTuanEmotion.sleepy,
              buttonLabel: '✏️ 记一笔',
              onButtonTap: () => context.push('/add'),
            )
          else
            ...bills.map((b) => _FlowRow(bill: b, me: me, onTap: () => context.push('/bills/${b.id}'))),
          const SizedBox(height: 12),
          DoodleButton(
            label: '＋ 记一笔',
            type: DoodleButtonType.secondary,
            expand: true,
            onPressed: () => context.push('/add'),
          ),
        ],
      ),
    );
  }
}

class _MemberNetCard extends StatelessWidget {
  const _MemberNetCard({required this.member});
  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final net = member.netBalanceCents;
    final color = net > 0
        ? AAColors.mint
        : (net < 0 ? AAColors.coral : AAColors.inkSoft);
    final label = net > 0
        ? '应收'
        : (net < 0 ? '应付' : '已平');
    return Container(
      width: 88,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(member.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 13, color: AAColors.ink)),
          const SizedBox(height: 4),
          if (net == 0)
            Text('已平', style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 14, color: AAColors.inkSoft))
          else
            FittedBox(
              child: HandAmount(amountCents: net, color: color, size: 20, showSign: true),
            ),
          Text(label, style: TextStyle(fontSize: 10, color: AAColors.inkSoft)),
        ],
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({required this.bill, required this.me, required this.onTap});
  final Bill bill;
  final String me;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
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
                    '${Fmt.dateShort(bill.billDate)} · ${SplitText.label(bill.splitType)} · ${bill.payerName}垫付',
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
                HandAmount(
                  amountCents: -bill.amountCents,
                  color: bill.fullySettled ? AASemantic.settled : AAColors.coral,
                  size: 18,
                ),
                if (bill.payerId == me)
                  const StampBadge(text: '我垫的', size: 46, rotate: -8, color: AAColors.sky),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
