/// 全局配置
///
/// ## Demo 模式如何切换
///
/// 默认开启 Demo 模式（`useMock = true`），所有数据来自内存假数据
/// `lib/data/mock/mock_store.dart`，不需要后端即可完整走通原型页面。
///
/// 切换（两种方式）：
/// 1. 直接改下方常量：把 `defaultValue: true` 改成 `false`；
/// 2. 运行/打包时用 dart-define 覆盖（不改代码）：
///    ```
///    flutter run --dart-define=AA_USE_MOCK=false \
///                --dart-define=AA_API_BASE=http://10.0.2.2:3000/api/v1
///    ```
///
/// ## baseUrl 说明
/// - Android 模拟器访问宿主机：`http://10.0.2.2:3000/api/v1`（默认）
/// - iOS 模拟器/真机 + 本机后端：改成 `http://127.0.0.1:3000/api/v1`
/// - 真机调试（同局域网）：改成 `http://<电脑局域网IP>:3000/api/v1`
abstract final class AppConfig {
  /// 是否使用内存假数据（Demo 模式）。默认 true。
  static const bool useMock = bool.fromEnvironment(
    'AA_USE_MOCK',
    defaultValue: true,
  );

  /// 后端 API 根路径（不含 `/api/docs`）。
  static const String baseUrl = String.fromEnvironment(
    'AA_API_BASE',
    defaultValue: 'http://10.0.2.2:3000/api/v1',
  );

  /// 登录成功后是否自动进入已登录 Demo 会话。
  /// 仅 Demo 模式生效：true 时启动页直接进入主框架（方便演示/测试），
  /// false 时先到登录页。
  static const bool mockAutoLogin = bool.fromEnvironment(
    'AA_MOCK_AUTO_LOGIN',
    defaultValue: true,
  );

  /// App 名称
  static const String appName = 'AA分账';

  /// 版本号（与 pubspec.yaml `version: 1.0.4+2005` 的版本名部分完全一致；
  /// 由 test/version_consistency_test.dart 强制校验，改 pubspec 需同步此处）
  static const String appVersion = '1.0.4';

  /// 构建版本号（与 pubspec.yaml `version: 1.0.4+2005` 的 +build 部分完全一致）
  static const String appBuildNumber = '2005';

  /// 极光推送 AppKey（客户端公开值；测试包可 --dart-define=AA_JPUSH_APP_KEY= 覆盖）
  static const String jpushAppKey = String.fromEnvironment(
    'AA_JPUSH_APP_KEY',
    defaultValue: 'aadc425dd712362a851cf69a',
  );

  /// 邀请链接前缀（P22 深链：`aafen://join/群码`）
  static const String inviteScheme = 'aafen://join/';
}
