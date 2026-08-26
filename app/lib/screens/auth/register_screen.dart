import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repositories.dart';
import '../../widgets/common.dart';
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

  bool? _available;

  /// 防重复提交：注册进行中置位，重复点击直接忽略（单次操作仅注册一次）
  bool _submitting = false;

  bool get _accountTaken => _available == false;

  bool get _canSubmit {
    return _account.text.trim().isNotEmpty &&
        _nickname.text.trim().isNotEmpty &&
        _password.text.length >= 6 &&
        _confirm.text == _password.text &&
        _answer.text.trim().isNotEmpty &&
        _agree;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);
    await _checkAccount();
    if (!mounted) return;
    if (_accountTaken) {
      setState(() {
        _accountErr = '这个名字被占用啦，换一个试试';
        _submitting = false;
      });
      return;
    }
    try {
      await ref.read(authProvider.notifier).register(
            accountName: _account.text.trim(),
            password: _password.text,
            nickname: _nickname.text.trim(),
            securityQuestion: _question,
            securityAnswer: _answer.text.trim(),
          );
      // 成功：不重置 _submitting（页面随即跳转主框架），杜绝连点窗口
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _accountErr = e.message;
          _submitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _accountErr = e.toString();
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      children: [
        AaAppBar(title: '✏️ 注册新账户'),
        // 🐾 涂鸦装饰（Demo .doodle）
        SizedBox(height: 34),
        // 账户信息卡（Demo .card padding:4px 14px 的 .line 行）
        PaperCard(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Column(
            children: [
              _RegLine(
                label: '账户名',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 160,
                      child: HandTextField(
                        controller: _account,
                        hint: 'tuanzi_t',
                        keyboardType: TextInputType.text,
                        textAlign: TextAlign.end,
                        onChanged: (_) => setState(() {
                          _accountErr = null;
                          _checkAccount();
                        }),
                      ),
                    ),
                    if (_account.text.trim().isNotEmpty) ...[
                      SizedBox(width: 6),
                      StampBadge(
                        text: _accountTaken ? '占用' : '✅ 可用',
                        rotate: -8,
                        color: _accountTaken ? AAColors.berry : AASemantic.stampDone,
                      ),
                    ],
                  ],
                ),
              ),
              _RegLine(
                label: '昵称（选填）',
                child: SizedBox(
                  width: 160,
                  child: HandTextField(
                    controller: _nickname,
                    hint: '团子酱',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
              _RegLine(
                label: '密码（≥6位）',
                child: SizedBox(
                  width: 160,
                  child: Row(
                    children: [
                      Expanded(
                        child: HandTextField(
                          controller: _password,
                          hint: '••••••••',
                          textAlign: TextAlign.end,
                          obscure: _obscure,
                          onChanged: (_) => setState(() {
                            _passwordErr = _password.text.length < 6
                                ? '密码至少6位哦'
                                : (!_hasLetterAndDigit(_password.text) ? '要含字母和数字' : null);
                          }),
                        ),
                      ),
                      IconButton(
                        icon: Text(_obscure ? '🙈' : '👁️',
                            style: TextStyle(fontSize: 15)),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ],
                  ),
                ),
              ),
              _RegLine(
                label: '确认密码',
                showBorder: false,
                child: SizedBox(
                  width: 160,
                  child: HandTextField(
                    controller: _confirm,
                    hint: '••••••••',
                    textAlign: TextAlign.end,
                    obscure: true,
                    onChanged: (_) => setState(() {
                      _confirmErr = _confirm.text != _password.text ? '两次密码不一致' : null;
                    }),
                  ),
                ),
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
              Text('🔐 找回密码用（忘记手机号也不怕）',
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
              SizedBox(height: 4),
              _RegLine(
                label: '安全问题',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _question,
                    icon: Text('▾',
                        style: TextStyle(fontSize: 16, color: AAColors.inkSoft, height: 1)),
                    items: _questions
                        .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                        .toList(),
                    onChanged: (v) => setState(() => _question = v ?? _question),
                  ),
                ),
              ),
              _RegLine(
                label: '答案',
                showBorder: false,
                child: SizedBox(
                  width: 160,
                  child: HandTextField(
                    controller: _answer,
                    hint: '小虎',
                    textAlign: TextAlign.end,
                    onChanged: (_) => setState(() {
                      _answerErr = _answer.text.trim().isEmpty ? '还是要填一下答案哦' : null;
                    }),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        FieldError(message: _accountErr),
        FieldError(message: _passwordErr),
        FieldError(message: _confirmErr),
        FieldError(message: _answerErr),
        SizedBox(height: 8),
        Row(
          children: [
            AaCheckbox(
              value: _agree,
              onChanged: () => setState(() => _agree = !_agree),
            ),
            SizedBox(width: 8),
            Text(
              '已阅读并同意《用户协议》《隐私政策》',
              style: TextStyle(
                  fontFamily: AAFonts.title, fontSize: 12, color: AAColors.ink),
            ),
          ],
        ),
        SizedBox(height: 14),
        DoodleButton(
          label: _submitting ? '注册中…' : '注册并开始',
          trailingImage: _submitting ? null : 'assets/icons/party.png',
          big: true,
          onPressed: _canSubmit && !_submitting ? _submit : null,
        ),
        SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: Text('已有账户？去登录',
                style: TextStyle(color: AAColors.sky, fontFamily: AAFonts.title)),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Future<void> _checkAccount() async {
    final name = _account.text.trim();
    if (name.isEmpty) {
      if (_available != null && mounted) setState(() => _available = null);
      return;
    }
    final ok = await ref.read(authRepositoryProvider).isAccountAvailable(name);
    if (mounted) setState(() => _available = ok);
  }

  bool _hasLetterAndDigit(String s) =>
      s.contains(RegExp('[a-zA-Z]')) && s.contains(RegExp('[0-9]'));
}

/// 注册表单行 —— Demo `.line`：左标签 + 右输入，底部虚线
class _RegLine extends StatelessWidget {
  const _RegLine({required this.label, required this.child, this.showBorder = true});
  final String label;
  final Widget child;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
              child,
            ],
          ),
        ),
        if (showBorder)
          CustomPaint(size: Size(double.infinity, 2.5), painter: _RegDash()),
      ],
    );
  }
}

class _RegDash extends CustomPainter {
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
