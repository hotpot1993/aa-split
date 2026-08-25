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

/// P40 消息中心 —— 对齐 docs/ui-demo/index.html
class MessagesScreen extends ConsumerWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(notificationsProvider).value ?? const <NotificationItem>[];
    final today = items.where((n) => n.isToday).toList();
    final earlier = items.where((n) => !n.isToday).toList();

    return AaScaffold(
      appBar: AaAppBar(
        title: '消息中心',
        back: false,
        headIcon: 'assets/icons/notify.png',
        iconImage: 'assets/icons/settings.png',
        onIconTap: () => context.push('/messages/settings'),
      ),
      body: items.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                EmptyState(
                  title: '安静的一天～ 没有新消息',
                  subtitle: '团团戴着耳机打瞌睡，你不找它它不醒',
                  tag: 'P40 消息中心',
                  artImage: 'assets/icons/headphone.png',
                  buttonLabel: '去记一笔',
                  onButtonTap: () => context.push('/add'),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (today.isNotEmpty)
                  SectionTitle('今天', emojiImage: 'assets/icons/sun.png'),
                ...today.map((n) => _MsgCard(n: n)),
                if (earlier.isNotEmpty)
                  SectionTitle('更早', emojiImage: 'assets/icons/moon.png'),
                ...earlier.map((n) => _MsgCard(n: n)),
                SizedBox(height: 16),
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
    final isRemind = n.type == NotifyType.remind;
    final isInvite = n.type == NotifyType.invite;
    final emoji = _emojiOf(n.type);

    void open() {
      ref.read(notificationRepositoryProvider).markRead(n.id);
      ref.read(refreshProvider.notifier).bump();
      if (n.refType == 'bill' && n.refId.isNotEmpty) {
        context.push('/bills/${n.refId}');
      } else if (n.refType == 'group' && n.refId.isNotEmpty) {
        context.push('/groups/${n.refId}');
      }
    }

    // 催款粉卡（Demo：border-color:var(--pink);background:#FFF6F8 + 印章）
    if (isRemind) {
      return PaperCard(
        margin: const EdgeInsets.only(bottom: 16),
        color: AASemantic.msgPinkBg,
        borderColor: AAColors.berry,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StampBadge(text: '催款', color: AASemantic.stampMoney),
                SizedBox(width: 8),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: '',
                        style: TextStyle(fontFamily: AAFonts.title, fontSize: 12)),
                    TextSpan(text: n.title, style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 12, color: AAColors.ink)),
                  ])),
                ),
              ],
            ),
            SizedBox(height: 6),
            Text('来自：${n.body}',
                style: TextStyle(
                    fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
            SizedBox(height: 8),
            DoodleButton(
              label: '去处理 ✓',
              mini: true,
              onPressed: open,
            ),
          ],
        ),
      );
    }

    // 邀请卡（emoji + 标题 + 接受/拒绝按钮）
    if (isInvite) {
      return PaperCard(
        onTap: open,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AaIconImage(emoji, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text(n.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DoodleButton(
                    label: '接受 ✓',
                    mini: true,
                    expand: true,
                    color: AAColors.mint,
                    textColor: AAColors.ink,
                    onPressed: () => showAaToast(context, '🎉 已加入群组'),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: DoodleButton(
                    label: '拒绝 ✗',
                    mini: true,
                    expand: true,
                    onPressed: () => showAaToast(context, '已拒绝邀请'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 普通消息卡（emoji + 标题 + mini dim 详情 + chip）
    return PaperCard(
      onTap: open,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          AaIconImage(emoji, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                SizedBox(height: 2),
                Text('${n.body} · ${Fmt.relative(n.createdAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
              ],
            ),
          ),
          SizedBox(width: 8),
          HandTag(_chipText(n.type), fontSize: 12, variant: ChipVariant.blue),
        ],
      ),
    );
  }

  String _chipText(NotifyType t) => switch (t) {
        NotifyType.newBill => '新账单',
        NotifyType.regular => '定期',
        NotifyType.settled => '已清',
        NotifyType.member => '动态',
        NotifyType.remind => '催款',
        NotifyType.invite => '邀请',
      };

  String _emojiOf(NotifyType t) => switch (t) {
        NotifyType.newBill => 'assets/icons/receipt.png',
        NotifyType.remind => 'assets/icons/broadcast.png',
        NotifyType.invite => 'assets/icons/inbox.png',
        NotifyType.regular => 'assets/icons/notify.png',
        NotifyType.settled => 'assets/icons/party.png',
        NotifyType.member => 'assets/icons/group.png',
      };
}
