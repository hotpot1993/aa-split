import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/balance.dart';
import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../models/group.dart';
import '../../providers/data_providers.dart';
import '../../providers/refresh_provider.dart';
import '../../providers/repositories.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P11 总览首页 —— 对齐 docs/ui-demo/index.html
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final bills = ref.watch(billsProvider).value ?? const <Bill>[];
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final name = user?.nickname ?? '朋友';

    final bal = personalBalance(bills, user?.id ?? 'me');
    final recent = bills.take(5).toList();

    return AaScaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Header(name: name),
          SizedBox(height: 12),
          _NetCard(
            balance: bal,
            onSettle: () => _goSettle(context, ref, groups, bills, user?.id ?? 'me'),
            onDetail: () => context.push('/bills'),
          ),
          SectionTitle('快捷入口', emoji: '🔜'),
          _QuickActions(
            onAdd: () => context.push('/add'),
            onInvite: () => _goInvite(context, groups),
            onRemind: () => _goRemind(context, groups, bills, user?.id ?? 'me'),
          ),
          SectionTitle('最近账单', emoji: '🍃'),
          if (recent.isEmpty)
            EmptyState(
              title: '账本空空如也，记一笔吧！',
              tag: 'P11/P12 账单列表',
              artImage: 'assets/icons/notebook.png',
              buttonLabel: '✏️ 记一笔',
              onButtonTap: () => context.push('/add'),
            )
          else
            ...recent.map((b) => _RecentRow(
                  bill: b,
                  onTap: () => context.push('/bills/${b.id}'),
                  onLongPress: () => _onLongPressBill(context, ref, b, groups),
                )),
          SizedBox(height: 4),
          InkWell(
            onTap: () => context.push('/bills'),
            child: Center(
              child: Text('— 查看更多账单 →',
                  style: TextStyle(fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
            ),
          ),
          SizedBox(height: 16),
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

  /// 邀请朋友：无群 → 创建群；一个群 → 直达；多个群 → 弹层选群
  Future<void> _goInvite(BuildContext context, List<Group> groups) async {
    if (groups.isEmpty) {
      context.push('/groups/create');
      return;
    }
    if (groups.length == 1) {
      context.push('/groups/${groups.first.id}/invite');
      return;
    }
    final picked = await showAaSheet<Group>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('邀请哪个群组的小伙伴？',
              style: Theme.of(context).textTheme.headlineSmall),
          SizedBox(height: 8),
          for (final g in groups)
            _InviteGroupRow(
              group: g,
              onTap: () => Navigator.of(context).pop(g),
            ),
          SizedBox(height: 8),
        ],
      ),
    );
    if (picked != null && context.mounted) {
      context.push('/groups/${picked.id}/invite');
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

  /// 群主长按首页最近账单 → 确认弹窗 → 删除（与群组详情一致；
  /// 非群主仅提示，不弹删除确认）
  Future<void> _onLongPressBill(
      BuildContext context, WidgetRef ref, Bill bill, List<Group> groups) async {
    final me = ref.read(currentUserProvider)?.id;
    Group? group;
    for (final g in groups) {
      if (g.id == bill.groupId) {
        group = g;
        break;
      }
    }
    if (me == null || group == null || group.ownerId != me) {
      showAaToast(context, '只有群主才能删除账单哦');
      return;
    }
    final ok = await showAaConfirm(
      context,
      title: '要删除这笔账单吗？',
      subtitle: '「${bill.title}」删除后从流水里消失，撤销不了了哦',
      confirmLabel: '删除',
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(billRepositoryProvider).delete(bill.id);
      ref.read(refreshProvider.notifier).bump();
      if (context.mounted) showAaToast(context, '账单已删除');
    } catch (e) {
      if (context.mounted) showAaToast(context, '删除失败：$e');
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            '${Fmt.greeting()}，$name 👋',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: AAFonts.title,
              fontSize: 22,
              color: AAColors.ink,
              height: 1.2,
            ),
          ),
        ),
        InkWell(
          onTap: () => context.push('/search'),
          child: AaIconImage('assets/icons/search.png', size: 24),
        ),
      ],
    );
  }
}

/// 净额卡 —— Demo `.card.tilt`：白纸底 + 胶带 + `我的净额` + 金额 + 双胶囊 + 双按钮 + 团团
class _NetCard extends StatelessWidget {
  const _NetCard({required this.balance, required this.onSettle, required this.onDetail});
  final PersonalBalance balance;
  final VoidCallback onSettle;
  final VoidCallback onDetail;

