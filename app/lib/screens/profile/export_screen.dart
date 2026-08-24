import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/bill.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P53 数据导出页
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
    final text = Theme.of(context).textTheme;
    final bills = ref.watch(billsProvider).value ?? const <Bill>[];

    return AaScaffold(
      appBar: AppBar(title: const Text('数据导出')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_packing) _Packing(onDone: () => setState(() => _done = true)),
          if (_done) const _Done(),

          SectionTitle('导出范围'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['全部', '按群组', '按月份'].map((s) {
              final on = _scope == s;
              return GestureDetector(
                onTap: () => setState(() => _scope = s),
                child: HandTag(
                  label: s,
                  color: on ? AAColors.coral : AAColors.inkSoft,
                  textColor: on ? AAColors.coral : AAColors.ink,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          SectionTitle('文件格式'),
          Row(
            children: _Format.values
                .map((f) => Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _format = f),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _format == f ? AAColors.lemon.withValues(alpha: 0.5) : AAColors.cardWhite,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _format == f ? AAColors.coral : AAColors.ink, width: 1.5),
                          ),
                          child: Text(f.name.toUpperCase(),
                              style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 14, color: AAColors.ink)),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),
          Text('共 ${bills.length} 笔账单可导出', style: text.bodySmall),
          const SizedBox(height: 20),
          DoodleButton(
            label: _packing || _done ? '打包中…' : '开始打包',
            expand: true,
            onPressed: _packing ? null : _startPack,
          ),
          if (_done)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DoodleButton(
                label: '下载文件',
                type: DoodleButtonType.secondary,
                expand: true,
                onPressed: () => showAaToast(context, '已保存到本地'),
              ),
            ),
          const SizedBox(height: 12),
          Text('历史导出记录：暂无', style: text.bodySmall),
        ],
      ),
    );
  }

  void _startPack() {
    setState(() {
      _packing = true;
      _done = false;
    });
  }
}

class _Packing extends StatelessWidget {
  const _Packing({required this.onDone});
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) {
    Timer(const Duration(milliseconds: 1800), onDone);
    return Column(
      children: [
        const Text('正在打包你的账单…', style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 16, color: AAColors.ink)),
        const SizedBox(height: 12),
        const TuanTuan(size: 140, emotion: TuanTuanEmotion.excited),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Center(child: Text('📦', style: TextStyle(fontSize: 56))),
        const SizedBox(height: 8),
        const HighlightText('打包好啦！',
            style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 22, color: AAColors.ink)),
        const SizedBox(height: 8),
      ],
    );
  }
}
