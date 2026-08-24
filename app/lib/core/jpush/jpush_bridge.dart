import 'package:flutter/foundation.dart';
import 'package:jpush_flutter/jpush_flutter.dart';

/// 极光推送桥接（免费版，jpush_flutter 3.5.5）：
/// - 登录/恢复会话后 init(appKey) + setAlias(userId)（服务端按 alias 推送）
/// - 退出登录清 alias
/// - 点击通知：按 extras.refType/refId 回调上层路由跳转
///
/// 限制：未配置厂商通道，App 进程被系统杀掉后离线通知不可达；
/// 前台/短后台由 SDK 长连接（Android 默认保持）覆盖。
class JpushBridge {
  JpushBridge._();

  // JPushFlutterInterface 未在包外导出，用工厂方法推断类型
  static final _jpush = JPush.newJPush();
  static bool _inited = false;

  /// 登录后调用；绑定 alias（通知权限由极光 SDK 在 setup 时自动申请/校验）
  static Future<void> init({required String appKey, required String userId}) async {
    if (_inited) return;
    try {
      _jpush.setup(appKey: appKey, channel: 'default', production: false, debug: kDebugMode);
      _inited = true;
      // 前台也展示系统通知（默认前台仅回调/InApp）
      _jpush.setUnShowAtTheForeground(unShow: false);
      // 极光 alias 规则更宽松但稳妥起见：纯字母数字（UUID 去连字符）
      await _jpush.setAlias(userId.replaceAll('-', ''));
      debugPrint('JPush: alias=$userId regId=${await _jpush.getRegistrationID()}');
    } catch (e) {
      debugPrint('JPush init error: $e');
    }
  }

  /// 退出登录：清除 alias（服务端按 alias 推送不再命中该设备）
  static Future<void> clearAlias() async {
    try {
      await _jpush.deleteAlias();
    } catch (e) {
      debugPrint('JPush clearAlias error: $e');
    }
  }

  /// 注册点击通知回调；[open] 传入 refType/refId
  static void setOpenHandler({required void Function(String refType, String refId) open}) {
    _jpush.addEventHandler(
      onOpenNotification: (event) async => _handle(event, open),
      onReceiveNotification: (event) async => _handle(event, open),
      onReceiveMessage: (event) async {},
    );
  }

  static Map<String, dynamic> _asMap(dynamic v) => v is Map
      ? v.cast<String, dynamic>()
      : const <String, dynamic>{};

  static void _handle(
    Map<String, dynamic> event,
    void Function(String, String) open,
  ) {
    // 极光 Android 事件 map：extras 里含 cn.jpush.android.EXTRA 嵌套（refType/refId）
    var extras = event['extra'] ?? event['extras'];
    if (extras is Map) {
      final inner = _asMap(extras)['cn.jpush.android.EXTRA'];
      if (inner is Map) extras = inner;
    } else {
      final android = event['android'];
      extras = _asMap(android)['extras'];
    }
    final map = _asMap(extras);
    final refType = (map['refType'] ?? '').toString();
    final refId = (map['refId'] ?? '').toString();
    if (refType.isNotEmpty && refId.isNotEmpty) {
      open(refType, refId);
    }
  }
}
