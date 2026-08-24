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

  @override
  bool build() {
    ref.listen(authProvider, (_, next) => _sync(next.isLoggedIn));
    _sync(ref.read(authProvider).isLoggedIn);
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
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
          (_) => ref.read(refreshProvider.notifier).bump(),
          onError: (_) {},
        );
    state = true;
  }
}
