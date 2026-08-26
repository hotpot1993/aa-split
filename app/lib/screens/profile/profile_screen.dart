import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../models/group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P50 个人主页 —— 对齐 docs/ui-demo/index.html
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      // 未登录态（异常进入主框架时的兜底）：提供去登录入口，避免用户被困在空状态
      return AaScaffold(
        appBar: null,
        body: Center(
          child: EmptyState(
            title: '还没登录哦',
            subtitle: '登录后就能看到你的账本和好友啦',
            buttonLabel: '🔑 去登录',
            onButtonTap: () => context.go('/login'),
          ),
        ),
      );
    }
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final bills = ref.watch(billsProvider).value ?? const <Bill>[];
    final totalAA = bills.fold<int>(0, (s, b) => s + b.amountCents);

    return AaScaffold(
      appBar: AaAppBar(
        title: '我的',
        back: false,
        iconImage: 'assets/icons/edit.png',
        onIconTap: () => _editProfile(context, ref),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 头像 + 昵称（Demo：86px 大头像 + 📷 角标 + 22px 昵称 + @账户名）
          SizedBox(height: 6),
          Center(
            child: Column(
              children: [
                GestureDetector(
                  // 点击头像区域 → 更换头像（P50）
                  onTap: () => _changeAvatar(context, ref),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _Wobble(
                        child: SketchAvatar(
                          emoji: user.avatarUrl,
                          size: 86,
                          name: user.nickname,
                          background: Color(0xFFFFF1EA),
                        ),
                      ),
                      Positioned(
                        right: -6,
                        bottom: -2,
                        child: AaIconImage('assets/icons/camera.png', size: 18),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Text(user.nickname,
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 22, color: AAColors.ink)),
                SizedBox(height: 2),
                // 英文点缀（规范 §4 第五级：Caveat 手写体）
                Text('@${user.accountName}',
                    style: TextStyle(
                        fontFamily: AAFonts.accent,
                        fontSize: 15,
                        color: AAColors.inkSoft)),
              ],
            ),
          ),
          SizedBox(height: 16),
          // 数据卡（Demo：三列，中间列左右虚线分隔）
          PaperCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: _StatCell(value: '${groups.length}', label: '群组', size: 26)),
                Expanded(
                  child: CustomPaint(
                    painter: _DashedVerticalsPainter(),
                    child: _StatCell(value: '${bills.length}', label: '账单', size: 26),
                  ),
                ),
                Expanded(child: _StatCell(value: Fmt.yuan(totalAA, trimZero: true), label: '累计AA', size: 22, isYen: true)),
              ],
            ),
          ),
          SizedBox(height: 16),
          // 菜单卡（Demo .line 行）
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 2),
            child: Column(
              children: [
                AaLine(
                  child: _menuRow('数据导出',
                      image: 'assets/icons/export.png',
                      onTap: () => context.push('/export')),
                  onTap: () => context.push('/export'),
                ),
                AaLine(
                  child: _menuRow('账号安全',
                      image: 'assets/icons/lock.png',
                      onTap: () => context.push('/security')),
                  onTap: () => context.push('/security'),
                ),
                AaLine(
                  child: _menuRow('设置',
                      image: 'assets/icons/settings.png',
                      onTap: () => context.push('/settings')),
                  onTap: () => context.push('/settings'),
                ),
                AaLine(
                  showBorder: false,
                  child: _menuRow('关于我们',
                      image: 'assets/icons/mail.png',
                      onTap: () => context.push('/about')),
                  onTap: () => context.push('/about'),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          DoodleButton(
            label: '退出登录「下次再来玩呀」',
            type: DoodleButtonType.danger,
            big: true,
            onPressed: () => _logout(context, ref),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _menuRow(String label, {String? image, VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (image != null) ...[
              AaIconImage(image, size: 18),
              SizedBox(width: 8),
            ],
            Text(label,
                style: TextStyle(
                    fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
          ],
        ),
        Text('→', style: TextStyle(fontSize: 15, color: AAColors.ink)),
      ],
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showAaConfirm(
      context,
      title: '要退出登录吗？',
      subtitle: '下次来还要把这些账算清楚哦',
      confirmLabel: '退出',
      // 退出弹窗保持简洁：不展示手绘吉祥物
      showMascot: false,
    );
    if (ok == true && context.mounted) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go('/login');
    }
  }

  /// 点击头像 → 拍一张 / 从相册选 / 恢复默认（P50 换头像）
  Future<void> _changeAvatar(BuildContext context, WidgetRef ref) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final choice = await showAaSheet<String>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('换头像',
              style:
                  TextStyle(fontFamily: AAFonts.title, fontSize: 18, color: AAColors.ink)),
          SizedBox(height: 12),
          DoodleButton(
            label: '拍一张',
            leadingImage: 'assets/icons/camera.png',
            expand: true,
            onPressed: () => Navigator.of(context).pop('camera'),
          ),
          SizedBox(height: 8),
          DoodleButton(
            label: '从相册选',
            leadingImage: 'assets/icons/picture.png',
            type: DoodleButtonType.secondary,
            expand: true,
            onPressed: () => Navigator.of(context).pop('gallery'),
          ),
          SizedBox(height: 8),
          DoodleButton(
            label: '恢复默认',
            leadingImage: 'assets/icons/panda.png',
            type: DoodleButtonType.ghost,
            expand: true,
            onPressed: () => Navigator.of(context).pop('default'),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
    if (choice == null || !context.mounted) return;

    if (choice == 'default') {
      try {
        await ref.read(authProvider.notifier).updateProfile(avatarUrl: '🐼');
        if (context.mounted) showAaToast(context, '已恢复默认头像');
      } catch (e) {
        if (context.mounted) showAaToast(context, '换头像失败：$e');
      }
      return;
    }
    try {
      final file = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (file == null || !context.mounted) return;
      await ref.read(authProvider.notifier).updateProfile(avatarUrl: file.path);
      if (context.mounted) showAaToast(context, '头像已更新 ✨');
    } catch (e) {
      if (context.mounted) showAaToast(context, '换头像失败：$e');
    }
  }

  void _editProfile(BuildContext context, WidgetRef ref) {    final user = ref.read(currentUserProvider);
    if (user == null) return;
    showAaSheet(
      context,
      child: _EditProfileSheet(
        nickname: user.nickname,
        bio: user.bio,
        onSave: (nickname, bio) async {
          try {
            await ref.read(authProvider.notifier).updateProfile(
                  nickname: nickname,
                  bio: bio,
                  avatarUrl: user.avatarUrl,
                );
            if (!context.mounted) return;
            showAaToast(context, '资料已更新');
          } catch (e) {
            if (!context.mounted) return;
            showAaToast(context, '保存失败：$e');
          }
        },
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.value, required this.label, required this.size, this.isYen = false});
  final String value;
  final String label;
  final double size;
  final bool isYen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (isYen)
          HandAmount(
            amountCents: _parseCents(value),
            size: size,
            color: AAColors.ink,
            trimZero: true,
          )
        else
          Text(
            value,
            style: TextStyle(
                fontFamily: AAFonts.hand, fontSize: size, color: AAColors.ink, height: 1),
          ),
        Text(label,
            style: TextStyle(
                fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
      ],
    );
  }

  int _parseCents(String s) {
    final v = double.tryParse(s.replaceAll('¥', '')) ?? 0;
    return (v * 100).round();
  }
}

/// 中间列左右虚线（Demo：border-left/right:2px dashed var(--ink)）
class _DashedVerticalsPainter extends CustomPainter {
  const _DashedVerticalsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AAColors.ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt;
    for (final x in [0.0, size.width]) {
      var y = 0.0;
      while (y < size.height) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 6), p);
        y += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// `.wob` 摇晃：±3° · 2.4s
class _Wobble extends StatefulWidget {
  const _Wobble({required this.child});
  final Widget child;
  @override
  State<_Wobble> createState() => _WobbleState();
}

class _WobbleState extends State<_Wobble> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: 2400))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Transform.rotate(
        angle: (-3 + 6 * (1 - (2 * _c.value - 1).abs())) * pi / 180,
        child: widget.child,
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.nickname,
    required this.bio,
    required this.onSave,
  });
  final String nickname;
  final String bio;
  final Future<void> Function(String nickname, String bio) onSave;
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nickname = TextEditingController(text: widget.nickname);
  late final TextEditingController _bio = TextEditingController(text: widget.bio);

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('编辑资料', style: text.headlineSmall),
        SizedBox(height: 12),
        Text('昵称', style: text.bodyMedium),
        HandTextField(controller: _nickname),
        SizedBox(height: 12),
        Text('个性签名', style: text.bodyMedium),
        HandTextField(controller: _bio, maxLines: 2),
        SizedBox(height: 16),
        DoodleButton(
          label: '保存',
          expand: true,
          onPressed: _nickname.text.trim().isEmpty
              ? null
              : () async {
                  await widget.onSave(_nickname.text.trim(), _bio.text.trim());
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
        SizedBox(height: 8),
      ],
    );
  }
}
