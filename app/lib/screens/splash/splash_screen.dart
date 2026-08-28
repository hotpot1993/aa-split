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
/// 2s 后按登录态自动跳转（未登录 → /login，已登录 → /home；点击屏幕任意处可跳过）。
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _jumping = false; // 防重入：连点/定时器竞态只跳一次
  bool _skipping = false; // 已点击跳过 → 提示文案即时反馈
  Future<void>? _restoreFuture; // 真实模式会话预恢复（点击/定时器共用，不重复发请求）
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: 900));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);

  /// 停留时长：2 秒后自动进入登录页或首页（按登录状态决定）
  static const autoJumpDelay = Duration(seconds: 2);

  /// 点击跳过时等待会话恢复的上限：超时按未登录处理（登录页仍会再校验），
  /// 弱网下点屏幕也能立刻有响应，不会卡在启动页
  static const skipRestoreTimeout = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _c.forward();
    // 真实模式：进入启动页就预恢复会话（与点击跳过共用同一 Future）
    if (!AppConfig.useMock && !ref.read(authProvider).isLoggedIn) {
      _restoreFuture = ref.read(authProvider.notifier).restore();
    }
    _timer = Timer(autoJumpDelay, _go);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (!mounted || _jumping) return;
    _jumping = true;
    _timer?.cancel();
    // 点击即时反馈：提示文案切换为「正在进入…」
    if (mounted) setState(() => _skipping = true);
    // 真实模式：等待预恢复结果（设上限，弱网不再卡死跳过）
    final restore = _restoreFuture;
    if (restore != null) {
      try {
        await restore.timeout(skipRestoreTimeout, onTimeout: () {});
      } catch (_) {
        // 恢复失败不阻塞跳转（按未登录处理）
      }
    }
    if (!mounted) return;
    final loggedIn = ref.read(authProvider).isLoggedIn;
    context.go(loggedIn ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AAColors.paper,
      // 点击屏幕任意处跳过：整屏 GestureDetector（opaque），不再只包中间 Logo 块
      body: GestureDetector(
        onTap: _go,
        behavior: HitTestBehavior.opaque,
        child: Stack(
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
                    Text(
                      _skipping ? '正在进入…' : '2 秒后自动进入（点击屏幕可跳过）',
                      style: TextStyle(
                          fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
                  ],
                ),
              ),
            ),
          ],
        ),
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
