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
            const EmptyState(
              title: '还没有凭证，拍一张吧',
              subtitle: '小票、付款截图都可以哦',
              compact: true,
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: b.receipts.map((r) => _ReceiptBox(url: r.url)).toList(),
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
    // Demo 模式为 emoji 占位；真实模式展示上传后的图片
    if (url.startsWith('🧾')) {
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        absReceiptUrl(url),
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AAColors.cardWhite,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AAColors.ink, width: 1.5),
          ),
          child: const Icon(Icons.broken_image, color: AAColors.inkSoft, size: 24),
        ),
      ),
    );
  }
}
