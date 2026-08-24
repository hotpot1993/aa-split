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

  AuthState copyWith({User? user, String? token}) =>
      AuthState(user: user ?? this.user, token: token ?? this.token);
}

final authProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repo = ref.read(authRepositoryProvider);
    final user = repo.restoreSession();
    // Demo 模式：默认自动进入已登录会话（见 AppConfig.mockAutoLogin）
    if (AppConfig.useMock && AppConfig.mockAutoLogin && user != null) {
      return AuthState(user: user, token: 'mock-token');
    }
    return const AuthState();
  }

  void login(String accountName, String password) {
    final user = ref.read(authRepositoryProvider).login(accountName, password);
    state = AuthState(user: user, token: 'mock-token');
  }

  void register({
    required String accountName,
    required String password,
    required String nickname,
    required String securityQuestion,
    required String securityAnswer,
  }) {
    final user = ref.read(authRepositoryProvider).register(
          accountName: accountName,
          password: password,
          nickname: nickname,
          securityQuestion: securityQuestion,
          securityAnswer: securityAnswer,
        );
    state = AuthState(user: user, token: 'mock-token');
  }

  void logout() {
    ref.read(authRepositoryProvider).logout();
    state = const AuthState();
  }

  /// 更新昵称/头像/签名（P50 即时生效）
  void updateProfile({String? nickname, String? avatarUrl, String? bio}) {
    final user = state.user;
    if (user == null) return;
    final updated = user.copyWith(
      nickname: nickname,
      avatarUrl: avatarUrl,
      bio: bio,
    );
    MockStore.instance.currentUser = updated;
    state = AuthState(user: updated, token: state.token);
  }

  /// 重置密码后强制登出（P05）
  void forceLogout() {
    state = const AuthState();
  }
}
