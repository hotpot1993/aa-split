import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../data/repositories/auth_repository.dart';
import '../../models/user_device.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../providers/refresh_provider.dart';
import '../../providers/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P52 账号安全 —— 对齐 docs/ui-demo/index.html
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});
  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _current = TextEditingController();
  final _newPwd = TextEditingController();
  final _confirmPwd = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _newPwd.dispose();
    _confirmPwd.dispose();
    super.dispose();
  }

  void _changePassword() {
    if (_newPwd.text != _confirmPwd.text) {
      showAaToast(context, '两次新密码不一致');
      return;
    }
    try {
      ref.read(authRepositoryProvider).changePassword(_current.text, _newPwd.text);
      showAaToast(context, '🛡 密码已修改，记得保管好新密码哦');
      _current.clear();
      _newPwd.clear();
      _confirmPwd.clear();
    } on AuthException catch (e) {
      showAaToast(context, e.message);
    }
  }

  /// 注销账号（应用商店合规：应用内删除账号）。二次确认后删除并回到登录页。
  Future<void> _deleteAccount() async {
    final ok = await showAaConfirm(
      context,
      title: '要注销账号吗？',
      subtitle: '删除后个人资料清空、退出全部群组，此操作不可恢复',
      confirmLabel: '确认注销',
    );
    if (ok != true) return;
    try {
      await ref.read(authRepositoryProvider).deleteAccount();
      // 清除推送 alias 并重置登录态 → 回登录页
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        showAaToast(context, '账号已注销');
        context.go('/login');
      }
    } on AuthException catch (e) {
      if (mounted) showAaToast(context, e.message);
    } catch (_) {
      if (mounted) showAaToast(context, '注销失败，请稍后再试');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 登录设备：真实数据（打开本页时先上报当前设备，服务端按 userId+deviceId 幂等记录；
    // Demo 模式为 MockStore 演示数据）
    final devices =
        ref.watch(loginDevicesProvider).value ?? const <UserDevice>[];
    return AaScaffold(
      appBar: AaAppBar(
        title: '账号安全',
        headIcon: 'assets/icons/lock.png',
        iconImage: 'assets/icons/shield.png',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 🔑 修改密码（Demo .line 三行）
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AaIconImage('assets/icons/key.png', size: 16),
                    SizedBox(width: 6),
                    Text('修改密码',
                        style: TextStyle(
                            fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
                  ],
                ),
                SizedBox(height: 2),
                _pwdLine('当前密码', _current, showBorder: true),
                _pwdLine('新密码', _newPwd, showBorder: true),
                _pwdLine('确认新密码', _confirmPwd, showBorder: false),
              ],
            ),
          ),
          SizedBox(height: 16),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                _tapLine(
                  '修改安全问题',
                  value: '你第一个朋友的名字？ ▾',
                  onTap: () => showAaToast(context, '演示：需当前密码验证'),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AaIconImage('assets/icons/phone.png', size: 16),
                    SizedBox(width: 6),
                    Text('登录设备',
                        style: TextStyle(
                            fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
                  ],
                ),
                SizedBox(height: 2),
                if (devices.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
                    child: Text('暂无登录设备记录',
                        style: TextStyle(
                            fontFamily: AAFonts.title, fontSize: 13, color: AAColors.inkSoft)),
                  )
                else
                  // 最近登录在前（页面打开时刚上报过本机 → 首行即当前设备）
                  for (var i = 0; i < devices.length; i++)
                    _deviceLine(
                      devices[i],
                      isCurrent: i == 0,
                      showBorder: i < devices.length - 1,
                    ),
              ],
            ),
          ),
          SizedBox(height: 16),
          DoodleButton(
            label: '保存修改',
            big: true,
            onPressed: _changePassword,
          ),
          SizedBox(height: 10),
          DoodleButton(
            label: '注销账号',
            type: DoodleButtonType.danger,
            big: true,
            onPressed: _deleteAccount,
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 登录设备行：机型 + 最近登录时间；当前设备标「当前」，其它设备可「退出」
  Widget _deviceLine(UserDevice d,
      {required bool isCurrent, required bool showBorder}) {
    final icon = (d.platform == 'android' || d.platform == 'ios')
        ? 'assets/icons/phone.png'
        : 'assets/icons/laptop.png';
    final time = d.lastLoginAt == null ? '' : ' · ${Fmt.relative(d.lastLoginAt!)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AaIconImage(icon, size: 16),
                  SizedBox(width: 6),
                  Text('${d.label}$time',
                      style: TextStyle(
                          fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
                ],
              ),
              if (isCurrent)
                HandTag('当前', dense: true, variant: ChipVariant.green)
              else
                GestureDetector(
                  onTap: () => _removeDevice(d),
                  child: HandTag('退出', dense: true, variant: ChipVariant.orange),
                ),
            ],
          ),
        ),
        if (showBorder)
          CustomPaint(size: Size(double.infinity, 2.5), painter: _SecDash()),
      ],
    );
  }

  /// 退出（移除）一台设备记录并刷新列表
  Future<void> _removeDevice(UserDevice d) async {
    try {
      await ref.read(authRepositoryProvider).removeDevice(d.deviceId);
      ref.read(refreshProvider.notifier).bump();
      if (!mounted) return;
      showAaToast(context, '已退出「${d.label}」');
    } catch (_) {
      if (mounted) showAaToast(context, '退出失败，请稍后再试');
    }
  }

  Widget _pwdLine(String label, TextEditingController ctrl, {bool showBorder = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
              SizedBox(
                width: 170,
                child: HandTextField(
                  controller: ctrl,
                  hint: '••••••••',
                  textAlign: TextAlign.end,
                  obscure: true,
                ),
              ),
            ],
          ),
        ),
        if (showBorder)
          CustomPaint(size: Size(double.infinity, 2.5), painter: _SecDash()),
      ],
    );
  }

  Widget _tapLine(String label,
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
          CustomPaint(size: Size(double.infinity, 2.5), painter: _SecDash()),
      ],
    );
  }
}

class _SecDash extends CustomPainter {
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
