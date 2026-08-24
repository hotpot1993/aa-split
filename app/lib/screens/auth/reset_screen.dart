import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repositories.dart';
import '../../widgets/sheet.dart';
import 'auth_widgets.dart';

/// P05 重设密码（成功后强制重新登录）
class ResetScreen extends ConsumerStatefulWidget {
  const ResetScreen({super.key});
  @override
  ConsumerState<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends ConsumerState<ResetScreen> {
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _ok = false;

  void _reset() {
    if (_newPassword.text.length < 6) {
      setState(() => _error = '密码至少6位哦');
      return;
    }
    if (_newPassword.text != _confirm.text) {
      setState(() => _error = '两次密码不一致');
      return;
    }
    try {
      ref.read(authRepositoryProvider).resetPassword('', _newPassword.text);
      ref.read(authProvider.notifier).forceLogout();
      setState(() => _ok = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF4E8D3),
      appBar: AppBar(),
      body: SketchPaper(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: _ok ? _Success(onLogin: () {
            showAaToast(context, '密码已重置，请登录');
            context.go('/login');
          }) : _Form(
            newPassword: _newPassword,
            confirm: _confirm,
            error: _error,
            onReset: _reset,
            text: text,
          ),
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.newPassword,
    required this.confirm,
    required this.error,
    required this.onReset,
    required this.text,
  });

  final TextEditingController newPassword;
  final TextEditingController confirm;
  final String? error;
  final VoidCallback onReset;
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text('重设密码', style: text.headlineLarge, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        Text('新密码', style: text.bodyMedium),
        HandTextField(controller: newPassword, hint: '至少6位，含字母和数字'),
        const SizedBox(height: 14),
        Text('确认新密码', style: text.bodyMedium),
        HandTextField(controller: confirm, hint: '再输一次'),
        const SizedBox(height: 10),
        FieldError(message: error),
        const SizedBox(height: 12),
        DoodleButton(label: '重设密码', expand: true, onPressed: onReset),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.onLogin});
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TuanTuan(size: 150, emotion: TuanTuanEmotion.celebrate),
          const SizedBox(height: 12),
          HighlightText('密码已重置！', style: text.headlineMedium),
          const SizedBox(height: 24),
          DoodleButton(label: '去登录 →', expand: true, onPressed: onLogin),
        ],
      ),
    );
  }
}
