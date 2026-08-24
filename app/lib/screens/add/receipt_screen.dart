import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/bill.dart';
import '../../models/bill_participant.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P33 凭证拍照页
class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.billId});
  final String billId;
  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  @override
  Widget build(BuildContext context) {
    final all = ref.watch(billsProvider);
    Bill? bill;
    for (final b in all) {
      if (b.id == widget.billId) {
        bill = b;
        break;
      }
    }
    if (bill == null) {
      return const AaScaffold(appBar: null, body: Center(child: EmptyState(title: '账单不存在')));
    }
    final b = bill;
    final text = Theme.of(context).textTheme;

    return AaScaffold(
      appBar: AppBar(title: const Text('凭证拍照')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _CameraFrame(onCapture: () => _capture(b)),
          const SizedBox(height: 16),
          Text('凭证（${b.receipts.length}）', style: text.titleSmall),
          const SizedBox(height: 8),
          if (b.receipts.isEmpty)
            const EmptyState(title: '还没有凭证，拍一张吧', compact: true)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: b.receipts
                  .map((r) => _ReceiptBox(url: r.url))
                  .toList(),
            ),
          const SizedBox(height: 16),
          DoodleButton(
            label: '完成',
            expand: true,
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }

  void _capture(Bill bill) {
    final repo = ref.read(billRepositoryProvider);
    repo.addReceipt(
      widget.billId,
      Receipt(id: 'r${DateTime.now().millisecondsSinceEpoch}', billId: widget.billId, url: '🧾'),
    );
    ref.read(refreshProvider.notifier).bump();
    showAaToast(context, '已拍下一张凭证');
  }
}

class _CameraFrame extends StatelessWidget {
  const _CameraFrame({required this.onCapture});
  final VoidCallback onCapture;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 260,
            height: 180,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AAColors.cardWhite,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AAColors.ink, width: 2),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_camera, color: AAColors.inkSoft, size: 40),
                SizedBox(height: 8),
                Text('点下方拍照键，把镜头对准小票',
                    style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
              ],
            ),
          ),
          // 四角涂鸦
          const Positioned(top: -4, left: -4, child: _Corner()),
          const Positioned(top: -4, right: -4, child: _Corner()),
          const Positioned(bottom: -4, left: -4, child: _Corner()),
          const Positioned(bottom: -4, right: -4, child: _Corner()),
          Positioned(
            bottom: -30,
            right: 0,
            child: GestureDetector(
              onTap: onCapture,
              child: Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: AAColors.coral,
                  shape: SketchyBorder(
                    side: const BorderSide(color: AAColors.ink, width: AATokens.stroke),
                    seed: 71,
                    bow: 5,
                  ),
                  shadows: const [BoxShadow(color: AAColors.ink, offset: AATokens.shadowOffset)],
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(2),
      child: Icon(Icons.star, color: AAColors.coral, size: 16),
    );
  }
}

class _ReceiptBox extends StatelessWidget {
  const _ReceiptBox({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AAColors.cardWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AAColors.ink, width: 1.5),
      ),
      child: Text(url, style: const TextStyle(fontSize: 30)),
    );
  }
}