  @override
  Widget build(BuildContext context) {
    final net = balance.netCents;
    final color = net >= 0 ? AASemantic.amountPos : AASemantic.amountNeg;
    return PaperCard(
      withTape: true,
      tapeColor: AATokens.tapeLemon,
      tiltSeed: 'net-card',
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '我的净额',
                style: TextStyle(fontFamily: AAFonts.title, fontSize: 13, color: AAColors.inkSoft),
              ),
              SizedBox(height: 4),
              HandAmount(amountCents: net, color: color, size: 42),
              SizedBox(height: 6),
              Row(
                children: [
                  HandTag('应收 +¥${(balance.receivableCents / 100).toStringAsFixed(2)}',
                      variant: ChipVariant.green, fontSize: 12),
                  SizedBox(width: 8),
                  HandTag('应付 -¥${(balance.payableCents / 100).toStringAsFixed(2)}',
                      variant: ChipVariant.orange, fontSize: 12),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  DoodleButton(
                    label: '去结算',
                    type: DoodleButtonType.primary,
                    mini: true,
                    onPressed: onSettle,
                  ),
                  SizedBox(width: 8),
                  DoodleButton(label: '查看明细', mini: true, onPressed: onDetail),
                ],
              ),
            ],
          ),
          Positioned(
            right: 6,
            bottom: 2,
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: TuanTuanPanda(size: 64),
            ),
          ),
        ],
      ),
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
        _QuickCircle(
          emoji: '',
          image: 'assets/icons/edit.png',
          label: '记一笔',
          radii: [50, 46, 52, 48],
          onTap: onAdd,
        ),
        SizedBox(width: 10),
        _QuickCircle(
          emoji: '',
          image: 'assets/icons/group.png',
          label: '邀请朋友',
          radii: [48, 52, 46, 54],
          onTap: onInvite,
        ),
        SizedBox(width: 10),
        _QuickCircle(
          emoji: '',
          image: 'assets/icons/broadcast.png',
          label: '催款',
          radii: [52, 48, 54, 46],
          onTap: onRemind,
        ),
      ],
    );
  }
}

/// 快捷入口圆 —— Demo：56x56 白底、2.5px 墨线、不对称圆角、3px 阴影、emoji 24px、标签 mini
class _QuickCircle extends StatelessWidget {
  const _QuickCircle({
    required this.emoji,
    required this.radii,
    required this.onTap,
    this.image,
    this.label = '',
  });
  final String emoji;
  final String? image;
  final String label;
  final List<double> radii;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const d = 56.0;
    BorderRadius r(List<double> radii) => BorderRadius.only(
          topLeft: Radius.elliptical(d / 2 * radii[0] / 50, d / 2 * radii[0] / 50),
          topRight: Radius.elliptical(d / 2 * radii[1] / 50, d / 2 * radii[1] / 50),
          bottomRight: Radius.elliptical(d / 2 * radii[2] / 50, d / 2 * radii[2] / 50),
          bottomLeft: Radius.elliptical(d / 2 * radii[3] / 50, d / 2 * radii[3] / 50),
        );
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: d,
              height: d,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AAColors.cardWhite,
                shape: BoxShape.rectangle,
                borderRadius: r(radii),
                border: Border.all(color: AAColors.ink, width: 2.5),
                boxShadow: [AATokens.quickShadow],
              ),
              child: image != null
                  ? AaIconImage(image!, size: 30)
                  : Text(emoji, style: TextStyle(fontSize: 24)),
            ),
            SizedBox(height: 5),
            Text(label,
                style: TextStyle(
                    fontFamily: AAFonts.title, fontSize: 12, color: AAColors.ink)),
          ],
        ),
      ),
    );
  }
}

/// 邀请页群组选择行（首页「邀请朋友」多群时弹层）
class _InviteGroupRow extends StatelessWidget {
  const _InviteGroupRow({required this.group, required this.onTap});
  final Group group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: SketchAvatar(emoji: group.avatar, size: 42),
      title: Text(group.name,
          style: TextStyle(
              fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
      subtitle: Text('${group.memberCount}个小伙伴',
          style: TextStyle(
              fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
      trailing: Text('→', style: TextStyle(fontSize: 15, color: AAColors.inkSoft)),
      onTap: onTap,
    );
  }
}

/// 最近账单行 —— Demo `.card.tap`：`padding:12px`，`[ava 44][标题+副行][金额 24px][印章]`
class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.bill, required this.onTap, this.onLongPress});
  final Bill bill;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      onTap: onTap,
      onLongPress: onLongPress,
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
                  '${bill.groupName} · ${bill.participants.length}人 · ${Fmt.relative(bill.billDate)} · ${SplitText.label(bill.splitType)}',
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          HandAmount(amountCents: bill.amountCents, size: 24, trimZero: true),
          SizedBox(width: 10),
          StampBadge(
            text: bill.fullySettled ? '✅已结清' : '待结算',
            color: bill.fullySettled ? AASemantic.stampDone : AASemantic.stampMoney,
          ),
        ],
      ),
    );
  }
}
