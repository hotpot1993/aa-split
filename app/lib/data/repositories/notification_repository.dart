import '../../core/config.dart';
import '../../models/notification_item.dart';
import '../mock/mock_store.dart';

/// 通知仓库（Demo 模式走 MockStore）
///
/// 非 Demo 模式：应改为 async 并调用 ApiClient 的 `/notifications`（技术方案 §4.5）。
class NotificationRepository {
  NotificationRepository();

  List<NotificationItem> list() {
    if (AppConfig.useMock) {
      final out = List.of(MockStore.instance.notifications)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    }
    throw UnsupportedError('useMock=false：list 需 async + ApiClient');
  }

  int unreadCount() {
    if (AppConfig.useMock) {
      return MockStore.instance.notifications.where((n) => !n.isRead).length;
    }
    throw UnsupportedError('useMock=false：unreadCount 需 async + ApiClient');
  }

  void markRead(String id) {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final idx = store.notifications.indexWhere((n) => n.id == id);
      if (idx >= 0) store.notifications[idx] = store.notifications[idx].copyWith(isRead: true);
      return;
    }
    throw UnsupportedError('useMock=false：markRead 需 async + ApiClient');
  }

  void markAllRead() {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      store.notifications.replaceRange(0, store.notifications.length,
          store.notifications.map((n) => n.copyWith(isRead: true)));
      return;
    }
    throw UnsupportedError('useMock=false：markAllRead 需 async + ApiClient');
  }

  /// 发送催款提醒（P26 → P40 对方收到）
  void sendRemind({
    required String billId,
    required String billTitle,
    required List<String> userIds,
    required String message,
  }) {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      for (final uid in userIds) {
        store.notifications.add(NotificationItem(
          id: 'nr${DateTime.now().microsecondsSinceEpoch}_$uid',
          type: NotifyType.remind,
          title: '催你付 AA',
          body: '$billTitle · 去处理一下',
          createdAt: DateTime.now(),
          isRead: false,
          refType: 'bill',
          refId: billId,
        ));
      }
      return;
    }
    throw UnsupportedError('useMock=false：sendRemind 需 async + ApiClient');
  }

  /// 邀请通知
  void sendInvite({required String groupName, required String inviteCode}) {
    if (AppConfig.useMock) {
      MockStore.instance.notifications.add(NotificationItem(
        id: 'ni${DateTime.now().microsecondsSinceEpoch}',
        type: NotifyType.invite,
        title: '$groupName 邀请你加入',
        body: '接受邀请一起分账',
        createdAt: DateTime.now(),
        isRead: false,
        refType: 'group',
        refId: inviteCode,
      ));
      return;
    }
    throw UnsupportedError('useMock=false：sendInvite 需 async + ApiClient');
  }

  /// 定期账单通知（P34 开启后横幅）
  void sendRegular(RegularBillDraft draft) {
    if (AppConfig.useMock) {
      MockStore.instance.notifications.add(NotificationItem(
        id: 'nreg${DateTime.now().microsecondsSinceEpoch}',
        type: NotifyType.regular,
        title: '${draft.title} 已生成',
        body: '定期账单 · ${FmtPlain.yuan(draft.amountCents)}',
        createdAt: DateTime.now(),
        isRead: false,
        refType: 'bill',
        refId: draft.groupId,
      ));
      return;
    }
    throw UnsupportedError('useMock=false：sendRegular 需 async + ApiClient');
  }
}

/// 定期账单草稿（P34 开启后写入通知）
class RegularBillDraft {
  const RegularBillDraft({
    required this.title,
    required this.groupId,
    required this.groupName,
    required this.amountCents,
  });

  final String title;
  final String groupId;
  final String groupName;
  final int amountCents;
}

/// 轻量金额格式化（避免与 UI 层 Fmt 耦合）
abstract final class FmtPlain {
  static String yuan(int cents) {
    final negative = cents < 0;
    final abs = cents.abs();
    final s = '¥${(abs ~/ 100)}.${(abs % 100).toString().padLeft(2, '0')}';
    return negative ? '-$s' : s;
  }
}
