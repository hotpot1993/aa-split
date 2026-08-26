import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/config.dart';
import '../../core/update/app_update.dart';
import '../../providers/data_providers.dart';
import '../../widgets/sheet.dart';
import 'app_bottom_nav.dart';

/// 主框架（P10）：StatefulShellRoute.indexedStack 容器
///
/// 返回键行为（Android 规范）：
/// - 群组 / 消息 / 我的 等非首页 Tab → 返回首页 Tab；
/// - 首页 → 2 秒内连按两次返回 → 退出应用（首次提示）。
class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen> {
  /// 首页最近一次返回键按下时间（双击退出用）
  DateTime? _lastBackAt;

  @override
  void initState() {
    super.initState();
    _maybePromptUpdate();
  }

  /// 启动静默检查更新：延迟 2s 后查一次（真实模式、每个新版本只提示一次），
  /// 用户可从弹窗进入「关于页」完成下载/安装；失败静默不打扰。
  Future<void> _maybePromptUpdate() async {
    if (AppConfig.useMock) return;
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final repo = AppUpdateRepository();
      final info = await repo.check();
      if (!repo.hasUpdate(info)) return;
      final prefs = await SharedPreferences.getInstance();
      final key = 'prompt_update_${info.latestVersion}_${info.latestBuild}';
      if (prefs.getBool(key) ?? false) return;
      await prefs.setBool(key, true);
      if (!mounted) return;
      final go = await showAaConfirm(
        context,
        title: '发现新版本 v${info.latestVersion}',
        subtitle: '本次更新:${info.notes.isEmpty ? '体验优化与修复' : info.notes}',
        confirmLabel: '去查看',
        showMascot: false,
      );
      if (go == true && mounted) context.push('/about');
    } catch (_) {
      // 静默检查失败不影响正常使用
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (widget.navigationShell.currentIndex != 0) {
          // 非首页 Tab → 回首页，而不是退出应用
          widget.navigationShell.goBranch(0);
          return;
        }
        _handleHomeBack();
      },
      child: Scaffold(
        backgroundColor: AAColors.paper,
        body: SketchPaper(child: widget.navigationShell),
        bottomNavigationBar: AppBottomNav(
          currentIndex: widget.navigationShell.currentIndex,
          unreadCount: unread,
          onTap: (index) => widget.navigationShell.goBranch(
            index,
            initialLocation: index == widget.navigationShell.currentIndex,
          ),
          onAdd: () {
            // 中央 ➕ 浮出记一笔，不切换 Tab
            context.push('/add');
          },
        ),
      ),
    );
  }

  /// 首页：2 秒内连按两次返回 → 退出应用；首次提示
  void _handleHomeBack() {
    final now = DateTime.now();
    final last = _lastBackAt;
    if (last != null && now.difference(last).inSeconds < 2) {
      SystemNavigator.pop();
      return;
    }
    _lastBackAt = now;
    showAaToast(context, '再按一次返回键退出应用');
  }
}
