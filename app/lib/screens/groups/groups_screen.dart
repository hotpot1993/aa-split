import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/group.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P20 群组列表页
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    final me = ref.watch(currentUserProvider)?.id ?? 'me';

    return AaScaffold(
      appBar: AppBar(
        title: const Text('群组'),
        actions: [
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search, color: AAColors.ink, size: 24),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: GestureDetector(
              onTap: () => context.push('/search'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AAColors.cardWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AAColors.ink, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 18, color: AAColors.inkSoft),
                    const SizedBox(width: 8),
                    Text('搜群组名 / 群成员',
                        style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 14, color: AAColors.inkSoft)),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: groups.isEmpty
                ? EmptyState(
                    title: '还没有群组，拉上小伙伴开个AA局吧～',
                    buttonLabel: '＋ 创建群组',
                    onButtonTap: () => context.push('/groups/create'),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      for (final g in groups)
                        _GroupCard(
                          group: g,
                          isOwner: g.ownerId == me,
                          onTap: () => context.push('/groups/${g.id}'),
                          onLongPress: () => _longPress(context, ref, g, me),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: DoodleButton(
                label: '邀请朋友',
                type: DoodleButtonType.secondary,
                expand: true,
                onPressed: groups.isEmpty
                    ? () => context.push('/groups/create')
                    : () => context.push('/groups/${groups.first.id}/invite'),
              ),
            ),
          ),
        ],
      ),
      bottomBar: null,
    );
  }

  Future<void> _longPress(BuildContext context, WidgetRef ref, Group g, String me) async {
    final action = await showAaSheet<String>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('「${g.name}」', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          _SheetAction(
            icon: Icons.push_pin,
            label: '置顶群组',
            onTap: () => Navigator.of(context).pop('pin'),
          ),
          _SheetAction(
            icon: Icons.link,
            label: '复制邀请链接',
            onTap: () {
              final link = ref.read(groupRepositoryProvider).inviteLink(g.id);
              Clipboard.setData(ClipboardData(text: link));
              Navigator.of(context).pop('copy');
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (!context.mounted) return;
    if (action == 'pin') showAaToast(context, '已置顶「${g.name}」');
    if (action == 'copy') showAaToast(context, '邀请链接已复制');
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AAColors.ink, size: 22),
      title: Text(label, style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
      trailing: const Icon(Icons.chevron_right, color: AAColors.inkSoft),
      onTap: onTap,
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.isOwner,
    required this.onTap,
    required this.onLongPress,
  });
  final Group group;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: PaperCard(
        margin: const EdgeInsets.only(bottom: 14),
        withTape: true,
        tiltSeed: group.id,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AAColors.lemon.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AAColors.ink, width: 1.5),
              ),
              child: Text(group.avatar, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(group.name, style: text.titleLarge),
                      if (isOwner) ...[
                        const SizedBox(width: 6),
                        const Text('👑', style: TextStyle(fontSize: 14)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    group.recentBillTitle.isEmpty
                        ? '${group.memberCount}人 · 还没有账单'
                        : '${group.recentBillTitle} · ${Fmt.relative(group.recentBillDate!)}',
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (group.pendingBillCount > 0)
              _AngleTag(count: group.pendingBillCount)
            else
              Text('${group.memberCount}人', style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _AngleTag extends StatelessWidget {
  const _AngleTag({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.08,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AAColors.berry.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AAColors.berry, width: 1.5),
        ),
        child: Text(
          '📮$count笔待清',
          style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.ink),
        ),
      ),
    );
  }
}
