import '../../core/config.dart';
import '../../models/user.dart';
import '../mock/mock_store.dart';

/// 认证相关异常（携带用户可读文案，用于行内红章/Toast）
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 认证/账户仓库（Demo 模式走 MockStore）。
///
/// 非 Demo 模式：各方法应改为 `async` 并通过 `ApiClient`（lib/core/api/api_client.dart）
/// 调用 `/auth/*` 接口（见技术方案 §4.1）。此处演示骨架直接抛未实现。
class AuthRepository {
  AuthRepository();

  /// 恢复登录态（启动页判断用）。Demo 模式返回当前演示用户。
  User? restoreSession() {
    if (AppConfig.useMock) return MockStore.instance.currentUser;
    throw UnsupportedError('useMock=false：restoreSession 需 async + ApiClient');
  }

  /// 登录
  User login(String accountName, String password) {
    if (AppConfig.useMock) {
      final name = accountName.trim();
      if (name.isEmpty) throw const AuthException('先输入账户名呀');
      if (password.isEmpty) throw const AuthException('密码不能为空');
      if (!_accountExists(name)) {
        throw const AuthException('账户不存在，请注册');
      }
      return MockStore.instance.currentUser;
    }
    throw UnsupportedError('useMock=false：login 需 async + ApiClient');
  }

  /// 注册
  User register({
    required String accountName,
    required String password,
    required String nickname,
    required String securityQuestion,
    required String securityAnswer,
  }) {
    if (AppConfig.useMock) {
      final name = accountName.trim();
      if (name.isEmpty) throw const AuthException('账户名不能为空');
      if (password.length < 6) throw const AuthException('密码至少6位，含字母和数字');
      if (name.toLowerCase() == 'root') throw const AuthException('这个名字被占用啦，换一个试试');
      final user = User(
        id: 'me',
        accountName: name,
        nickname: nickname.isEmpty ? name : nickname,
        avatarUrl: '🐼',
        bio: '新来的小伙伴',
        securityQuestion: securityQuestion,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      MockStore.instance.currentUser = user;
      return user;
    }
    throw UnsupportedError('useMock=false：register 需 async + ApiClient');
  }

  /// 账户名唯一性校验（注册实时）。返回 true 表示可用。
  bool isAccountAvailable(String accountName) => !_accountExists(accountName);

  /// 忘记密码：安全问题
  String securityQuestionOf(String accountName) {
    if (AppConfig.useMock) {
      final q = MockStore.instance.currentUser.securityQuestion;
      return q.isEmpty ? '你第一个朋友的名字？' : q;
    }
    throw UnsupportedError('useMock=false：securityQuestionOf 需 async + ApiClient');
  }

  /// 验证安全问题（true=通过）
  bool verifySecurityQuestion(String accountName, String answer) =>
      answer.trim().isNotEmpty;

  /// 重置密码（P05）
  void resetPassword(String accountName, String newPassword) {
    if (AppConfig.useMock) return;
    throw UnsupportedError('useMock=false：resetPassword 需 async + ApiClient');
  }

  /// 修改密码（P52）
  void changePassword(String current, String next) {
    if (AppConfig.useMock) {
      if (current.isEmpty) throw const AuthException('请输入当前密码');
      return;
    }
    throw UnsupportedError('useMock=false：changePassword 需 async + ApiClient');
  }

  /// 退出登录
  void logout() {
    if (AppConfig.useMock) return;
    throw UnsupportedError('useMock=false：logout 需 async + ApiClient');
  }

  bool _accountExists(String name) {
    final me = MockStore.instance.currentUser;
    return name.toLowerCase() == me.accountName.toLowerCase() ||
        name.toLowerCase() == me.nickname.toLowerCase();
  }
}
