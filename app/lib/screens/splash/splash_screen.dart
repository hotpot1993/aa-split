import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/config.dart';
import '../../providers/auth_provider.dart';

/// P01 启动页：深纸米底 + 大号手写标题 + 团团 + 散落星星/硬币。
/// 2s 后按登录态跳转（未登录 → /login，已登录 → /home）。
/// 真实模式：先尝试从本地存储恢复会话（/auth/me 校验），再决定跳转。。
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(const Duration(seconds: 2), _go);
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
      backgroundColor: const Color(0xFFF4E8D3),
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _SplashPainter())),
          Center(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const TuanTuan(size: 150, emotion: TuanTuanEmotion.celebrate),
                  const SizedBox(height: 8),
                  Text(
                    'AA分账',
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '记清楚 · 算明白 · 催到位',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  const _SplashPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final lemon = Paint()..color = AAColors.lemon.withValues(alpha: 0.9);
    final ink = Paint()
      ..color = AAColors.ink.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final rnd = _FixedRandom(7);
    // 散落星星
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
    // 散落硬币
    for (var i = 0; i < 5; i++) {
      final x = rnd.next() * size.width;
      final y = rnd.next() * size.height;
      canvas.drawCircle(Offset(x, y), 9, lemon);
      canvas.drawCircle(Offset(x, y), 9, ink);
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
