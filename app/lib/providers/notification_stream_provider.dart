import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import 'auth_provider.dart';
import 'refresh_provider.dart';
import 'repositories.dart';

/// 实时通知流控制器（P40 实时更新）。
///
/// - 真实模式（AA_USE_MOCK=false）：登录后订阅 `NotificationRepository.sseEvents()`
///   （服务端 SSE），收到事件即 bump 刷新 → 消息中心列表与 Tab 角标自动更新；
///   登出自动取消订阅。
/// - Demo 模式：流为空，控制器保持关闭（无副作用）。
final notificationStreamProvider =
    NotifierProvider<NotificationStreamController, bool>(
        NotificationStreamController.new);

class NotificationStreamController extends Notifier<bool> {
  StreamSubscription<Map<String, dynamic>>? _sub;

  /// 小票 OCR 识别完成事件（type == 'receipt-ocr'）的广播通道
  final _ocrEvents = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get ocrEvents => _ocrEvents.stream;

  @override
  bool build() {
    ref.listen(authProvider, (_, next) => _sync(next.isLoggedIn));
    _sync(ref.read(authProvider).isLoggedIn);
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
      _ocrEvents.close();
    });
    return _sub != null;
  }

  void _sync(bool loggedIn) {
    if (AppConfig.useMock || !loggedIn) {
      _sub?.cancel();
      _sub = null;
      state = false;
      return;
    }
    if (_sub != null) return;
    _sub = ref.read(notificationRepositoryProvider).sseEvents().listen(
          (e) {
            if (e['type'] == 'receipt-ocr') {
              // 服务端按 SsePayload 信封推送（结果在 data 内），摊平后页面可直接读
              // kind/receiptId/uploadId/amountCents 等（与设计文档扁平载荷一致）
              _ocrEvents.add(flattenOcrEvent(e));
            }
            ref.read(refreshProvider.notifier).bump();
          },
          onError: (_) {},
        );
    state = true;
  }
}

/// 将 SSE `receipt-ocr` 事件（结果嵌套在 `data` 里的 SsePayload 信封）摊平到顶层，
/// 便于各页面 `_onOcrEvent` 直接读取 `kind/uploadId/receiptId/amountCents/confidence/currency/ocrStatus`。
Map<String, dynamic> flattenOcrEvent(Map<String, dynamic> e) {
  final data = e['data'];
  if (data is Map) {
    return {...e, ...Map<String, dynamic>.from(data)};
  }
  return e;
}

/// 小票 OCR 识别结果流（由 notificationStreamProvider 内部分流，不额外占连接）
final receiptOcrEventsProvider = Provider<Stream<Map<String, dynamic>>>((ref) {
  ref.watch(notificationStreamProvider);
  return ref.read(notificationStreamProvider.notifier).ocrEvents;
});
