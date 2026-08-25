import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/api/codec.dart';
import '../../core/config.dart';
import '../../core/device_info.dart';
import '../../models/user.dart';
import '../../models/user_device.dart';
import '../mock/mock_store.dart';

/// 认证相关异常（携带用户可读文案，用于行内红章/Toast）
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 认证/账户仓库。
/// Demo 模式走 MockStore；真实模式（AA_USE_MOCK=false）调用服务端 /auth/*，
/// token 与用户信息持久化到 SharedPreferences（app 重启后仍登录）。
class AuthRepository {
  AuthRepository();

  static const _kToken = 'aa.token';
  static const _kUser = 'aa.user';

  /// 注册后由 forgot/verify 存入的 resetToken（内存态，10 分钟有效由服务端把关）
  String? _resetToken;

  /// 恢复登录态（启动页判断用）。
  User? restoreSessionSync() {
    if (AppConfig.useMock) return MockStore.instance.currentUser;
    return null; // 真实模式需 async：restoreSession()
  }

  /// 真实模式：从本地存储恢复。已登录返回 User，否则 null。
  Future<User?> restoreSession() async {
    if (AppConfig.useMock) return MockStore.instance.currentUser;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kToken);
      final userJson = prefs.getString(_kUser);
      if (token == null || userJson == null) return null;
      ApiClient.instance.setToken(token);
      // 以服务端资料为准；失败（401 等）则清除本地态
      try {
        final res = await ApiClient.instance.get('/auth/me');
        final user = parseUser(res.data);
        await _saveSession(token, user);
        return user;
      } catch (e) {
        // 仅 token 无效(401)时清除本地会话；网络异常保留，避免弱网误清
        if (e is ApiException && e.code == 401) await _clearSession();
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  /// 登录
  Future<User> login(String accountName, String password) async {
    if (AppConfig.useMock) {
      final name = accountName.trim();
      if (name.isEmpty) throw const AuthException('先输入账户名呀');
      if (password.isEmpty) throw const AuthException('密码不能为空');
      if (!_accountExists(name)) {
        throw const AuthException('账户不存在，请注册');
      }
      return MockStore.instance.currentUser;
    }
    try {
      final res = await ApiClient.instance.post('/auth/login', body: {
        'accountName': accountName.trim(),
        'password': password,
        // 真实设备信息（登录即记录设备，P52 登录设备列表）
        'deviceInfo': (await DeviceInfoService.current()).toJson(),
      });
      final data = res.data as Map? ?? const {};
      final token = (data['accessToken'] ?? '').toString();
      final user = parseUser(data['user']);
      ApiClient.instance.setToken(token);
      await _saveSession(token, user);
      return user;
    } on ApiException catch (e) {
      // 服务端提示（如「账户名或密码错误」）原样透出给用户
      throw AuthException(e.message);
    }
  }

  /// 注册
  Future<User> register({
    required String accountName,
    required String password,
    required String nickname,
    required String securityQuestion,
    required String securityAnswer,
  }) async {
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
    try {
      final res = await ApiClient.instance.post('/auth/register', body: {
        'accountName': accountName.trim(),
        'password': password,
        if (nickname.isNotEmpty) 'nickname': nickname,
        'securityQuestion': securityQuestion,
        'securityAnswer': securityAnswer,
        // 真实设备信息（注册即记录设备，P52 登录设备列表）
        'deviceInfo': (await DeviceInfoService.current()).toJson(),
      });
      final data = res.data as Map? ?? const {};
      final token = (data['accessToken'] ?? '').toString();
      final user = parseUser(data['user']);
      ApiClient.instance.setToken(token);
      await _saveSession(token, user);
      return user;
    } on ApiException catch (e) {
      // 服务端提示（如「账户名已被占用」「密码至少6位…」）原样透出给用户
      throw AuthException(e.message);
    }
  }

  /// 账户名唯一性校验（注册实时）。
  Future<bool> isAccountAvailable(String accountName) async {
    if (AppConfig.useMock) return !_accountExists(accountName);
    try {
      final res = await ApiClient.instance
          .get('/users/search', query: {'accountName': accountName.trim()});
      final list = res.data is List ? res.data as List : const [];
      return list.isEmpty;
    } catch (_) {
      return true; // 搜索不可用时放行，提交时服务端兜底校验
    }
  }

  /// 忘记密码：查询安全问题（P04）。真实模式 GET /auth/security-question。
  Future<String> securityQuestionOf(String accountName) async {
    if (AppConfig.useMock) {
      final q = MockStore.instance.currentUser.securityQuestion;
      return q.isEmpty ? '你第一个朋友的名字？' : q;
    }
    if (accountName.trim().isEmpty) {
      throw const AuthException('先输入账户名呀');
    }
    final res = await ApiClient.instance.get(
      '/auth/security-question',
      query: {'accountName': accountName.trim()},
    );
    final data = res.data as Map? ?? const {};
    return (data['question'] ?? '').toString();
  }

  /// 验证安全问题（true=通过）
  Future<bool> verifySecurityQuestion(String accountName, String answer) async {
    if (AppConfig.useMock) return answer.trim().isNotEmpty;
    final res = await ApiClient.instance.post('/auth/forgot/verify', body: {
      'accountName': accountName.trim(),
      'securityAnswer': answer.trim(),
    });
    final data = res.data as Map? ?? const {};
    _resetToken = (data['resetToken'] ?? '').toString();
    return _resetToken!.isNotEmpty;
  }

  /// 重置密码（P05；真实模式使用 verify 阶段取得的 resetToken）
  Future<void> resetPassword(String accountName, String newPassword) async {
    if (AppConfig.useMock) return;
    if (_resetToken == null || _resetToken!.isEmpty) {
      throw const AuthException('安全验证已过期，请重新验证');
    }
    await ApiClient.instance.post('/auth/forgot/reset', body: {
      'resetToken': _resetToken,
      'newPassword': newPassword,
    });
    _resetToken = null;
  }

  /// 修改密码（P52）
  Future<void> changePassword(String current, String next) async {
    if (AppConfig.useMock) {
      if (current.isEmpty) throw const AuthException('请输入当前密码');
      return;
    }
    await ApiClient.instance.post('/auth/change-password', body: {
      'currentPassword': current,
      'newPassword': next,
    });
  }

  /// 更新个人资料（P50）：真实模式 PATCH /auth/me，成功后同步本地会话。
  Future<User> updateProfile({
    required String nickname,
    required String bio,
    String? avatarUrl,
  }) async {
    if (AppConfig.useMock) {
      final updated = MockStore.instance.currentUser.copyWith(
        nickname: nickname,
        avatarUrl: avatarUrl,
        bio: bio,
      );
      MockStore.instance.currentUser = updated;
      return updated;
    }
    final body = <String, dynamic>{
      'nickname': nickname,
      'bio': bio,
    };
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
    final res = await ApiClient.instance.patch('/auth/me', body: body);
    final user = parseUser(res.data);
    // 只刷新本地 user 缓存，不动认证 token（当前会话以 ApiClient 持有者为准；
    // 避免从 prefs 取「可能是另一个会话」的 token 回填导致会话被切走）
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
    return user;
  }

  /// 退出登录
  Future<void> logout() async {
    if (AppConfig.useMock) return;
    ApiClient.instance.setToken(null);
    await _clearSession();
  }

  /// 注销账号（商店合规：应用内删除账号）。
  /// 服务端软删除 + 匿名化；成功后清空本地会话（旧 token 服务端已失效）。
  Future<void> deleteAccount() async {
    if (AppConfig.useMock) {
      await logout();
      return;
    }
    await ApiClient.instance.delete('/auth/me');
    ApiClient.instance.setToken(null);
    await _clearSession();
  }

  // ---------- 登录设备（P52 账号安全：真实数据） ----------

  /// 登录设备列表：先上报当前设备（幂等）再拉取，保证本机始终真实在列。
  /// 上报失败不阻塞列表（登录时已记录过当前设备）。
  Future<List<UserDevice>> listDevices() async {
    if (AppConfig.useMock) return List.of(MockStore.instance.devices);
    final me = await DeviceInfoService.current();
    try {
      await ApiClient.instance.post('/auth/devices', body: me.toJson());
    } catch (_) {
      // 忽略：展示列表优先；当前设备在登录时已上报
    }
    final res = await ApiClient.instance.get('/auth/devices');
    final list = res.data is List ? res.data as List : const [];
    return list
        .map((e) => UserDevice.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// 退出指定设备（服务端幂等；当前设备也可调用，下次登录会重新记录）
  Future<void> removeDevice(String deviceId) async {
    if (AppConfig.useMock) {
      MockStore.instance.devices.removeWhere((d) => d.deviceId == deviceId);
      return;
    }
    await ApiClient.instance.delete('/auth/devices/$deviceId');
  }

  Future<void> _saveSession(String token, User user) async {
    ApiClient.instance.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUser, jsonEncode(user.toJson()));
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
  }

  bool _accountExists(String name) {
    final me = MockStore.instance.currentUser;
    return name.toLowerCase() == me.accountName.toLowerCase() ||
        name.toLowerCase() == me.nickname.toLowerCase();
  }
}
