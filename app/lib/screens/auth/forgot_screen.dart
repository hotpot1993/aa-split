import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../providers/repositories.dart';
import '../../widgets/common.dart';
import 'auth_widgets.dart';

/// P04 忘记密码 —— 对齐 docs/ui-demo/index.html
class ForgotScreen extends ConsumerStatefulWidget {
  const ForgotScreen({super.key});
  @override
  ConsumerState<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends ConsumerState<ForgotScreen> {
  final _account = TextEditingController();
  final _answer = TextEditingController();
  String _question = '';
  String? _error;

  Future<void> _lookup() async {
    if (_account.text.trim().isEmpty) {
      setState(() => _error = '先输入账户名');
      return;
    }
    try {
      final q =
          await ref.read(authRepositoryProvider).securityQuestionOf(_account.text.trim());
      setState(() {
        _question = q;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _verify() async {
    if (_answer.text.trim().isEmpty) {
      setState(() => _error = '回答问题才能继续哦');
      return;
    }
    try {
      final ok = await ref
          .read(authRepositoryProvider)
          .verifySecurityQuestion(_account.text, _answer.text);
      if (!ok) {
        setState(() => _error = '回答不对，再想想～');
        return;
      }
      if (!mounted) return;
      context.push('/forgot/reset');
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      children: [
        const AaAppBar(title: '忘记密码', headIcon: 'assets/icons/search.png', iconImage: 'assets/icons/detective.png'),
        const SizedBox(height: 26),
        PaperCard(
          withTape: true,
          child: Column(
            children: [
              const Image(image: AssetImage('assets/icons/detective.png'), width: 48, height: 48),
              const Text('团团侦探出马！',
                  style: TextStyle(
                      fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
              const SizedBox(height: 2),
              const Text('回答注册时的安全问题即可找回',
                  style: TextStyle(
                      fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PaperCard(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Column(
            children: [
              AaLine(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('账户名',
                        style: TextStyle(
                            fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft)),
                    SizedBox(
                      width: 200,
                      child: HandTextField(
                        controller: _account,
                        hint: 'tuanzi_t',
                        textAlign: TextAlign.end,
                        onChanged: (_) => setState(() => _error = null),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              DoodleButton(
                label: '查询安全问题',
                mini: true,
                onPressed: _lookup,
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
        if (_question.isNotEmpty) ...[
          const SizedBox(height: 16),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    AaIconImage('assets/icons/clipboard.png', size: 16),
                    SizedBox(width: 6),
                    Text('你的安全问题',
                        style: TextStyle(
                            fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_question,
                    style: const TextStyle(
                        fontFamily: 'ZCOOLKuaiLe', fontSize: 16, color: AAColors.ink)),
                const SizedBox(height: 8),
                AaLine(
                  showBorder: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('答案',
                          style: TextStyle(
                              fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft)),
                      SizedBox(
                        width: 200,
                        child: HandTextField(
                          controller: _answer,
                          hint: '小虎',
                          textAlign: TextAlign.end,
                          onChanged: (_) => setState(() => _error = null),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FieldError(message: _error),
          const SizedBox(height: 8),
          DoodleButton(
            label: '下一步：验证答案 →',
            big: true,
            onPressed: _verify,
          ),
        ],
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => context.pop(),
            child: const Text('返回登录',
                style: TextStyle(color: AAColors.sky, fontFamily: 'ZCOOLKuaiLe')),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
