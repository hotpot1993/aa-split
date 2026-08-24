import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repositories.dart';
import 'auth_widgets.dart';

const _questions = [
  '你第一个朋友的名字？',
  '你妈妈的姓氏？',
  '你最喜欢的城市？',
  '你的小学名字？',
];

/// P03 注册页
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _account = TextEditingController();
  final _nickname = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _answer = TextEditingController();
  String? _accountErr;
  String? _passwordErr;
  String? _confirmErr;
  String? _answerErr;
  String _question = _questions.first;
  bool _agree = false;
  bool _obscure = true;

  bool get _accountTaken {
    final name = _account.text.trim();
    if (name.isEmpty) return false;
    return !ref.read(authRepositoryProvider).isAccountAvailable(name);
  }

  bool get _canSubmit {
    return _account.text.trim().isNotEmpty &&
        _nickname.text.trim().isNotEmpty &&
        _password.text.length >= 6 &&
        _confirm.text == _password.text &&
        _answer.text.trim().isNotEmpty &&
        _agree;
  }

  void _submit() {
    if (!_canSubmit) return;
    try {
      ref.read(authProvider.notifier).register(
            accountName: _account.text.trim(),
            password: _password.text,
            nickname: _nickname.text.trim(),
            securityQuestion: _question,
            securityAnswer: _answer.text.trim(),
          );
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      setState(() => _accountErr = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget label(String s) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(s, style: text.bodyMedium),
        );

    return AuthScaffold(
      title: '注册',
      children: [
        label('设置你的账户名'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: HandTextField(
                controller: _account,
                hint: '如 tuanzi',
                keyboardType: TextInputType.text,
                onChanged: (_) => setState(() {
                  _accountErr = null;
                  _checkAccount();
                }),
              ),
            ),
            const SizedBox(width: 8),
            if (_account.text.trim().isNotEmpty)
              _AvailabilityStamp(available: !_accountTaken),
          ],
        ),
        FieldError(message: _accountErr),

        label('自定义昵称'),
        HandTextField(controller: _nickname, hint: '选填，默认等于账户名'),
        const SizedBox(height: 8),

        label('密码（至少6位，含字母和数字）'),
        TextField(
          controller: _password,
          obscureText: _obscure,
          onChanged: (_) => setState(() {
            _passwordErr = _password.text.length < 6
                ? '密码至少6位哦'
                : (!_hasLetterAndDigit(_password.text) ? '要含字母和数字' : null);
          }),
          style: text.titleMedium,
          decoration: InputDecoration(
            hintText: '密码',
            hintStyle: text.titleMedium,
            border: InputBorder.none,
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        FieldError(message: _passwordErr),

        label('确认密码'),
        HandTextField(
          controller: _confirm,
          hint: '再输一次',
          onChanged: (_) => setState(() {
            _confirmErr = _confirm.text != _password.text ? '两次密码不一致' : null;
          }),
        ),
        FieldError(message: _confirmErr),

        label('安全问题：$_question'),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _question,
            isExpanded: true,
            items: _questions
                .map((q) =>
                    DropdownMenuItem(value: q, child: Text(q, style: text.bodyMedium)))
                .toList(),
            onChanged: (v) => setState(() => _question = v ?? _question),
          ),
        ),
        const SizedBox(height: 6),
        HandTextField(
          controller: _answer,
          hint: '填写答案（用于找回密码）',
          onChanged: (_) => setState(() {
            _answerErr = _answer.text.trim().isEmpty ? '还是要填一下答案哦' : null;
          }),
        ),
        FieldError(message: _answerErr),

        const SizedBox(height: 16),
        Row(
          children: [
            InkWell(
              onTap: () => setState(() => _agree = !_agree),
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AAColors.cardWhite,
                  border: Border.all(color: AAColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: _agree
                    ? const Icon(Icons.check, size: 16, color: AAColors.coral)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '已阅读并同意《用户协议》《隐私政策》',
                style: text.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        DoodleButton(
          label: '注册并开始',
          expand: true,
          onPressed: _canSubmit ? _submit : null,
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: const Text('已有账户？去登录',
                style: TextStyle(color: AAColors.sky, fontFamily: 'ZCOOLKuaiLe')),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _checkAccount() {
    if (_account.text.trim().isEmpty) return;
    if (_accountTaken) {
      _accountErr = '已被占用，试试 ${_account.text.trim()}_123';
    }
  }

  bool _hasLetterAndDigit(String s) =>
      s.contains(RegExp('[a-zA-Z]')) && s.contains(RegExp('[0-9]'));
}

class _AvailabilityStamp extends StatelessWidget {
  const _AvailabilityStamp({required this.available});
  final bool available;
  @override
  Widget build(BuildContext context) {
    return StampBadge(
      text: available ? '可用' : '占用',
      size: 46,
      rotate: -8,
      color: available ? AAColors.mint : AAColors.berry,
    );
  }
}
