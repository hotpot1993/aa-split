import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/config.dart';
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
          SizedBox(height: 18),
          Center(child: TuanTuanPanda(size: 110)),
          SizedBox(height: 6),
          Center(
            child: Text(
              'AA分账',
              style: TextStyle(
                fontFamily: AAFonts.title,
                fontSize: 24,
                color: AAColors.ink,
              ),
            ),
          ),
          SizedBox(height: 2),
          // 版本号与构建号：单一来源 AppConfig（与 pubspec.yaml 一致，见 version_consistency_test）
          // 英文/数字点缀（规范 §4 第五级：Caveat 手写体）
          Center(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'v${AppConfig.appVersion}',
                    style: TextStyle(
                      fontFamily: AAFonts.accent,
                      fontSize: 15,
                      color: AAColors.inkSoft,
                    ),
                  ),
                  TextSpan(
                    text: ' · 构建 ${AppConfig.appBuildNumber} · 由团团和程序员们一起做 💕',
                    style: TextStyle(
                      fontFamily: AAFonts.title,
                      fontSize: 12,
                      color: AAColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                _row(
                  '用户协议',
                  leadImage: 'assets/icons/scroll.png',
                  onTap: () => context.push('/about/agreement'),
                ),
                _row(
                  '隐私政策',
                  leadImage: 'assets/icons/locked.png',
                  onTap: () => context.push('/about/privacy'),
                ),
                _row(
                  '开源声明',
                  leadImage: 'assets/icons/scroll.png',
                  onTap: () => context.push('/about/oss'),
                ),
                _row(
                  '联系我们',
                  leadImage: 'assets/icons/inbox.png',
                  value: 'davedefy@163.com',
                  showBorder: false,
                ),
              ],
            ),
          ),
          SizedBox(height: 6),
          Center(
            child: Text(
              '© 2026 AA分账 · DeepSeek Harness',
              style: TextStyle(
                fontFamily: AAFonts.title,
                fontSize: 12,
                color: AAColors.inkSoft,
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _row(
    String label, {
    String? value,
    String? leadImage,
    VoidCallback? onTap,
    bool showBorder = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (leadImage != null) ...[
                      AaIconImage(leadImage, size: 16),
                      SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: AAFonts.title,
                        fontSize: 15,
                        color: AAColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                if (value != null)
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: AAFonts.title,
                      fontSize: 15,
                      color: AAColors.ink,
                    ),
                  )
                else
                  Text(
                    '→',
                    style: TextStyle(fontSize: 15, color: AAColors.ink),
                  ),
              ],
            ),
          ),
        ),
        if (showBorder)
          CustomPaint(size: Size(double.infinity, 2.5), painter: _AboutDash()),
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
