import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/config.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common.dart';

/// P01 启动页 —— 对齐 docs/ui-demo/index.html：
/// 150px 团团 + 48px AA分账 + mini「团团正在数钱…」+ · · · + 四枚涂鸦。
/// 5s 后按登录态自动跳转（未登录 → /login，已登录 → /home；点击屏幕可跳过等待）。
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: 900));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);

  /// 停留时长：5 秒后自动进入登录页或首页（按登录状态决定）
  static const autoJumpDelay = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(autoJumpDelay, _go);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (!mounted) return;
    // 真实模式：先恢复本地会话（token + /auth/me 校验），避免每次都掉回登录页
    if (!AppConfig.useMock && !ref.read(authProvider).isLoggedIn) {
      await ref.read(authProvider.notifier).restore();
      if (!mounted) return;
    }
    final loggedIn = ref.read(authProvider).isLoggedIn;
    context.go(loggedIn ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AAColors.paper,
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _SplashPainter())),
          // 散落涂鸦（Demo .doodle）—— 替换为匹配素材
          Positioned(top: 130, left: 36, child: AaIconImage('assets/icons/star.png', size: 18)),
          Positioned(top: 230, right: 40, child: AaIconImage('assets/icons/heart.png', size: 18)),
          Positioned(
            top: 400,
            left: 56,
            child: Opacity(opacity: 0.55, child: AaIconImage('assets/icons/coin.png', size: 22)),
          ),
          Positioned(
            top: 470,
            right: 56,
            child: Opacity(opacity: 0.55, child: AaIconImage('assets/icons/edit.png', size: 22)),
          ),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: GestureDetector(
                onTap: _go,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 30),
                    TuanTuanPanda(size: 150),
                    SizedBox(height: 16),
                    // 品牌字：知音漫兴体（Demo P01：Zhi Mang Xing 48px）
                    Text(
                      'AA分账',
                      style: TextStyle(
                          fontFamily: AAFonts.brand,
                          fontSize: 48,
                          color: AAColors.ink,
                          height: 1.1),
                    ),
                    SizedBox(height: 6),
                    Text('团团正在数钱…',
                        style: TextStyle(
                            fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
                    SizedBox(height: 24),
                    Text('· · ·',
                        style: TextStyle(
                            fontFamily: AAFonts.title,
                            fontSize: 22,
                            color: AAColors.inkSoft,
                            letterSpacing: 6)),
                    SizedBox(height: 60),
                    Text('5 秒后自动进入（点击屏幕可跳过）',
                        style: TextStyle(
                            fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 散落星星/硬币（Demo 背景涂鸦）
class _SplashPainter extends CustomPainter {
  const _SplashPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = AAColors.ink.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final rnd = _FixedRandom(7);
    for (var i = 0; i < 8; i++) {
      final x = rnd.next() * size.width;
      final y = rnd.next() * size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rnd.next() * 3.14);
      final r = 6 + rnd.next() * 6;
      canvas.drawLine(Offset(-r, 0), Offset(r, 0), ink);
      canvas.drawLine(Offset(0, -r), Offset(0, r), ink);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _FixedRandom {
  _FixedRandom(int seed) : _state = seed;
  int _state;
  double next() {
    _state = (_state * 1103515245 + 12345) & 0x7fffffff;
    return _state / 0x7fffffff;
  }
}
