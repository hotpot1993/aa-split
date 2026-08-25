import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import 'core/config.dart';
import 'core/jpush/jpush_bridge.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_stream_provider.dart';
import 'providers/settings_provider.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 恢复字体风格偏好（设置页「字体风格」），在首帧前生效避免风格跳变
  await FontStyleStore.init();
  // 纸米浅色底 → 状态栏/导航栏使用深色图标（避免系统深色模式下白图标看不清）
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const ProviderScope(child: AaSplitApp()));
}

/// 根 Widget：ProviderScope + MaterialApp.router（主题随系统深浅色）
class AaSplitApp extends ConsumerStatefulWidget {
  const AaSplitApp({super.key});

  @override
  ConsumerState<AaSplitApp> createState() => _AaSplitAppState();
}

class _AaSplitAppState extends ConsumerState<AaSplitApp> {
  late final GoRouter _router = buildRouter(ref);

  @override
  void initState() {
    super.initState();
    // 极光通知点击 → 跳转对应业务页（等首帧后路由就绪；未登录忽略）
    JpushBridge.setOpenHandler(open: (refType, refId) {
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        if (!mounted || refId.isEmpty) return;
        if (!ref.read(authProvider).isLoggedIn && !AppConfig.useMock) return;
        switch (refType) {
          case 'bill':
            _router.push('/bills/$refId');
          case 'group':
            _router.push('/groups/$refId');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // 保持实时通知流随登录态常驻（真实模式 SSE；Demo 模式空流）
    ref.watch(notificationStreamProvider);
    // 字体风格（设置页切换）：先全局生效，再按当前风格构建主题。
    // key 随风格变化 → 整棵 widget 树重建，保证已挂载页面（首页/各 Tab 等）
    // 的文本立即按新字体家族重绘（依赖 Theme 级联在已冻结路由上并不可靠）。
    // GoRouter 状态由 _router 持有，重建后仍在当前页面，路由栈不变。
    final fontStyle = ref.watch(fontStyleProvider);
    AAFonts.useStyle(fontStyle);
    return MaterialApp.router(
      key: ValueKey(fontStyle),
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      // 主题固定为浅色（Demo 唯一设计基准），不提供深色模式
      theme: buildAaTheme(),
      routerConfig: _router,
    );
  }
}
