import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/group_member.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P24 成员管理页
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = (ref.watch(groupMembersProvider).value ?? const {})[groupId] ?? [];
    final me = ref.watch(currentUserProvider)?.id ?? 'me';

    return AaScaffold(
      appBar: AppBar(
        title: Text('成员管理（${members.length}）'),
        actions: [
          IconButton(
            onPressed: () => context.push('/groups/$groupId/invite'),
            icon: const Icon(Icons.person_add_alt, size: 24, color: AAColors.ink),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          ...members.map((m) => _MemberTile(
                member: m,
                isMe: m.userId == me,
                canManage: m.userId == me ? false : members.any((x) => x.isOwner && x.userId == me),
                onRemove: () => _remove(ref, context, m),
              )),
          const SizedBox(height: 16),
          DoodleButton(
            label: '退出群组',
            type: DoodleButtonType.secondary,
            color: AAColors.berry,
            textColor: AAColors.berry,
            expand: true,
            onPressed: () => _leave(ref, context, me),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(WidgetRef ref, BuildContext context, GroupMember m) async {
    final ok = await showAaConfirm(
      context,
      title: '把「${m.nickname}」移出群？',
      subtitle: 'TA的未结清账单仍会保留在群里',
      confirmLabel: '移除',
    );
    if (ok == true) {
      if (!context.mounted) return;
      await ref.read(groupRepositoryProvider).removeMember(groupId, m.userId);
      if (!context.mounted) return;
      ref.read(refreshProvider.notifier).bump();
      showAaToast(context, '已移除 ${m.nickname}');
    }
  }

  Future<void> _leave(WidgetRef ref, BuildContext context, String me) async {
    final members = (ref.read(groupMembersProvider).value ?? const {})[groupId] ?? [];
    final isOwner = members.any((x) => x.isOwner && x.userId == me);
    if (isOwner) {
      showAaToast(context, '你是群主，先转让群主或解散群组');
      return;
    }
    final ok = await showAaConfirm(
      context,
      title: '要退出这个群吗？',
      subtitle: '退出不影响账单结算',
      confirmLabel: '退出',
    );
    if (ok == true) {
      if (!context.mounted) return;
      await ref.read(groupRepositoryProvider).removeMember(groupId, me);
      if (!context.mounted) return;
      ref.read(refreshProvider.notifier).bump();
      showAaToast(context, '已退出群组');
      if (context.mounted) context.pop();
    }
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isMe,
    required this.canManage,
    required this.onRemove,
  });
  final GroupMember member;
  final bool isMe;
  final bool canManage;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          SketchAvatar(emoji: member.avatarUrl, size: 46, name: member.nickname),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(member.nickname, style: text.titleMedium),
                    if (member.isOwner) ...[
                      const SizedBox(width: 6),
                      const Text('👑', style: TextStyle(fontSize: 14)),
                    ],
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      const Text('(我)', style: TextStyle(fontSize: 12, color: AAColors.inkSoft)),
                    ],
                  ],
                ),
                Text(
                  '@${member.accountName} · ${member.joinedAt != null ? '加入于${member.joinedAt!.year}' : '刚加入'}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          if (canManage)
            InkWell(
              onTap: onRemove,
              child: const Icon(Icons.delete_outline, color: AAColors.berry, size: 22),
            )
          else if (!member.isOwner)
            const Text('已完成',
                style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
        ],
      ),
    );
  }
}
