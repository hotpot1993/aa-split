import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';
import 'auth_widgets.dart';

/// P05 重设密码 —— 对齐 docs/ui-demo/index.html
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
    return AuthScaffold(
      children: _ok
          ? [
              SizedBox(height: 120),
              Center(child: TuanTuanPanda(size: 110)),
              SizedBox(height: 12),
              Center(
                child: Text('密码已重置！',
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 22, color: AAColors.ink)),
              ),
              SizedBox(height: 20),
              DoodleButton(
                label: '去登录 →',
                expand: true,
                onPressed: () {
                  showAaToast(context, '密码已重置，请登录');
                  context.go('/login');
                },
              ),
            ]
          : [
              AaAppBar(
                title: '重设密码',
                headIcon: 'assets/icons/key.png',
                iconImage: 'assets/icons/check.png',
              ),
              SizedBox(height: 26),
              PaperCard(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                child: Column(
                  children: [
                    AaLine(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('新密码',
                              style: TextStyle(
                                  fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
                          SizedBox(
                            width: 200,
                            child: HandTextField(
                              controller: _newPassword,
                              hint: '••••••••',
                              textAlign: TextAlign.end,
                              obscure: true,
                              onChanged: (_) => setState(() => _error = null),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AaLine(
                      showBorder: false,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('确认新密码',
                              style: TextStyle(
                                  fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
                          SizedBox(
                            width: 200,
                            child: HandTextField(
                              controller: _confirm,
                              hint: '••••••••',
                              textAlign: TextAlign.end,
                              obscure: true,
                              onChanged: (_) => setState(() => _error = null),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              FieldError(message: _error),
              SizedBox(height: 8),
              DoodleButton(
                label: '重置密码并去登录 👍',
                big: true,
                onPressed: _reset,
              ),
              SizedBox(height: 14),
              Center(
                child: Text('💪 新密码要字母+数字哦',
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
              ),
              SizedBox(height: 16),
            ],
    );
  }
}
