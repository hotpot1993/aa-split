import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

/// 行内红章错误提示（UI规范 §9.3：草莓粉小印章，不弹窗打断）
class FieldError extends StatelessWidget {
  const FieldError({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const StampBadge(text: '!' , size: 18, color: AAColors.berry, rotate: -8),
          const SizedBox(width: 6),
          Text(
            message!,
            style: const TextStyle(
              fontFamily: 'ZCOOLKuaiLe',
              fontSize: 12,
              color: AAColors.berry,
            ),
          ),
        ],
      ),
    );
  }
}

/// 接入层页面公共骨架（深纸米底 + 顶部 Logo 区）
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4E8D3),
      body: SketchPaper(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const TuanTuan(size: 54, emotion: TuanTuanEmotion.happy),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          Text(
                            '记清楚 · 算明白 · 催到位',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
