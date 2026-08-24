import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 数据刷新信号：任意仓库做写操作后 bump 一次，
/// 依赖它的派生 Provider 会重算（MockStore 是同步内存数据）。
final refreshProvider = NotifierProvider<RefreshNotifier, int>(RefreshNotifier.new);

class RefreshNotifier extends Notifier<int> {
  int _v = 0;
  @override
  int build() => _v;

  void bump() {
    _v++;
    state = _v;
  }
}
