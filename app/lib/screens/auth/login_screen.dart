import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/sheet.dart';
import 'auth_widgets.dart';

/// P02 登录页
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _account = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _obscure = true;
  bool _remember = true;

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _account.text.trim().isNotEmpty && _password.text.isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    try {
      ref.read(authProvider.notifier).login(_account.text, _password.text);
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AuthScaffold(
      title: 'AA分账',
      children: [
        TextField(
          controller: _account,
          onChanged: (_) => setState(() => _error = null),
          style: text.titleMedium,
          decoration: InputDecoration(
            hintText: '账户名',
            hintStyle: text.titleMedium,
            border: InputBorder.none,
          ),
        ),
        const _Underline(),
        const SizedBox(height: 8),
        TextField(
          controller: _password,
          obscureText: _obscure,
          onChanged: (_) => setState(() => _error = null),
          style: text.titleMedium,
          decoration: InputDecoration(
            hintText: '密码',
            hintStyle: text.titleMedium,
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                  size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const _Underline(),
        const SizedBox(height: 12),
        Row(
          children: [
            InkWell(
              onTap: () => setState(() => _remember = !_remember),
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AAColors.cardWhite,
                  border: Border.all(color: AAColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: _remember
                    ? const Icon(Icons.check, size: 16, color: AAColors.coral)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Text('记住我', style: text.bodyMedium),
            const Spacer(),
            TextButton(
              onPressed: () => context.push('/forgot'),
              child: const Text('忘记密码？',
                  style: TextStyle(color: AAColors.sky, fontFamily: 'ZCOOLKuaiLe', fontSize: 14)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FieldError(message: _error),
        const SizedBox(height: 8),
        DoodleButton(
          label: '去记账咯 →',
          expand: true,
          onPressed: _canSubmit ? _submit : null,
        ),
        const SizedBox(height: 20),
        Row(
          children: const [
            Expanded(child: Divider(color: AAColors.inkSoft, height: 1)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('或', style: TextStyle(color: AAColors.inkSoft)),
            ),
            Expanded(child: Divider(color: AAColors.inkSoft, height: 1)),
          ],
        ),
        const SizedBox(height: 20),
        DoodleButton(
          label: '注册新账户',
          type: DoodleButtonType.secondary,
          expand: true,
          onPressed: () => context.push('/register'),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => showAaToast(context, '演示账号：tuanzi / 任意密码'),
            child: const Text('演示一下',
                style: TextStyle(color: AAColors.inkSoft, fontFamily: 'ZCOOLKuaiLe')),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _Underline extends StatelessWidget {
  const _Underline();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: CustomPaint(
        size: const Size(double.infinity, 4),
        painter: _UnderlinePainter(),
      ),
    );
  }
}

class _UnderlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AAColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..quadraticBezierTo(size.width * 0.3, size.height / 2 + 2,
          size.width * 0.55, size.height / 2)
      ..quadraticBezierTo(size.width * 0.8, size.height / 2 - 2,
          size.width, size.height / 2);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
