import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aa_design/aa_design.dart';

import '../../data/repositories/auth_repository.dart';
import '../../providers/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P52 账号安全页
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});
  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _current = TextEditingController();
  final _newPwd = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _newPwd.dispose();
    super.dispose();
  }

  void _changePassword() {
    try {
      ref.read(authRepositoryProvider).changePassword(_current.text, _newPwd.text);
      showAaToast(context, '密码已修改');
      _current.clear();
      _newPwd.clear();
    } on AuthException catch (e) {
      showAaToast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AaScaffold(
      appBar: AppBar(title: const Text('账号安全')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionTitle('修改密码'),
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('当前密码'),
                HandTextField(controller: _current, hint: '当前密码'),
                const SizedBox(height: 10),
                _label('新密码'),
                HandTextField(controller: _newPwd, hint: '至少6位，含字母和数字'),
                const SizedBox(height: 14),
                DoodleButton(
                  label: '确认修改',
                  type: DoodleButtonType.secondary,
                  expand: true,
                  onPressed: _changePassword,
                ),
              ],
            ),
          ),
          SectionTitle('修改安全问题'),
          PaperCard(
            child: Row(
              children: [
                const Icon(Icons.help_outline, color: AAColors.inkSoft),
                const SizedBox(width: 10),
                Expanded(child: Text('需要当前密码验证', style: text.titleSmall)),
                const SizedBox(width: 8),
                DoodleButton(
                  label: '去修改',
                  type: DoodleButtonType.secondary,
                  onPressed: () => showAaToast(context, '演示：需当前密码验证'),
                ),
              ],
            ),
          ),
          SectionTitle('登录设备'),
          _DeviceRow(emoji: '📱', name: 'iPhone 15', where: '当前设备 · 本机'),
          _DeviceRow(emoji: '💻', name: 'Windows 电脑', where: '昨天 · 北京'),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => showAaToast(context, '已清除其他设备登录态'),
              child: const Text('退出其他设备',
                  style: TextStyle(color: AAColors.berry, fontFamily: 'ZCOOLKuaiLe', fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(s, style: Theme.of(context).textTheme.bodySmall),
      );
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.emoji, required this.name, required this.where});
  final String emoji;
  final String name;
  final String where;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: text.titleMedium),
                Text(where, style: text.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: AAColors.mint, size: 20),
        ],
      ),
    );
  }
}
