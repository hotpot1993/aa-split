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

/// P23 群组详情页 —— 对齐 docs/ui-demo/index.html
class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});
  final String groupId;

  static const _tints = [
    Color(0xFFFFF1EA),
    Color(0xFFEDF7EE),
    Color(0xFFF0F6FB),
    Color(0xFFF7F0FB),
    Color(0xFFF4E8D3),
  ];

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

    final total = bills.fold<int>(0, (s, b) => s + b.amountCents);
    final perPerson = members.isEmpty ? 0 : total ~/ members.length;
    final allSettled = bills.isNotEmpty && bills.every((b) => b.fullySettled);

    return AaScaffold(
      appBar: AaAppBar(
        title: '',
        backLabel: '‹ ${group.name}',
        iconImage: 'assets/icons/settings.png',
        onIconTap: () => context.push('/groups/$groupId/settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 群总账卡（.card.tilt + .tape）
          PaperCard(
            withTape: true,
            tapeColor: AATokens.tapeLemon,
            tiltSeed: 'ledger-$groupId',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AaIconImage('assets/icons/coin.png', size: 16),
                    const SizedBox(width: 6),
                    const Text('群总账',
                        style: TextStyle(
                            fontFamily: 'ZCOOLKuaiLe', fontSize: 13, color: AAColors.inkSoft)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    HandAmount(amountCents: total, color: AAColors.ink, size: 34),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('人均 ${Fmt.yuan(perPerson, trimZero: true)} / ${members.length}人',
                          style: const TextStyle(
                              fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in members) ...[
                      HandTag(
                        _netLabel(m),
                        fontSize: 12,
                        variant: _netVariant(m),
                      ),
                      const SizedBox(width: 1),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                DoodleButton(
                  label: '✨ 一键智能结算',
                  big: true,
                  onPressed: allSettled ? null : () => context.push('/groups/$groupId/settlement'),
                ),
              ],
            ),
          ),
          SectionTitle('成员', emoji: '🐾'),
          // 成员头像行（52px 淡彩底）
          Row(
            children: [
              if (members.isEmpty)
                const Text('还没有成员',
                    style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft))
              else ...[
                for (var i = 0; i < members.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SketchAvatar(
                      emoji: members[i].avatarUrl,
                      size: 52,
                      name: members[i].nickname,
                      background: _tints[i % _tints.length],
                    ),
                  ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => context.push('/groups/$groupId/members'),
                  child: const Text('管理成员→',
                      style: TextStyle(
                          fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
                ),
              ],
            ],
          ),
          SectionTitle('账单流水', emoji: '🧾'),
          if (bills.isEmpty)
            EmptyState(
              title: '记第一笔账，开启AA之旅',
              subtitle: '30秒搞定，以后回头翻账可开心了',
              tag: 'P23 群组详情',
              artImage: 'assets/icons/edit.png',
              buttonLabel: '✏️ 记一笔',
              onButtonTap: () => context.push('/add'),
            )
          else if (allSettled)
            EmptyState(
              title: '本群已清账！两不相欠啦 🎉',
              subtitle: '团团撒花中——钱的事清了，咱们还是好朋友',
              tag: 'P23/P25 已清账 🎉',
              artImage: 'assets/icons/party.png',
              buttonLabel: '再来一笔 💪',
              onButtonTap: () => context.push('/add'),
            )
          else
            ...bills.map((b) => _FlowRow(bill: b, onTap: () => context.push('/bills/${b.id}'))),
          const SizedBox(height: 4),
          DoodleButton(
            label: '✏️ + 记一笔',
            big: true,
            type: DoodleButtonType.secondary,
            onPressed: () => context.push('/add'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _netLabel(GroupMember m) {
    final net = m.netBalanceCents;
    if (net == 0) return '${m.nickname} · 已平 0';
    final sign = net > 0 ? '+' : '-';
    return '${m.nickname} $sign${(net.abs() / 100).toStringAsFixed(0)}';
  }

  static ChipVariant _netVariant(GroupMember m) {
    final net = m.netBalanceCents;
    if (net > 0) return ChipVariant.green;
    if (net < 0) return ChipVariant.orange;
    return ChipVariant.blue;
  }
}

/// 流水行 —— Demo `.card.tap`：`[avatar][日期+标题 / ¥xx · 均摊][印章]`
class _FlowRow extends StatelessWidget {
  const _FlowRow({required this.bill, required this.onTap});
  final Bill bill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final perPerson = bill.participants.isEmpty
        ? 0
        : bill.amountCents ~/ bill.participants.length;
    final splitPart = bill.splitType == SplitType.even
        ? '均摊${Fmt.yuan(perPerson, trimZero: true)}/人'
        : SplitText.label(bill.splitType);
    return PaperCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CategoryIcon(category: bill.category, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${Fmt.dateShort(bill.billDate)} ${bill.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
                const SizedBox(height: 2),
                Text(
                  '${Fmt.yuan(bill.amountCents, trimZero: true)} · $splitPart',
                  style: const TextStyle(
                      fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StampBadge(
            text: bill.fullySettled ? '已结清' : '待结算',
            color: bill.fullySettled ? AASemantic.stampDone : AASemantic.stampMoney,
          ),
        ],
      ),
    );
  }
}
