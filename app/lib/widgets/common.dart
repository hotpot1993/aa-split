import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

import '../core/config.dart';

/// 相对路径（/uploads/xxx）→ 完整 URL；Demo 占位 emoji 原样返回。
/// 凭证 URL 存相对路径以兼容域名变更；展示时拼接当前 API origin。
String absReceiptUrl(String url) {
  if (url.isEmpty || url.startsWith('http') || url.startsWith('🧾')) return url;
  final origin = AppConfig.baseUrl.replaceFirst(RegExp(r'/api/v1$'), '');
  return '$origin$url';
}

/// 页面骨架：速写纸背景 + 可选顶部涂鸦导航栏
class AaScaffold extends StatelessWidget {
  const AaScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomBar,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomBar;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: appBar,
      body: SketchPaper(
        child: SafeArea(top: false, child: body),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

/// 手写体小节标题 + 手抖下划线（UI规范 §7 分组标题）
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Text(text, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(width: 8),
          const Expanded(child: _SquiggleLine()),
          ?trailing,
        ],
      ),
    );
  }
}

class _SquiggleLine extends StatelessWidget {
  const _SquiggleLine();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: CustomPaint(
        size: const Size(double.infinity, 6),
        painter: _LinePainter(),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AAColors.inkSoft.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..quadraticBezierTo(size.width * 0.25, 1, size.width * 0.5, size.height / 2)
      ..quadraticBezierTo(size.width * 0.75, size.height - 1, size.width, size.height / 2);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 内容加载/占位后的统一包裹：添加统一外边距
class AaBody extends StatelessWidget {
  const AaBody({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: child,
    );
  }
}
