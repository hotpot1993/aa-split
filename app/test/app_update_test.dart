// 检查更新模块回归：版本比较 / Demo 模式 check / hasUpdate 判定
import 'package:aa_split_app/core/config.dart';
import 'package:aa_split_app/core/update/app_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('compareVersions', () {
    test('相同版本返回 0', () {
      expect(compareVersions('1.0.3', '1.0.3'), 0);
      expect(compareVersions('1.0.3', '1.0.3.0'), 0);
    });

    test('新版本大于旧版本', () {
      expect(compareVersions('1.0.4', '1.0.3'), 1);
      expect(compareVersions('1.0.10', '1.0.9'), 1);
      expect(compareVersions('1.1.0', '1.0.99'), 1);
      expect(compareVersions('2.0.0', '1.99.99'), 1);
    });

    test('旧版本小于新版本', () {
      expect(compareVersions('1.0.3', '1.0.4'), -1);
    });

    test('带构建号的字符串也能比较', () {
      expect(compareVersions('1.0.3+2004', '1.0.3+2005'), -1);
    });
  });

  group('AppUpdateRepository（Demo 模式）', () {
    test('mock 下 check 返回当前版本（视为最新）', () async {
      final repo = AppUpdateRepository();
      final info = await repo.check();
      expect(info.latestVersion, AppConfig.appVersion);
      expect(info.latestBuild, int.parse(AppConfig.appBuildNumber));
      expect(repo.hasUpdate(info), isFalse);
    });
  });

  group('hasUpdate 判定', () {
    final repo = AppUpdateRepository();

    test('服务端构建号更高 → 有更新', () {
      final cur = int.parse(AppConfig.appBuildNumber);
      expect(
        repo.hasUpdate(AppVersionInfo(
          latestVersion: AppConfig.appVersion,
          latestBuild: cur + 1,
          downloadUrl: 'https://example.com/a.apk',
          notes: '',
        )),
        isTrue,
      );
    });

    test('服务端构建号相同 → 无更新', () {
      final cur = int.parse(AppConfig.appBuildNumber);
      expect(
        repo.hasUpdate(AppVersionInfo(
          latestVersion: AppConfig.appVersion,
          latestBuild: cur,
          downloadUrl: '',
          notes: '',
        )),
        isFalse,
      );
    });

    test('服务端仅配了版本名且更高 → 有更新', () {
      final cur = int.parse(AppConfig.appBuildNumber);
      expect(
        repo.hasUpdate(AppVersionInfo(
          latestVersion: '99.0.0',
          latestBuild: cur, // 构建号未升，靠版本名兜底
          downloadUrl: '',
          notes: '',
        )),
        isTrue,
      );
    });
  });
}
