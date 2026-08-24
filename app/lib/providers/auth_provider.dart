import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../core/jpush/jpush_bridge.dart';
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
      _registerPushAlias(user.id);
    }
  }

  Future<void> login(String accountName, String password) async {
    final user =
        await ref.read(authRepositoryProvider).login(accountName, password);
    state = AuthState(user: user, token: AppConfig.useMock ? 'mock-token' : 'jwt');
    _registerPushAlias(user.id);
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
    _registerPushAlias(user.id);
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    // 极光：清除 alias，避免服务端按 alias 命中已登出设备
    unawaited(JpushBridge.clearAlias());
    state = const AuthState();
  }

  /// 极光推送：alias=userId（真实模式有效；Demo 模式不初始化）
  void _registerPushAlias(String userId) {
    if (AppConfig.useMock) return;
    unawaited(JpushBridge.init(appKey: AppConfig.jpushAppKey, userId: userId));
  }

  /// 更新昵称/头像/签名（P50）：真实模式 PATCH /auth/me 走服务端，
  /// 成功后本地态与服务端资料一致；失败抛异常由 UI 提示。
  Future<User> updateProfile({String? nickname, String? avatarUrl, String? bio}) async {
    final user = state.user;
    if (user == null) throw StateError('未登录');
    final updated = await ref.read(authRepositoryProvider).updateProfile(
          nickname: nickname ?? user.nickname,
          bio: bio ?? user.bio,
          avatarUrl: avatarUrl ?? user.avatarUrl,
        );
    state = AuthState(user: updated, token: state.token);
    return updated;
  }

  /// 重置密码后强制登出（P05）
  void forceLogout() {
    state = const AuthState();
  }
}
