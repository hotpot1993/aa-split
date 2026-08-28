import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/format.dart';
import '../../models/notification_item.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P40 消息中心 —— 对齐 docs/ui-demo/index.html
///
/// 删除/清空采用「乐观更新」：二次确认后立即从列表消失（本地隐藏集合），
/// 服务端删除成功后由 refreshProvider 重载兜底；失败自动恢复显示并提示。
/// 另支持下拉刷新（重置本地隐藏状态并强制重拉列表）。
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  /// 已确认删除、本地先行隐藏的消息 id（服务端删除成功前不显示，失败即恢复）
  final Set<String> _hiddenIds = {};

  /// 「清空」确认后的本地清空标记（同上，失败恢复）
  bool _clearedAll = false;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(notificationsProvider).value ?? const <NotificationItem>[];
    final items = _clearedAll
        ? const <NotificationItem>[]
        : all.where((n) => !_hiddenIds.contains(n.id)).toList();
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final today = items.where((n) => n.isToday).toList();
    final earlier = items.where((n) => !n.isToday).toList();

    return AaScaffold(
      appBar: AaAppBar(
        title: '消息中心',
        back: false,
        headIcon: 'assets/icons/notify.png',
        iconImage: 'assets/icons/settings.png',
        onIconTap: () => context.push('/messages/settings'),
        // 「全部已读」：有未读消息时显示，点击把当前所有未读消息标记为已读；
        // 「清空」：有任何消息时显示，二次确认后删除全部消息
        actions: [
          if (unread > 0)
            InkWell(
              onTap: _markAllRead,
              child: Padding(
                padding: const EdgeInsets.only(left: 10, top: 8),
                child: Text('全部已读',
                    style: TextStyle(
                        fontFamily: AAFonts.title,
                        fontSize: 14,
                        color: AAColors.sky)),
              ),
            ),
          if (items.isNotEmpty)
            InkWell(
              onTap: _clearAll,
              child: Padding(
                padding: const EdgeInsets.only(left: 10, top: 8),
                child: Text('清空',
                    style: TextStyle(
                        fontFamily: AAFonts.title,
                        fontSize: 14,
                        color: AAColors.berry)),
              ),
            ),
        ],
      ),
      body: items.isEmpty
          ? RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  EmptyState(
                    title: '安静的一天～ 没有新消息',
                    subtitle: '团团戴着耳机打瞌睡，你不找它它不醒',
                    tag: '消息中心',
                    artImage: 'assets/icons/headphone.png',
                    buttonLabel: '去记一笔',
                    onButtonTap: () => context.push('/add'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (today.isNotEmpty)
                    SectionTitle('今天', emojiImage: 'assets/icons/sun.png'),
                  ...today.map((n) => _MsgCard(
                        n: n,
                        onLocallyHidden: () => _hideLocally(n.id),
                        onLocalRestore: () => _restoreLocally(n.id),
                      )),
                  if (earlier.isNotEmpty)
                    SectionTitle('更早', emojiImage: 'assets/icons/moon.png'),
                  ...earlier.map((n) => _MsgCard(
                        n: n,
                        onLocallyHidden: () => _hideLocally(n.id),
                        onLocalRestore: () => _restoreLocally(n.id),
                      )),
                  SizedBox(height: 16),
                ],
              ),
            ),
    );
  }

  void _hideLocally(String id) {
    if (!mounted) return;
    setState(() => _hiddenIds.add(id));
  }

  void _restoreLocally(String id) {
    if (!mounted) return;
    setState(() => _hiddenIds.remove(id));
  }

  /// 下拉刷新：重置本地乐观状态并强制重拉列表/角标
  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _hiddenIds.clear();
      _clearedAll = false;
    });
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
    try {
      await ref.read(notificationsProvider.future);
    } catch (e) {
      // 刷新失败保持当前内容，Toast 提示
      if (mounted) showAaToast(context, '❌ 刷新失败：${_friendly(e)}');
    }
  }

  /// 全部已读：当前所有未读消息标记为已读（Mock/真实模式都由仓库落库）
  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationRepositoryProvider).markAllRead();
      ref.read(refreshProvider.notifier).bump();
      if (mounted) showAaToast(context, '📮 已全部标记为已读');
    } catch (e) {
      if (mounted) showAaToast(context, '❌ 操作失败：${_friendly(e)}');
    }
  }

  /// 清空全部消息：二次确认 → 本地立即清空 → 服务端落库；异常后复核服务端定去留
  Future<void> _clearAll() async {
    final ok = await showAaConfirm(
      context,
      title: '清空全部消息？',
      subtitle: '所有消息将被删除，不可恢复',
      confirmLabel: '清空',
    );
    if (ok != true) return;
    if (!mounted) return;
    setState(() => _clearedAll = true);
    try {
      await ref.read(notificationRepositoryProvider).clearAll();
      ref.read(refreshProvider.notifier).bump();
      if (mounted) showAaToast(context, '🗑️ 已清空全部消息');
    } catch (e) {
      // 网络层失败 ≠ 清空失败（响应可能只是没送回来）——以服务端列表复核
      final gone = await _serverConfirmGone(ref);
      if (!mounted) return;
      if (gone) {
        ref.read(refreshProvider.notifier).bump();
        showAaToast(context, '🗑️ 已清空全部消息');
      } else {
        setState(() => _clearedAll = false);
        showAaToast(context, '❌ 清空失败：${_friendly(e)}');
      }
    }
  }

  /// 服务端/网络错误的用户可读文案
  static String _friendly(Object e) =>
      e is ApiException ? e.message : '网络开小差了，稍后再试';
}

