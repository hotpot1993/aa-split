import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../data/mock/mock_store.dart';
import '../models/user.dart';
import 'repositories.dart';

/// 登录态
class AuthState {
  const AuthState({this.user, this.token});

  final User? user;
  final String? token;

  bool get isLoggedIn => user != null && token != null;

  AuthState copyWith({User? user, String? token, bool clear = false}) =>
      clear
          ? const AuthState()
          : AuthState(user: user ?? this.user, token: token ?? this.token);
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Demo 模式：同步恢复；真实模式由 Splash 调用 restore() 异步恢复
    final user = ref.read(authRepositoryProvider).restoreSessionSync();
    if (AppConfig.useMock && AppConfig.mockAutoLogin && user != null) {
      return AuthState(user: user, token: 'mock-token');
    }
    return const AuthState();
  }

  /// 真实模式：从本地存储恢复会话（含 token 校验），启动页调用
  Future<void> restore() async {
    final user = await ref.read(authRepositoryProvider).restoreSession();
    if (user != null) {
      state = AuthState(user: user, token: 'restored');
    }
  }

  Future<void> login(String accountName, String password) async {
    final user =
        await ref.read(authRepositoryProvider).login(accountName, password);
    state = AuthState(user: user, token: AppConfig.useMock ? 'mock-token' : 'jwt');
  }

  Future<void> register({
    required String accountName,
    required String password,
    required String nickname,
    required String securityQuestion,
    required String securityAnswer,
  }) async {
    final user = await ref.read(authRepositoryProvider).register(
          accountName: accountName,
          password: password,
          nickname: nickname,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
        );
    state = AuthState(user: user, token: AppConfig.useMock ? 'mock-token' : 'jwt');
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AuthState();
  }

  /// 更新昵称/头像/签名（P50 即时生效；真实模式暂无服务端端点，仅本地演示）
  void updateProfile({String? nickname, String? avatarUrl, String? bio}) {
    final user = state.user;
    if (user == null) return;
    final updated = user.copyWith(
      nickname: nickname,
      avatarUrl: avatarUrl,
      bio: bio,
    );
    if (AppConfig.useMock) {
      MockStore.instance.currentUser = updated;
    }
    state = AuthState(user: updated, token: state.token);
  }

  /// 重置密码后强制登出（P05）
  void forceLogout() {
    state = const AuthState();
  }
}
