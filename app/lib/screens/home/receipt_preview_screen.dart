import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/bill.dart';
import '../../models/bill_participant.dart' show Receipt;
import '../../providers/data_providers.dart';
import '../../providers/refresh_provider.dart';
import '../../providers/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// 小票大图预览 —— 点击账单详情页拍立得缩略图进入；
/// 支持双指缩放，底部提供「重新拍照 / 从相册换图」替换当前凭证图片。
class ReceiptPreviewScreen extends ConsumerStatefulWidget {
  const ReceiptPreviewScreen({
    super.key,
    required this.billId,
    required this.receiptId,
  });

  final String billId;
  final String receiptId;

  @override
  ConsumerState<ReceiptPreviewScreen> createState() =>
      _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends ConsumerState<ReceiptPreviewScreen> {
  bool _busy = false;

  Receipt? get _receipt {
    for (final b in ref.watch(billsProvider).value ?? const <Bill>[]) {
      if (b.id != widget.billId) continue;
      for (final r in b.receipts) {
        if (r.id == widget.receiptId) return r;
      }
    }
    return null;
  }

  Future<void> _replace(ImageSource source) async {
    if (_busy) return;
    try {
      final file = await ImagePicker()
          .pickImage(source: source, maxWidth: 1920, imageQuality: 85);
      if (file == null || !mounted) return;
      setState(() => _busy = true);
      await ref
          .read(billRepositoryProvider)
          .replaceReceipt(widget.billId, widget.receiptId, file.path);
      if (!mounted) return;
      ref.read(refreshProvider.notifier).bump();
      showAaToast(context, '📷 小票已更新');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) showAaToast(context, '替换失败：$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _image(String url) {
    if (url.isEmpty || url.startsWith('🧾')) {
      return Center(child: Text('🧾', style: TextStyle(fontSize: 90)));
    }
    final isLocal = !url.startsWith('http') && File(url).existsSync();
    return isLocal
        ? Image.file(File(url), fit: BoxFit.contain)
        : Image.network(
            absReceiptUrl(url),
            fit: BoxFit.contain,
            loadingBuilder: (_, child, p) =>
                p == null ? child : Center(child: AaLoading()),
            errorBuilder: (_, _, _) =>
                Center(child: Text('🧾', style: TextStyle(fontSize: 90))),
          );
  }

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    return Scaffold(
      backgroundColor: AAColors.ink,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部：返回 + 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Text('‹ 返回',
                          style: TextStyle(
                              fontFamily: AAFonts.title,
                              fontSize: 16,
                              color: AAColors.paper)),
                    ),
                  ),
                  Spacer(),
                  Text('小票预览',
                      style: TextStyle(
                          fontFamily: AAFonts.title,
                          fontSize: 16,
                          color: AAColors.paper)),
                  Spacer(),
                  SizedBox(
                      width:
                          48), // 占位对称（右侧无按钮，保持标题居中）
                ],
              ),
            ),
            // 大图：双指缩放
            Expanded(
              child: Center(
                child: InteractiveViewer(
                  minScale: 0.6,
                  maxScale: 5,
                  child: receipt == null
                      ? Text('🧾 找不到这张小票', style: TextStyle(fontSize: 16, color: AAColors.paper))
                      : _image(receipt.url),
                ),
              ),
            ),
            // 底部操作：重新拍照 / 从相册换图
            if (receipt != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: DoodleButton(
                        label: _busy ? '替换中…' : '📷 重新拍照',
                        type: DoodleButtonType.secondary,
                        mini: true,
                        expand: true,
                        onPressed:
                            _busy ? null : () => _replace(ImageSource.camera),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: DoodleButton(
                        label: _busy ? '替换中…' : '🖼️ 从相册换图',
                        mini: true,
                        expand: true,
                        onPressed:
                            _busy ? null : () => _replace(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
