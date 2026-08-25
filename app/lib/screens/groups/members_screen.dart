import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/group_member.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P24 成员管理 —— 对齐 docs/ui-demo/index.html
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = (ref.watch(groupMembersProvider).value ?? const {})[groupId] ?? [];
    final me = ref.watch(currentUserProvider)?.id ?? 'me';

    return AaScaffold(
      appBar: AaAppBar(title: '👑 成员管理', icon: '➕', onIconTap: () => context.push('/groups/$groupId/invite')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                for (var i = 0; i < members.length; i++)
                  _MemberLine(
                    member: members[i],
                    isMe: members[i].userId == me,
                    showBorder: i != members.length - 1,
                    canManage:
                        members[i].userId == me
                            ? false
                            : members.any((x) => x.isOwner && x.userId == me),
                    onRemove: () => _remove(ref, context, members[i]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DoodleButton(
            label: '＋ 添加成员',
            big: true,
            onPressed: () => context.push('/groups/$groupId/invite'),
          ),
          const SizedBox(height: 10),
          DoodleButton(
            label: '退出群组（账单仍保留）',
            type: DoodleButtonType.danger,
            big: true,
            onPressed: () => _leave(ref, context, me),
          ),
          const SizedBox(height: 16),
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
      showAaToast(context, '👋 已退出群组');
      if (context.mounted) context.pop();
    }
  }
}

class _MemberLine extends StatelessWidget {
  const _MemberLine({
    required this.member,
    required this.isMe,
    required this.showBorder,
    required this.canManage,
    required this.onRemove,
  });
  final GroupMember member;
  final bool isMe;
  final bool showBorder;
  final bool canManage;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(
                  text: '${member.avatarUrl} ${member.nickname}${isMe ? '（我）' : ''} ',
                  style: const TextStyle(
                      fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink),
                ),
                TextSpan(
                  text: '@${member.accountName}',
                  style: const TextStyle(
                      fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft),
                ),
              ])),
              if (member.isOwner)
                const Text('👑 群主',
                    style: TextStyle(
                        fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink))
              else if (canManage)
                InkWell(
                  onTap: onRemove,
                  child: Row(
                    children: [
                      const HandTag('正常', dense: true, variant: ChipVariant.blue),
                      const SizedBox(width: 6),
                      const Text('✗',
                          style: TextStyle(
                              fontFamily: 'ZCOOLKuaiLe', fontSize: 13, color: AAColors.inkSoft)),
                      const SizedBox(width: 2),
                      Text('移除',
                          style: const TextStyle(
                              fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
                    ],
                  ),
                )
              else
                const HandTag('正常', dense: true, variant: ChipVariant.blue),
            ],
          ),
        ),
        if (showBorder)
          CustomPaint(size: const Size(double.infinity, 2.5), painter: _MemberDash()),
      ],
    );
  }
}

class _MemberDash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AAColors.ink
      ..strokeWidth = 2.5;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1.25), Offset(x + 7, 1.25), p);
      x += 14;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
