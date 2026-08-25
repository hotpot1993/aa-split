import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_device.dart';

/// 设备快照采集 —— 登录/注册与「账号安全」页向服务端上报真实设备信息：
/// - deviceId：本地持久化生成的设备标识（唯一标识本机，跨启动不变）
/// - deviceName / platform / osVersion：机型（如 Xiaomi 2509FPN0BC）/ 系统 / 版本
///
/// 插件不可用（如 flutter_test 无原生通道）时优雅降级为 dart:io 平台信息。
abstract final class DeviceInfoService {
  static const _kDeviceId = 'aa.deviceId';

  /// 当前设备快照
  static Future<UserDevice> current() async {
    final deviceId = await _ensureDeviceId();
    var platform = Platform.operatingSystem;
    var name = Platform.operatingSystem;
    var os = Platform.operatingSystemVersion;
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        name = '${a.brand} ${a.model}'.trim();
        os = a.version.release;
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        name = i.utsname.machine;
        os = i.systemVersion;
      }
    } catch (_) {
      // 测试环境/插件缺失：保留平台级信息
    }
    return UserDevice(
      id: '',
      deviceId: deviceId,
      platform: platform.length > 16 ? platform.substring(0, 16) : platform,
      deviceName: name.length > 64 ? name.substring(0, 64) : name,
      osVersion: os.length > 32 ? os.substring(0, 32) : os,
    );
  }

  /// 取（或生成）持久化设备标识
  static Future<String> _ensureDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kDeviceId);
      if (saved != null && saved.isNotEmpty) return saved;
      final id = _randomId();
      await prefs.setString(_kDeviceId, id);
      return id;
    } catch (_) {
      return _randomId();
    }
  }

  static String _randomId() {
    final rnd = Random.secure();
    final hex =
        List.generate(24, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return 'd-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-$hex';
  }
}