/// 删除/清空请求异常后的「服务端复核」（v1.0.14）。
///
/// 真机网络偶发丢响应（超时/连接重置/回包未达），此时删除**可能已在服务端生效**；
/// 旧逻辑一律恢复显示，造成"删掉又复活"。现改为重拉服务端列表：
/// [id] 不在最新列表（或 [id] 为 null 时列表为空）→ 视为删除成功，保持隐藏；
/// 复核失败或仍在列表 → 返回 false，由调用方恢复显示并提示。
Future<bool> _serverConfirmGone(WidgetRef ref, {String? id}) async {
  ref.invalidate(notificationsProvider);
  try {
    final fresh = await ref.read(notificationsProvider.future);
    return id == null ? fresh.isEmpty : !fresh.any((m) => m.id == id);
  } catch (_) {
    return false;
  }
}

class _MsgCard extends ConsumerWidget {
  const _MsgCard({
    required this.n,
    required this.onLocallyHidden,
    required this.onLocalRestore,
  });
  final NotificationItem n;

  /// 确认删除后立即隐藏（不等网络回包）；删除失败恢复显示
  final VoidCallback onLocallyHidden;
  final VoidCallback onLocalRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 左滑删除 + 长按删除（共用同一条二次确认链路）
    return _SwipeToDelete(
      notification: n,
      onLocallyHidden: onLocallyHidden,
      onLocalRestore: onLocalRestore,
      child: _buildCard(context, ref),
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref) {
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
        onLongPress: () => _confirmDelete(context, ref),
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
              label: '去处理',
              trailingImage: 'assets/icons/check.png',
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
        onLongPress: () => _confirmDelete(context, ref),
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
                    label: '接受',
                    trailingImage: 'assets/icons/check.png',
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
                    label: '拒绝',
                    trailingImage: 'assets/icons/cross.png',
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
      onLongPress: () => _confirmDelete(context, ref),
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

  /// 长按删除：二次确认 → 本地立即隐藏 → 服务端落库；异常后复核服务端定去留
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showAaConfirm(
      context,
      title: '删除这条消息？',
      subtitle: '删除后不可恢复',
      confirmLabel: '删除',
    );
    if (ok != true) return;
    onLocallyHidden();
    try {
      await ref.read(notificationRepositoryProvider).remove(n.id);
      ref.read(refreshProvider.notifier).bump();
      if (context.mounted) showAaToast(context, '🗑️ 已删除');
    } catch (e) {
      // 网络层失败 ≠ 删除失败（v1.0.14）：复核服务端，已不在列表则保持隐藏
      final gone = await _serverConfirmGone(ref, id: n.id);
      if (gone) {
        ref.read(refreshProvider.notifier).bump();
        if (context.mounted) showAaToast(context, '🗑️ 已删除');
      } else {
        onLocalRestore();
        if (context.mounted) {
          showAaToast(context,
              '❌ 删除失败：${e is ApiException ? e.message : '网络开小差了，稍后再试'}');
        }
      }
    }
  }
}

/// 左滑删除单条消息：露出删除背景，松手弹二次确认。
/// 确认后本地乐观隐藏 + 仓库删除；confirmDismiss 始终返回 false，
/// 避免「Dismissible 已确认移除但 widget 仍在树中」断言（移除交给乐观隐藏 + 列表刷新）。
class _SwipeToDelete extends ConsumerWidget {
  const _SwipeToDelete({
    required this.notification,
    required this.child,
    required this.onLocallyHidden,
    required this.onLocalRestore,
  });

  final NotificationItem notification;
  final Widget child;
  final VoidCallback onLocallyHidden;
  final VoidCallback onLocalRestore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('msg-${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.only(right: 18),
        decoration: BoxDecoration(
          color: AAColors.berry,
          borderRadius: AARadii.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AaIconImage('assets/icons/cross.png', size: 18),
            SizedBox(width: 6),
            Text('删除',
                style: TextStyle(
                    fontFamily: AAFonts.title,
                    fontSize: 14,
                    color: AAColors.paper)),
          ],
        ),
      ),
      confirmDismiss: (direction) => _confirmDelete(context, ref),
      child: child,
    );
  }

  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showAaConfirm(
      context,
      title: '删除这条消息？',
      subtitle: '删除后不可恢复',
      confirmLabel: '删除',
    );
    if (ok != true) return false;
    onLocallyHidden();
    try {
      await ref.read(notificationRepositoryProvider).remove(notification.id);
      ref.read(refreshProvider.notifier).bump();
      if (context.mounted) showAaToast(context, '🗑️ 已删除');
    } catch (e) {
      // 网络层失败 ≠ 删除失败（v1.0.14）：复核服务端，已不在列表则保持隐藏
      final gone = await _serverConfirmGone(ref, id: notification.id);
      if (gone) {
        ref.read(refreshProvider.notifier).bump();
        if (context.mounted) showAaToast(context, '🗑️ 已删除');
      } else {
        onLocalRestore();
        if (context.mounted) {
          showAaToast(context,
              '❌ 删除失败：${e is ApiException ? e.message : '网络开小差了，稍后再试'}');
        }
      }
    }
    return false;
  }
}
