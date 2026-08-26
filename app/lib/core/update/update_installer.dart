import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// APK 下载 + 调起系统安装器。
/// 下载至应用专属外部目录（无需存储权限）；安装由 open_filex 通过
/// FileProvider 发起 ACTION_VIEW，系统要求用户在「安装未知应用」中授权
/// （Manifest 已声明 REQUEST_INSTALL_PACKAGES）。
class UpdateInstaller {
  UpdateInstaller({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// 下载并返回本地 APK 路径（供安装器使用/测试断言）。
  Future<String> download(
    String url,
    String fileName, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getExternalStorageDirectory() ??
        await getTemporaryDirectory();
    final target = File('${dir.path}/$fileName');
    await _dio.download(
      url,
      target.path,
      cancelToken: cancelToken,
      options: Options(
        headers: const {'Accept': 'application/vnd.android.package-archive'},
        followRedirects: true,
      ),
      onReceiveProgress: (received, total) {
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );
    return target.path;
  }

  /// 调起系统安装器（Android：ARRAY_VIEW + FileProvider；iOS 不支持 APK）。
  Future<void> install(String apkPath) async {
    final result = await OpenFilex.open(apkPath, type: 'application/vnd.android.package-archive');
    if (result.type != ResultType.done) {
      throw StateError('调用安装器失败: ${result.message}');
    }
  }
}
