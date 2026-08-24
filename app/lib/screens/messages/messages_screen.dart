import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/notification_item.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P40 消息中心页
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider).value ?? const <NotificationItem>[];
    final today = items.where((n) => n.isToday).toList();
    final earlier = items.where((n) => !n.isToday).toList();

    return AaScaffold(
      appBar: AppBar(
        title: const Text('消息中心'),
        actions: [
          IconButton(
            onPressed: () => context.push('/messages/settings'),
            icon: const Icon(Icons.settings, size: 24, color: AAColors.ink),
          ),
          TextButton(
            onPressed: () {
              ref.read(notificationRepositoryProvider).markAllRead();
              ref.read(refreshProvider.notifier).bump();
              showAaToast(context, '全部已读');
            },
            child: const Text('全部已读',
                style: TextStyle(color: AAColors.sky, fontFamily: 'ZCOOLKuaiLe', fontSize: 13)),
          ),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(
              title: '安静的一天～ 没有新消息',
              subtitle: '去记一笔，喊上小伙伴吧',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (today.isNotEmpty) const _GroupLabel(label: '今天'),
                ...today.map((n) => _MsgCard(n: n)),
                if (earlier.isNotEmpty) const _GroupLabel(label: '更早'),
                ...earlier.map((n) => _MsgCard(n: n)),
              ],
            ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft)),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: AAColors.inkSoft, height: 1)),
        ],
      ),
    );
  }
}

class _MsgCard extends ConsumerWidget {
  const _MsgCard({required this.n});
  final NotificationItem n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final isRemind = n.type == NotifyType.remind;
    final isInvite = n.type == NotifyType.invite;
    final color = _colorOf(n.type);

    return GestureDetector(
      onTap: () {
        ref.read(notificationRepositoryProvider).markRead(n.id);
        ref.read(refreshProvider.notifier).bump();
        if (n.refType == 'bill' && n.refId.isNotEmpty) {
          context.push('/bills/${n.refId}');
        } else if (n.refType == 'group' && n.refId.isNotEmpty) {
          context.push('/groups/${n.refId}');
        }
      },
      child: PaperCard(
        margin: const EdgeInsets.only(bottom: 10),
        withTape: true,
        tapeColor: isRemind ? AAColors.berry : AAColors.lemon,
        tiltSeed: n.id,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconOf(n.type), color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    n.title,
                    style: text.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isRemind) const Text('❗', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 4),
                if (!n.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AAColors.berry, shape: BoxShape.circle),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(n.body, style: text.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(Fmt.relative(n.createdAt), style: text.bodySmall),
                const Spacer(),
                if (isRemind)
                  DoodleButton(
                    label: '去处理',
                    type: DoodleButtonType.secondary,
                    onPressed: () => context.push('/bills/${n.refId}'),
                  ),
                if (isInvite) ...[
                  DoodleButton(
                    label: '接受 ✓',
                    type: DoodleButtonType.secondary,
                    onPressed: () => showAaToast(context, '已接受邀请'),
                  ),
                  const SizedBox(width: 8),
                  DoodleButton(
                    label: '拒绝 ✗',
                    onPressed: () => showAaToast(context, '已拒绝邀请'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconOf(NotifyType t) => switch (t) {
        NotifyType.newBill => Icons.receipt_long,
        NotifyType.remind => Icons.notifications_active,
        NotifyType.invite => Icons.group_add,
        NotifyType.regular => Icons.repeat,
        NotifyType.settled => Icons.check_circle,
        NotifyType.member => Icons.people,
      };

  Color _colorOf(NotifyType t) => switch (t) {
        NotifyType.newBill => AAColors.sky,
        NotifyType.remind => AAColors.berry,
        NotifyType.invite => AAColors.mint,
        NotifyType.regular => AAColors.lilac,
        NotifyType.settled => AAColors.mint,
        NotifyType.member => AAColors.lemon,
      };
}
