import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/group.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P20 群组列表页 —— 对齐 docs/ui-demo/index.html
class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  static const _tints = [
    Color(0xFFEDF7EE),
    Color(0xFFF0F6FB),
    Color(0xFFF7F0FB),
    Color(0xFFFFF1EA),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final me = ref.watch(currentUserProvider)?.id ?? 'me';

    return AaScaffold(
      appBar: AaAppBar(
        title: '我的群组',
        back: false,
        onBack: null,
        headIcon: 'assets/icons/group.png',
        iconImage: 'assets/icons/search.png',
        onIconTap: () => context.push('/search'),
      ),
      body: groups.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _InviteCard(onTap: () => context.push('/groups/create')),
                const SizedBox(height: 12),
                EmptyState(
                  title: '还没有群组，拉上小伙伴开个AA局吧～',
                  subtitle: '团团这里只有硬币，快来人多才热闹',
                  tag: 'P20 群组列表',
                  artImage: 'assets/icons/bag.png',
                  buttonLabel: '＋ 创建群组',
                  onButtonTap: () => context.push('/groups/create'),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                _InviteCard(onTap: () => context.push('/groups/${groups.first.id}/invite')),
                SectionTitle('最近', emoji: '📔'),
                for (var i = 0; i < groups.length; i++)
                  _GroupCard(
                    group: groups[i],
                    tint: _tints[i % _tints.length],
                    isOwner: groups[i].ownerId == me,
                    onTap: () => context.push('/groups/${groups[i].id}'),
                    onLongPress: () => _longPress(context, ref, groups[i], me),
                  ),
                const SizedBox(height: 12),
                DoodleButton(
                  label: '＋ 创建群组',
                  type: DoodleButtonType.primary,
                  big: true,
                  onPressed: () => context.push('/groups/create'),
                ),
                const SizedBox(height: 8),
              ],
            ),
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
            emoji: '📌',
            label: '置顶群组',
            onTap: () => Navigator.of(context).pop('pin'),
          ),
          _SheetAction(
            emoji: '🔗',
            label: '复制邀请链接',
            onTap: () async {
              final link = await ref.read(groupRepositoryProvider).inviteLink(g.id);
              if (!context.mounted) return;
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
  const _SheetAction({required this.emoji, required this.label, required this.onTap});
  final String emoji;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(emoji, style: const TextStyle(fontSize: 20)),
      title: Text(label, style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
      trailing: const Text('→', style: TextStyle(fontSize: 15, color: AAColors.inkSoft)),
      onTap: onTap,
    );
  }
}

/// 邀请朋友来AA —— Demo P20 首卡：📮 emoji 底 + 标题/副行 + →
class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          // 邀请卡头像：📮 替换为「邮箱」素材
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1EA),
              shape: BoxShape.circle,
              border: Border.all(color: AAColors.ink, width: 2.5),
            ),
            child: const AaIconImage('assets/icons/inbox.png', size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('邀请朋友来AA',
                    style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
                const SizedBox(height: 2),
                Text('发送邀请链接/二维码',
                    style: const TextStyle(
                        fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
              ],
            ),
          ),
          const Text('→', style: TextStyle(fontSize: 15, color: AAColors.ink)),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.tint,
    required this.isOwner,
    required this.onTap,
    required this.onLongPress,
  });
  final Group group;
  final Color tint;
  final bool isOwner;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: PaperCard(
        onTap: null,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SketchAvatar(emoji: group.avatar, size: 44, background: tint),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(group.name,
                          style: const TextStyle(
                              fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
                      if (isOwner) ...[
                        const SizedBox(width: 6),
                        const Text('👑', style: TextStyle(fontSize: 14)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    group.pendingBillCount > 0
                        ? '${group.memberCount}个小伙伴 · ${group.pendingBillCount}笔待清'
                        : '${group.memberCount}个小伙伴 · 已清账',
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
              text: group.pendingBillCount > 0 ? '${group.pendingBillCount}笔待清' : '✅已清',
              color: group.pendingBillCount > 0
                  ? AASemantic.stampMoney
                  : AASemantic.stampDone,
            ),
          ],
        ),
      ),
    );
  }
}
