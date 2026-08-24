import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../providers/repositories.dart';
import 'auth_widgets.dart';

/// P04 忘记密码（回答安全问题）
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

  void _lookup() {
    if (_account.text.trim().isEmpty) {
      setState(() => _error = '先输入账户名');
      return;
    }
    final q = ref.read(authRepositoryProvider).securityQuestionOf(_account.text.trim());
    setState(() {
      _question = q;
      _error = null;
    });
  }

  void _verify() {
    if (_answer.text.trim().isEmpty) {
      setState(() => _error = '回答问题才能继续哦');
      return;
    }
    if (!ref.read(authRepositoryProvider).verifySecurityQuestion(_account.text, _answer.text)) {
      setState(() => _error = '回答不对，再想想～');
      return;
    }
    context.push('/forgot/reset');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF4E8D3),
      appBar: AppBar(),
      body: SketchPaper(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TuanTuan(emotion: TuanTuanEmotion.excited, size: 70),
                  Icon(Icons.search, color: AAColors.ink, size: 40),
                ],
              ),
              const SizedBox(height: 12),
              Text('忘记密码', style: text.headlineLarge, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              HandTextField(
                controller: _account,
                hint: '输入账户名',
                onChanged: (_) => setState(() => _error = null),
              ),
              const SizedBox(height: 8),
              if (_question.isEmpty)
                DoodleButton(label: '查询安全问题', expand: true, onPressed: _lookup)
              else ...[
                PaperCard(
                  withTape: true,
                  tiltSeed: 'question',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('答题卡', style: text.titleSmall),
                      const SizedBox(height: 6),
                      Text(_question, style: text.titleMedium),
                      const SizedBox(height: 8),
                      HandTextField(
                        controller: _answer,
                        hint: '填写你的答案',
                        onChanged: (_) => setState(() => _error = null),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FieldError(message: _error),
                const SizedBox(height: 8),
                DoodleButton(label: '验证并继续', expand: true, onPressed: _verify),
              ],
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('返回登录',
                      style: TextStyle(color: AAColors.sky, fontFamily: 'ZCOOLKuaiLe')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
