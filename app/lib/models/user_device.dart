/// 登录设备（P52 账号安全）—— 服务端 UserDevice / `auth/devices` 系列接口
class UserDevice {
  const UserDevice({
    required this.id,
    required this.deviceId,
    this.platform = '',
    this.deviceName = '',
    this.osVersion = '',
    this.ip,
    this.lastLoginAt,
  });

  final String id;
  final String deviceId;
  final String platform;
  final String deviceName;
  final String osVersion;
  final String? ip;
  final DateTime? lastLoginAt;

  /// 展示名（空机型兜底）
  String get label => deviceName.trim().isEmpty ? platform : deviceName.trim();

  factory UserDevice.fromJson(Map<String, dynamic> json) => UserDevice(
        id: (json['id'] ?? '').toString(),
        deviceId: (json['deviceId'] ?? '').toString(),
        platform: (json['platform'] ?? '').toString(),
        deviceName: (json['deviceName'] ?? '').toString(),
        osVersion: (json['osVersion'] ?? '').toString(),
        ip: json['ip']?.toString(),
        lastLoginAt: json['lastLoginAt'] != null
            ? DateTime.tryParse(json['lastLoginAt'].toString())
            : null,
      );

  /// 上报给服务端的设备快照
  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'platform': platform,
        'deviceName': deviceName,
        'osVersion': osVersion,
      };
}
