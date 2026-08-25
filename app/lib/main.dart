import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import 'core/config.dart';
import 'core/jpush/jpush_bridge.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_stream_provider.dart';
import 'router/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      // 主题固定为浅色（Demo 唯一设计基准），不提供深色模式
      theme: aaTheme,
      routerConfig: _router,
    );
  }
}
