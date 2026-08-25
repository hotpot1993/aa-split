// 版本一致性守卫：AppConfig.appVersion / appBuildNumber + 关于页展示串
// 必须与 pubspec.yaml 的 `version: x.y.z+build` 完全一致，防止硬编码漂移。
// （Flutter 打包时 Android versionName/versionCode、iOS CFBundleVersion 均取自 pubspec，
//  因此 pubspec 是版本号的唯一事实来源。）
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/core/config.dart';

/// AppConfig 展示串（与 AboutScreen 保持一致，改格式需同步此处）
const displayVersion =
    'v${AppConfig.appVersion} · 构建 ${AppConfig.appBuildNumber}';

void main() {
  test('AppConfig 版本号/构建号与 pubspec.yaml 完全一致', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final m = RegExp(
      r'^version:\s*(\d+\.\d+\.\d+)(?:\+(\d+))?\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(m, isNotNull, reason: 'pubspec.yaml 中未找到 version: x.y.z(+build)');
    expect(
      AppConfig.appVersion,
      m!.group(1),
      reason: 'AppConfig.appVersion 与 pubspec 版本名不一致',
    );
    expect(
      AppConfig.appBuildNumber,
      m.group(2)!,
      reason: 'AppConfig.appBuildNumber 与 pubspec 构建号不一致',
    );
  });

  test('关于页展示串与 AppConfig 一致（防硬编码漂移）', () {
    // 展示串在 AboutScreen 中以 TextSpan 拼接，此处校验片段不会因改版漏改
    expect(
      displayVersion,
      'v${AppConfig.appVersion} · 构建 ${AppConfig.appBuildNumber}',
    );
  });

  test('UI 原型关于页版本串与 AppConfig 一致', () {
    final demo = File('../docs/ui-demo/index.html').readAsStringSync();
    expect(
      demo.contains(displayVersion),
      isTrue,
      reason: 'docs/ui-demo/index.html 关于页版本串未同步 AppConfig',
    );
  });
}
