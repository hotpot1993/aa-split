import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

import '../../widgets/common.dart';

/// P54 关于页
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AaScaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SizedBox(height: 20),
          const Center(child: TuanTuan(size: 130, emotion: TuanTuanEmotion.happy)),
          const SizedBox(height: 8),
          Center(child: Text('AA分账', style: text.headlineLarge)),
          Center(
            child: Text(
              'v$_version  ·  仅记账提醒，资金走微信/支付宝',
              style: text.bodySmall,
            ),
          ),
          const SizedBox(height: 20),
          _LinkRow(label: '用户协议'),
          _LinkRow(label: '隐私政策'),
          _LinkRow(label: '开源声明'),
          const SizedBox(height: 16),
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('联系反馈', style: text.titleSmall),
                const SizedBox(height: 6),
                Text('feedback@aa.example.com', style: const TextStyle(color: AAColors.sky, fontFamily: 'ZCOOLKuaiLe', fontSize: 14)),
                const SizedBox(height: 8),
                Text('团团🐼：吃小笼包长大，帮大家把账算明白～', style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _version => '1.0.0';
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.titleMedium)),
          Text('>', style: const TextStyle(color: AAColors.inkSoft)),
        ],
      ),
    );
  }
}
