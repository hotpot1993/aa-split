import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P51 设置页 —— 对齐 docs/ui-demo/index.html
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AaScaffold(
      appBar: AaAppBar(
        title: '设置',
        headIcon: 'assets/icons/settings.png',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                _row('通知设置',
                    leadImage: 'assets/icons/notify.png',
                    trailing: const _Arrow(),
                    onTap: () => context.push('/messages/settings')),
                _row('隐私设置',
                    leadImage: 'assets/icons/locked.png',
                    value: '账单仅参与者可见 ▾'),
                _row('账号安全',
                    leadImage: 'assets/icons/key.png',
                    trailing: const _Arrow(),
                    onTap: () => context.push('/security')),
                _row('数据导出',
                    leadImage: 'assets/icons/export.png',
                    trailing: const _Arrow(),
                    onTap: () => context.push('/export')),
                _row('关于我们',
                    leadImage: 'assets/icons/mail.png',
                    trailing: const _Arrow(),
                    onTap: () => context.push('/about'),
                    showBorder: false),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DoodleButton(
            label: '退出登录',
            type: DoodleButtonType.danger,
            big: true,
            onPressed: () => _logout(context, ref),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text('退出后本地登录态会清除',
                style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _row(String label,
      {String? value, Widget? trailing, VoidCallback? onTap, String? leadImage, bool showBorder = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (leadImage != null) ...[
                      AaIconImage(leadImage, size: 16),
                      const SizedBox(width: 6),
                    ],
                    Text(label,
                        style: const TextStyle(
                            fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft)),
                  ],
                ),
                if (value != null)
                  Text(value,
                      style: const TextStyle(
                          fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
                ?trailing,
              ],
            ),
          ),
        ),
        if (showBorder)
          CustomPaint(size: const Size(double.infinity, 2.5), painter: _SetDash()),
      ],
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showAaConfirm(
      context,
      title: '要退出登录吗？',
      subtitle: '账都记得好好的，随时回来',
      confirmLabel: '退出',
      // 退出弹窗保持简洁：不展示手绘吉祥物
      showMascot: false,
    );
    if (ok == true) {
      ref.read(authProvider.notifier).logout();
      if (!context.mounted) return;
      showAaToast(context, '已退出，下次再来呀');
      context.go('/login');
    }
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow();
  @override
  Widget build(BuildContext context) {
    return const Text('→', style: TextStyle(fontSize: 15, color: AAColors.ink));
  }
}

class _SetDash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AAColors.ink
      ..strokeWidth = 2.5;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1.25), Offset(x + 7, 1.25), p);
      x += 14;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
