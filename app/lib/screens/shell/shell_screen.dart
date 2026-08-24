import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../providers/data_providers.dart';
import 'app_bottom_nav.dart';

/// 主框架（P10）：StatefulShellRoute.indexedStack 容器
class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SketchPaper(child: navigationShell),
      bottomNavigationBar: AppBottomNav(
        currentIndex: navigationShell.currentIndex,
        unreadCount: unread,
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        onAdd: () {
          // 中央 ➕ 浮出记一笔，不切换 Tab
          context.push('/add');
        },
      ),
    );
  }
}
