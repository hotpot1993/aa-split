import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P51 设置页
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final themeMode = ref.watch(themeModeProvider);
    final modeCtrl = ref.read(themeModeProvider.notifier);

    return AaScaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _Group(title: '通用'),
          _Row(
            icon: Icons.notifications,
            emoji: '🔔',
            label: '通知设置',
            onTap: () => context.push('/messages/settings'),
          ),
          _Row(
            icon: Icons.dark_mode,
            emoji: '🌙',
            label: '深色模式',
            trailing: _ModeSelector(
              value: themeMode,
              onChanged: (m) => modeCtrl.set(m),
            ),
          ),
          _Row(
            icon: Icons.lock,
            emoji: '🔒',
            label: '账号安全',
            onTap: () => context.push('/security'),
          ),
          _Row(
            icon: Icons.download,
            emoji: '📦',
            label: '数据导出',
            onTap: () => context.push('/export'),
          ),
          _Group(title: '其他'),
          _Row(
            icon: Icons.info,
            emoji: 'ℹ️',
            label: '关于',
            onTap: () => context.push('/about'),
          ),
          _Group(title: '账户'),
          const SizedBox(height: 8),
          DoodleButton(
            label: '下次再来玩呀（退出登录）',
            type: DoodleButtonType.secondary,
            color: AAColors.berry,
            textColor: AAColors.berry,
            expand: true,
            onPressed: () => _logout(context, ref),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('退出后本地登录态会清除', style: text.bodySmall),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showAaConfirm(
      context,
      title: '要退出登录吗？',
      subtitle: '账都记得好好的，随时回来',
      confirmLabel: '退出',
    );
    if (ok == true) {
      ref.read(authProvider.notifier).logout();
      if (!context.mounted) return;
      showAaToast(context, '已退出，下次再来呀');
      context.go('/login');
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text('— $title —',
          style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 14, color: AAColors.inkSoft)),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.emoji, required this.label, this.onTap, this.trailing});
  final IconData icon;
  final String emoji;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: PaperCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: text.titleMedium)),
            trailing ?? const Icon(Icons.arrow_forward, color: AAColors.inkSoft, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.value, required this.onChanged});
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;
  @override
  Widget build(BuildContext context) {
    final items = [
      (ThemeMode.system, '跟随系统'),
      (ThemeMode.light, '浅色'),
      (ThemeMode.dark, '深色'),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: items
          .map((it) => GestureDetector(
                onTap: () => onChanged(it.$1),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: value == it.$1 ? AAColors.lemon.withValues(alpha: 0.5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(it.$2,
                      style: TextStyle(
                          fontFamily: 'ZCOOLKuaiLe',
                          fontSize: 12,
                          color: value == it.$1 ? AAColors.coral : AAColors.inkSoft)),
                ),
              ))
          .toList(),
    );
  }
}
