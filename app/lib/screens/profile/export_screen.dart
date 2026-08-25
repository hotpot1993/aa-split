import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aa_design/aa_design.dart';

import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P53 数据导出 —— 对齐 docs/ui-demo/index.html
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});
  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

enum _Format { excel, csv, pdf }

class _ExportScreenState extends ConsumerState<ExportScreen> {
  _Format _format = _Format.excel;
  String _scope = '全部';
  bool _packing = false;
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return AaScaffold(
      appBar: AaAppBar(
        title: '数据导出',
        headIcon: 'assets/icons/export.png',
        icon: '📤',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Text('导出范围：',
              style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['全部', '按群组', '按月份'].map((s) {
              final on = _scope == s;
              return GestureDetector(
                onTap: () => setState(() => _scope = s),
                child: HandTag(s, selected: on, fontSize: 12),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text('文件格式：',
              style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _Format.values.map((f) {
              final on = _format == f;
              return GestureDetector(
                onTap: () => setState(() => _format = f),
                child: HandTag(f.name.toUpperCase(), selected: on, fontSize: 12),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // 打包卡（Demo：🎒 + mini dim + 进度条）
          PaperCard(
            withTape: true,
            tapeColor: AATokens.tapeMint,
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            child: Column(
              children: [
                if (_done)
                  const Image(image: AssetImage('assets/icons/box.png'), width: 44, height: 44)
                else
                  const Image(image: AssetImage('assets/icons/box.png'), width: 44, height: 44),
                const SizedBox(height: 4),
                const Text('团团正在打包你的账本…',
                    style: TextStyle(
                        fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
                const SizedBox(height: 10),
                _DemoProgress(progress: _packing ? 1.0 : 0.72),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DoodleButton(
            label: _packing || _done ? '开始导出 ✈️' : '开始导出 ✈️',
            big: true,
            onPressed: _packing ? null : _startPack,
          ),
          if (_done) ...[
            const SizedBox(height: 10),
            DoodleButton(
              label: '下载文件',
              type: DoodleButtonType.secondary,
              big: true,
              onPressed: () => showAaToast(context, '📦 打包好啦！请查收'),
            ),
          ],
          const SizedBox(height: 12),
          const Text('历史记录：',
              style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
          const SizedBox(height: 4),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('6月账单.xlsx · 6月1日',
                    style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.ink)),
                const HandTag('已生成', dense: true, variant: ChipVariant.green),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _startPack() {
    setState(() {
      _packing = true;
      _done = false;
    });
    Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() {
        _packing = false;
        _done = true;
      });
    });
  }
}

/// Demo 进度条：`height:14px;border:2.5px solid var(--ink);border-radius:999px;
/// background:#fff`，填充 `repeating-linear-gradient(90deg, var(--coral) 0 12px,transparent 12px 18px)`
/// + 右侧 2px 墨线
class _DemoProgress extends StatelessWidget {
  const _DemoProgress({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: AAColors.cardWhite,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AAColors.ink, width: 2.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0, 1),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: AAColors.ink, width: 2)),
              ),
              child: CustomPaint(painter: _StripeBarPainter()),
            ),
          ),
        ),
      ),
    );
  }
}

class _StripeBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    var x = 0.0;
    while (x < size.width) {
      canvas.drawRect(
        Rect.fromLTWH(x, 0, 12, size.height),
        Paint()..color = AAColors.coral,
      );
      x += 18;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
