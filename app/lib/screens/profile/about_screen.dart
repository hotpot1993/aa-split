import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

import '../../widgets/common.dart';

/// P54 关于页 —— 对齐 docs/ui-demo/index.html
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AaScaffold(
      appBar: AaAppBar(
        title: '关于我们',
        headIcon: 'assets/icons/mail.png',
        icon: '🏷',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SizedBox(height: 18),
          const Center(child: TuanTuanPanda(size: 110)),
          const SizedBox(height: 6),
          const Center(
            child: Text('AA分账',
                style: TextStyle(
                    fontFamily: 'ZCOOLKuaiLe', fontSize: 24, color: AAColors.ink)),
          ),
          const SizedBox(height: 2),
          // 版本号：英文/数字点缀（规范 §4 第五级：Caveat 手写体）
          const Center(
            child: Text.rich(TextSpan(children: [
              TextSpan(
                  text: 'v1.0.0',
                  style: TextStyle(
                      fontFamily: 'Caveat', fontSize: 15, color: AAColors.inkSoft)),
              TextSpan(
                  text: ' · 由团团和程序员们一起做 💕',
                  style: TextStyle(
                      fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
            ])),
          ),
          const SizedBox(height: 20),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                _row('用户协议', leadImage: 'assets/icons/scroll.png'),
                _row('隐私政策', leadImage: 'assets/icons/locked.png'),
                _row('开源声明', leadImage: 'assets/icons/scroll.png'),
                _row('联系我们', leadImage: 'assets/icons/inbox.png', value: 'hi@aafen.app', showBorder: false),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text('© 2025 AA分账 · 手绘风小团队',
                style: TextStyle(
                    fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _row(String label, {String? value, String? leadImage, bool showBorder = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (leadImage != null) ...[
                    AaIconImage(leadImage, size: 16),
                    const SizedBox(width: 6),
                  ],
                  Text(label,
                      style: const TextStyle(
                          fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft)),
                ],
              ),
              if (value != null)
                Text(value,
                    style: const TextStyle(
                        fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink))
              else
                const Text('→', style: TextStyle(fontSize: 15, color: AAColors.ink)),
            ],
          ),
        ),
        if (showBorder)
          CustomPaint(size: const Size(double.infinity, 2.5), painter: _AboutDash()),
      ],
    );
  }
}

class _AboutDash extends CustomPainter {
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
