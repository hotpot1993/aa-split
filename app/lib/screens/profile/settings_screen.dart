import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P51 设置页 —— 对齐 docs/ui-demo/index.html
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fontStyle = ref.watch(fontStyleProvider);
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
                _row('字体风格',
                    leadImage: 'assets/icons/notebook.png',
                    value: fontStyle.label,
                    trailing: const _Arrow(),
                    onTap: () => _pickFontStyle(context, ref)),
                _row('通知设置',
                    leadImage: 'assets/icons/notify.png',
                    trailing: const _Arrow(),
                    onTap: () => context.push('/messages/settings')),
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
          SizedBox(height: 16),
          DoodleButton(
            label: '退出登录',
            type: DoodleButtonType.danger,
            big: true,
            onPressed: () => _logout(context, ref),
          ),
          SizedBox(height: 8),
          Center(
            child: Text('退出后本地登录态会清除',
                style: TextStyle(fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
          ),
          SizedBox(height: 16),
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
                      SizedBox(width: 6),
                    ],
                    Text(label,
                        style: TextStyle(
                            fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
                  ],
                ),
                if (value != null)
                  Text(value,
                      style: TextStyle(
                          fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                ?trailing,
              ],
            ),
          ),
        ),
        if (showBorder)
          CustomPaint(size: Size(double.infinity, 2.5), painter: _SetDash()),
      ],
    );
  }

  Future<void> _pickFontStyle(BuildContext context, WidgetRef ref) async {
    final current = ref.read(fontStyleProvider);
    final picked = await showAaSheet<AaFontStyle>(
      context,
      child: _FontStylePicker(selected: current),
    );
    if (picked == null || picked == current || !context.mounted) return;
    await ref.read(fontStyleProvider.notifier).setStyle(picked);
    if (!context.mounted) return;
    showAaToast(context, '已切换到「${picked.label}」');
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
    return Text('→', style: TextStyle(fontSize: 15, color: AAColors.ink));
  }
}

/// 字体风格选择弹层：两种风格各一张卡片（标题/说明 + 实时预览）
class _FontStylePicker extends StatelessWidget {
  const _FontStylePicker({required this.selected});

  final AaFontStyle selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('字体风格',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('选择后立即生效，所有页面跟着换',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
        const SizedBox(height: 16),
        for (final style in AaFontStyle.values) ...[
          _StyleCard(
            style: style,
            selected: style == selected,
            onTap: () => Navigator.of(context).pop(style),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
      ],
    );
  }
}

/// 单个风格选项卡片：以该风格的字体渲染预览（金额 + 正文），选中态描边高亮
class _StyleCard extends StatelessWidget {
  const _StyleCard({required this.style, required this.selected, required this.onTap});

  final AaFontStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 预览固定使用「该风格」对应的字体家族（不随全局切换变化）
    final bodyFamily = style == AaFontStyle.hand ? AAFonts.titleHand : AAFonts.bodyStandard;
    final amountFamily = style == AaFontStyle.hand ? AAFonts.amountHand : AAFonts.amountStandard;
    return PaperCard(
      onTap: onTap,
      color: selected ? AAColors.paperDeep : AAColors.cardWhite,
      borderColor: selected ? AAColors.mint : AAColors.ink,
      borderWidth: selected ? 3 : AATokens.stroke,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(style.label,
                  style: TextStyle(fontFamily: bodyFamily, fontSize: 16, color: AAColors.ink)),
              if (selected) ...[
                const SizedBox(width: 6),
                AaIconImage('assets/icons/check.png', size: 11),
                SizedBox(width: 3),
                Text('当前使用',
                    style: TextStyle(
                        fontFamily: bodyFamily, fontSize: 11, color: AAColors.mint)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(style.description,
              style: TextStyle(
                  fontFamily: bodyFamily, fontSize: 12, color: AAColors.inkSoft, height: 1.4)),
          const SizedBox(height: 10),
          // 预览：金额保留小数 + 一行正文（¥ 统一 JetBrains Mono，数字用该风格字体）
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '¥ ',
                    style: TextStyle(
                        fontFamily: AAFonts.currency,
                        fontSize: 14,
                        color: AAColors.coral,
                        height: 1.1),
                  ),
                  TextSpan(
                    text: '1,024.50',
                    style: TextStyle(
                        fontFamily: amountFamily,
                        fontSize: 22,
                        color: AAColors.coral,
                        height: 1.1),
                  ),
                ]),
              ),
              const SizedBox(width: 8),
              Text('周末露营 4 人 AA 账单',
                  style: TextStyle(fontFamily: bodyFamily, fontSize: 13, color: AAColors.ink)),
            ],
          ),
        ],
      ),
    );
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
