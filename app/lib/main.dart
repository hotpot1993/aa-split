import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import 'core/config.dart';
import 'core/jpush/jpush_bridge.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_stream_provider.dart';
import 'providers/settings_provider.dart';
import 'router/app_router.dart';

void main() {
  runApp(const ProviderScope(child: AaSplitApp()));
}

/// 根 Widget：ProviderScope + MaterialApp.router（主题随系统深浅色）
class AaSplitApp extends ConsumerStatefulWidget {
  const AaSplitApp({super.key});

  @override
  ConsumerState<AaSplitApp> createState() => _AaSplitAppState();
}

class _AaSplitAppState extends ConsumerState<AaSplitApp> {
  late final GoRouter _router = buildRouter();

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
      theme: aaTheme,
      darkTheme: buildAaTheme(brightness: Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: _router,
    );
  }
}
