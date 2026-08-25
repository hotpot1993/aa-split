import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/config.dart';
import '../../models/bill.dart';
import '../../models/bill_participant.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P33 凭证拍照页
/// Demo 模式：模拟拍摄（🧾 占位）；真实模式：调用系统相机/相册拍照，
/// 通过 BillRepository.addReceipt（multipart）上传到服务端
/// POST /bills/:id/receipts，成功后列表展示图片（/uploads 静态托管）。
class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key, required this.billId});
  final String billId;
  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(billsProvider).value ?? const <Bill>[];
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

    return AaScaffold(
      appBar: AaAppBar(
        title: '凭证拍照',
        headIcon: 'assets/icons/camera.png',
        iconImage: 'assets/icons/bulb.png',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _CameraFrame(onCapture: () => _capture(b)),
          const SizedBox(height: 12),
          Text('已拍 ${b.receipts.length} 张：',
              style: const TextStyle(
                  fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
          const SizedBox(height: 4),
          if (b.receipts.isEmpty)
            const Text('还没有凭证，拍一张吧',
                style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft))
          else
            Row(
              children: [
                for (var i = 0; i < b.receipts.take(2).length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: _PolaroidBox(url: b.receipts[i].url, rotate: i == 0 ? -2 : 2),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          DoodleButton(
            label: '完成，回记账页 ✓',
            big: true,
            onPressed: () => context.pop(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _capture(Bill bill) async {
    if (AppConfig.useMock) {
      final repo = ref.read(billRepositoryProvider);
      await repo.addReceipt(
        widget.billId,
        Receipt(id: 'r${DateTime.now().millisecondsSinceEpoch}', billId: widget.billId, url: '🧾'),
      );
      ref.read(refreshProvider.notifier).bump();
      if (!mounted) return;
      showAaToast(context, '已拍下一张凭证（演示）');
      return;
    }

    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      debugPrint('P33: capture start');
      // 系统相机/相册（Android 走 intent，无需 CAMERA 权限）
      final pick = ImagePicker();
      final src = await _chooseSource(context);
      debugPrint('P33: source chosen ${src?.name}');
      if (src == null) return;
      final file = await pick.pickImage(
        source: src,
        maxWidth: 1920,
        imageQuality: 85,
      );
      debugPrint('P33: picked=${file?.path}');
      if (file == null) {
        if (mounted) showAaToast(context, '没有选择照片');
        return;
      }
      if (!mounted) return;
      showAaToast(context, '上传中…');
      await ref
          .read(billRepositoryProvider)
          .addReceipt(widget.billId, Receipt(id: '', billId: widget.billId, url: file.path));
      debugPrint('P33: upload done');
      ref.read(refreshProvider.notifier).bump();
      if (mounted) showAaToast(context, '凭证已上传 ✓');
    } catch (e, st) {
      debugPrint('P33: error $e\n$st');
      if (mounted) showAaToast(context, '拍/传失败：$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// 选择拍照还是相册（保持手绘风 sheet）
  Future<ImageSource?> _chooseSource(BuildContext context) {
    return showAaSheet<ImageSource>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('凭证来源', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          DoodleButton(
            label: '📷 拍一张',
            expand: true,
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          const SizedBox(height: 8),
          DoodleButton(
            label: '🖼️ 从相册选',
            type: DoodleButtonType.secondary,
            expand: true,
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 相对路径 URL 归一化见 widgets/common.dart 的 absReceiptUrl

class _CameraFrame extends StatelessWidget {
  const _CameraFrame({required this.onCapture});
  final VoidCallback onCapture;
  @override
  Widget build(BuildContext context) {
    return PaperCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // 拍照取景框（Demo：h210 虚线 2.5 ink2 圆角 10/4/9/5 纸米底）
          Container(
            height: 210,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AAColors.paperDeep,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(4),
                bottomRight: Radius.circular(9),
                bottomLeft: Radius.circular(5),
              ),
              border: Border.all(color: AAColors.inkSoft, width: 2.5),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image(image: AssetImage('assets/icons/camera.png'), width: 62, height: 62),
                SizedBox(height: 6),
                Text('对准小票/截图',
                    style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
                SizedBox(height: 2),
                Text('4:3 · 支持9张 · 自动压缩',
                    style: TextStyle(
                        fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 按钮组（Demo .btn.mini x3）
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DoodleButton(
                label: '💡 闪光灯',
                mini: true,
                onPressed: () => showAaToast(context, '💡 闪光灯已开'),
              ),
              const SizedBox(width: 8),
              DoodleButton(
                label: '🖼 从相册选',
                mini: true,
                type: DoodleButtonType.secondary,
                onPressed: onCapture,
              ),
              const SizedBox(width: 8),
              DoodleButton(
                label: '📸 拍一张',
                mini: true,
                type: DoodleButtonType.primary,
                onPressed: onCapture,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 拍立得（Demo .polaroid 110px 版）
class _PolaroidBox extends StatelessWidget {
  const _PolaroidBox({required this.url, required this.rotate});
  final String url;
  final double rotate;
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: rotate / 180 * 3.14159265,
      child: Container(
        width: 110,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border.fromBorderSide(BorderSide(color: AAColors.ink, width: 2.5)),
          borderRadius: BorderRadius.all(Radius.circular(4)),
          boxShadow: [AATokens.polaroidShadow],
        ),
        child: Column(
          children: [
            Container(
              height: 70,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AAColors.paperDeep,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: AAColors.inkSoft, width: 2),
              ),
              child: url.startsWith('🧾')
                  ? const AaIconImage('assets/icons/receipt.png', size: 34)
                  : Image.network(
                      absReceiptUrl(url),
                      width: 110,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Text('🧾', style: TextStyle(fontSize: 22)),
                    ),
            ),
            const SizedBox(height: 4),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}
