import '../../core/api/api_client.dart';
import '../../core/config.dart';

/// 服务端返回的最新版本信息（GET /app/version，公开接口）。
class AppVersionInfo {
  const AppVersionInfo({
    required this.latestVersion,
    required this.latestBuild,
    required this.downloadUrl,
    required this.notes,
  });

  final String latestVersion;
  final int latestBuild;
  final String downloadUrl;
  final String notes;

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) => AppVersionInfo(
        latestVersion: json['latestVersion'] as String? ?? AppConfig.appVersion,
        latestBuild:
            (json['latestBuild'] as num?)?.toInt() ?? int.parse(AppConfig.appBuildNumber),
        downloadUrl: json['downloadUrl'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}

/// 语义化版本比较：'1.0.3' vs '1.0.10' → -1（a 更旧）。
/// 返回 -1 / 0 / 1；格式非法时按字符串比较兜底。
int compareVersions(String a, String b) {
  List<int> parse(String s) {
    final parts = s.split(RegExp(r'[.\-+]'));
    final nums = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null) return const [];
      nums.add(n);
    }
    return nums;
  }

  final pa = parse(a);
  final pb = parse(b);
  if (pa.isEmpty || pb.isEmpty) return a.compareTo(b);
  for (var i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

/// 升级检查仓库：真实模式走 GET /app/version；
/// Demo 模式（无服务端）返回「当前版本即为最新」的占位信息。
class AppUpdateRepository {
  AppUpdateRepository();

  Future<AppVersionInfo> check() async {
    if (AppConfig.useMock) {
      return AppVersionInfo(
        latestVersion: AppConfig.appVersion,
        latestBuild: int.parse(AppConfig.appBuildNumber),
        downloadUrl: '',
        notes: '',
      );
    }
    final res = await ApiClient.instance.get('/app/version');
    final data = res.data is Map ? (res.data as Map).cast<String, dynamic>() : const <String, dynamic>{};
    return AppVersionInfo.fromJson(data);
  }

  /// 是否有可升级的新版本（构建号优先，版本名兜底）
  bool hasUpdate(AppVersionInfo info) {
    final currentBuild = int.parse(AppConfig.appBuildNumber);
    if (info.latestBuild > currentBuild) return true;
    return compareVersions(info.latestVersion, AppConfig.appVersion) > 0;
  }
}
