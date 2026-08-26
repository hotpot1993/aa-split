import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../data/repositories/auth_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';
import 'auth_widgets.dart';

/// P02 登录页 —— 对齐 docs/ui-demo/index.html
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
  bool _submitting = false;

  @override
  void dispose() {
    _account.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _account.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(_account.text, _password.text);
      // 登录成功才进入主框架；失败停留在本页并给出错误提示
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '登录失败：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      children: [
        // 涂鸦装饰（Demo .doodle）
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(height: 0),
            Positioned(top: -16, right: 8, child: AaIconImage('assets/icons/star.png', size: 18)),
            Positioned(top: 70, left: 0, child: AaIconImage('assets/icons/heart.png', size: 18)),
            const SizedBox.shrink(),
          ],
        ),
        SizedBox(height: 46),
        // 品牌区：团团 + AA分账
        Center(child: TuanTuanPanda(size: 110)),
        SizedBox(height: 8),
        // 品牌字：知音漫兴体（Demo P02：Zhi Mang Xing 44px）
        Center(
          child: Text('AA分账',
              style: TextStyle(
                  fontFamily: AAFonts.brand,
                  fontSize: 44,
                  color: AAColors.ink,
                  height: 1.1)),
        ),
        Center(
          child: Text('一起吃饭，轻松AA～',
              style: TextStyle(
                  fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
        ),
        SizedBox(height: 44),
        // 账户名 / 密码（Demo .line：虚线 + 左右分隔）
        AaLine(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('账户名',
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _account,
                  textAlign: TextAlign.end,
                  onChanged: (_) => setState(() => _error = null),
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink),
                  decoration: InputDecoration(
                    hintText: 'tuanzi_t',
                    hintStyle: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ),
        AaLine(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('密码',
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _password,
                  obscureText: _obscure,
                  textAlign: TextAlign.end,
                  onChanged: (_) => setState(() => _error = null),
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: IconButton(
                      icon: Image.asset(
                        _obscure
                            ? 'assets/icons/hide.png'
                            : 'assets/icons/eye.png',
                        width: 17,
                        height: 17,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            AaCheckbox(
              value: _remember,
              onChanged: () => setState(() => _remember = !_remember),
            ),
            SizedBox(width: 8),
            Text('记住我',
                style: TextStyle(
                    fontFamily: AAFonts.title, fontSize: 12, color: AAColors.ink)),
          ],
        ),
        FieldError(message: _error),
        SizedBox(height: 10),
        DoodleButton(
          label: _submitting ? '登录中…' : '登 录🐾',
          big: true,
          onPressed: _canSubmit && !_submitting ? _submit : null,
        ),
        SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () => context.push('/forgot'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AAColors.marker, width: 2),
                  ),
                ),
                child: Text('忘记密码？',
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 12, color: AAColors.ink)),
              ),
            ),
            InkWell(
              onTap: () => context.push('/register'),
              child: Text('注册新账户 →',
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 12, color: AAColors.ink)),
            ),
          ],
        ),
        SizedBox(height: 24),
        Center(
          child: TextButton(
            onPressed: () => showAaToast(context, '演示账号：tuanzi / 任意密码'),
            child: Text('演示一下',
                style: TextStyle(color: AAColors.inkSoft, fontFamily: AAFonts.title)),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }
}
