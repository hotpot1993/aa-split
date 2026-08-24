import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/api/codec.dart';
import '../../core/config.dart';
import '../../models/notification_item.dart';
import '../mock/mock_store.dart';

/// 通知仓库。
/// Demo 模式走 MockStore（sendRemind/sendInvite/sendRegular 仅供演示）；
/// 真实模式（AA_USE_MOCK=false）对接 /notifications 系列接口。
/// 服务端通知由 /bills/:id/remind 等操作产生，客户端不直接写通知。
class NotificationRepository {
  NotificationRepository();

  static const _pageSize = 100;

  Future<List<NotificationItem>> list() async {
    if (AppConfig.useMock) {
      final out = List.of(MockStore.instance.notifications)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    }
    final res = await ApiClient.instance
        .get('/notifications', query: {'page': 1, 'pageSize': _pageSize});
    final j = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
    final list = (j['list'] is List) ? j['list'] as List : const [];
    return list.map(parseNotification).toList();
  }

  Future<int> unreadCount() async {
    if (AppConfig.useMock) {
      return MockStore.instance.notifications.where((n) => !n.isRead).length;
    }
    final res = await ApiClient.instance.get('/notifications/unread-count');
    final j = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
    return (j['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final idx = store.notifications.indexWhere((n) => n.id == id);
      if (idx >= 0) store.notifications[idx] = store.notifications[idx].copyWith(isRead: true);
      return;
    }
    await ApiClient.instance.post('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      store.notifications.replaceRange(0, store.notifications.length,
          store.notifications.map((n) => n.copyWith(isRead: true)));
      return;
    }
    await ApiClient.instance.post('/notifications/read-all');
  }

  /// 发送催款提醒（P26 → P40 对方收到）。
  /// 真实模式：服务端由 POST /bills/:id/remind 写通知并推 SSE，此处仅演示用不落库。
  Future<void> sendRemind({
    required String billId,
    required String billTitle,
    required List<String> userIds,
    required String message,
  }) async {
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
    // 真实模式由服务端产生通知（/bills/:id/remind），无需本地写入
  }

  /// 邀请通知（Demo 演示用；真实模式由加入群后的服务端通知流转）
  Future<void> sendInvite({required String groupName, required String inviteCode}) async {
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
  }

  /// 定期账单通知（P34 开启后横幅；真实模式由服务端 BullMQ 生成）
  Future<void> sendRegular(RegularBillDraft draft) async {
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
  }

  /// 实时通知流（SSE，仅真实模式）。
  ///
  /// 连接服务端 `GET /notifications/stream`（靠 ApiClient 的 Bearer 拦截器带 token），
  /// 逐行解析 `data:` 事件；断线/报错后 3s 退避自动重连，直到订阅方取消。
  /// Demo 模式返回空流（UI 层通过 [notificationStreamProvider] 订阅）。
  Stream<Map<String, dynamic>> sseEvents() async* {
    if (AppConfig.useMock) return;
    while (true) {
      try {
        final res = await ApiClient.instance.dio.get<ResponseBody>(
          '/notifications/stream',
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Accept': 'text/event-stream'},
            // SSE 是长连接，取消默认 15s 接收超时（服务端 25s 心跳）
            receiveTimeout: Duration.zero,
          ),
        );
        final body = res.data;
        if (body == null) return;
        await for (final line in utf8.decoder
            .bind(body.stream)
            .transform(const LineSplitter())) {
          if (!line.startsWith('data:')) continue;
          final payload = line.substring(5).trim();
          if (payload.isEmpty) continue;
          try {
            yield (jsonDecode(payload) as Map).cast<String, dynamic>();
          } catch (_) {
            // 单帧解析失败忽略，不断流
          }
        }
        // 服务端关闭连接（keep-alive 超时等）：继续循环重连
      } catch (_) {
        await Future<void>.delayed(const Duration(seconds: 3));
      }
    }
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
