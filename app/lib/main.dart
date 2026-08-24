import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import 'core/config.dart';
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
