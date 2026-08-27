import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/config.dart';
import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../models/bill_participant.dart';
import '../../providers/data_providers.dart';
import '../../providers/notification_stream_provider.dart';
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

  /// 本次会话内新拍的凭证（真实模式追加服务端返回的 URL，Demo 模式追加 🧾 占位）。
  /// 与账单列表数据去重合并展示，保证「已拍 N 张」与预览框即时反映实际操作。
  List<Receipt> _taken = [];

  List<Receipt> get _allReceipts => [
        ..._taken,
        for (final r in _serverReceipts)
          if (!_taken.any((t) => t.id == r.id)) r,
      ];

  List<Receipt> _serverReceipts = const [];

  /// 小票 OCR 结果订阅（SSE分流）与二次确认去重
  StreamSubscription<Map<String, dynamic>>? _ocrSub;
  final Set<String> _prompted = {};

  @override
  void initState() {
    super.initState();
    // D5：P33 上传即识别 → SSE 推回 → 二次确认更新账单金额
    _ocrSub = ref.read(receiptOcrEventsProvider).listen(_onOcrEvent);
  }

  @override
  void dispose() {
    _ocrSub?.cancel();
    super.dispose();
  }

  /// p33 识别完成：更新凭证展示 → 按 D5 弹「更新账单金额？」二次确认
  Future<void> _onOcrEvent(Map<String, dynamic> e) async {
    if (e['kind'] != 'p33') return;
    final receiptId = e['receiptId'] as String?;
    if (receiptId == null || !mounted) return;
    final amount = e['amountCents'] as int?;
    final conf = (e['confidence'] as num?)?.toDouble() ?? 0;
    final currency = (e['currency'] as String?) ?? 'CNY';
    final okStatus = 'success';

    var touched = false;
    setState(() {
      _taken = [
        for (final r in _taken)
          if (r.id == receiptId)
            (touched = true,
             Receipt(
               id: r.id, billId: r.billId, url: r.url,
               amountCents: amount, confidence: conf, currency: currency,
               ocrStatus: okStatus,
             ))
              .$2
          else
            r,
      ];
      _serverReceipts = [
        for (final r in _serverReceipts)
          if (r.id == receiptId)
            (touched = true,
             Receipt(
               id: r.id, billId: r.billId, url: r.url,
               amountCents: amount, confidence: conf, currency: currency,
               ocrStatus: okStatus,
             ))
              .$2
          else
            r,
      ];
    });
    if (!touched) return;
    if (amount == null || conf < 0.6) return; // 识别不到/低置信：静默（D7/D10）
    if (!_prompted.add(receiptId)) return; // 每张只提示一次
    final ok = await showAaConfirm(
      context,
      title: '识别到 ${Fmt.yuan(amount)}',
      subtitle: currency != 'CNY'
          ? '币种为 $currency，可能非人民币，请核对'
          : '要更新账单金额吗？',
      confirmLabel: '更新账单 ✓',
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(billRepositoryProvider).update(widget.billId, amountCents: amount);
      ref.read(refreshProvider.notifier).bump();
      if (mounted) showAaToast(context, '已更新账单金额 ✓');
    } catch (err) {
      if (mounted) showAaToast(context, '更新金额失败：$err');
    }
  }

  /// 凭证识别状态行（徽标替代：金额/置信度/币种警告/重试）
  Widget _ocrStatusLine(Receipt r) {
    final style = TextStyle(
        fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft);
    if (r.amountCents != null) {
      final confTxt =
          r.confidence != null ? ' · 置信度 ${(r.confidence! * 100).round()}%' : '';
      final warn =
          r.currency != null && r.currency != 'CNY' ? ' · 币种 ${r.currency}?' : '';
      return Text('识别 ${Fmt.yuan(r.amountCents!)}$confTxt$warn', style: style);
    }
    if (r.ocrStatus == 'failed') {
      return Row(children: [
        Text('识别失败', style: style),
        SizedBox(width: 6),
        DoodleButton(
          label: '重试',
          mini: true,
          type: DoodleButtonType.secondary,
          onPressed: () => _retryOcr(r),
        ),
      ]);
    }
    return Text('识别中…', style: style);
  }

  Future<void> _retryOcr(Receipt r) async {
    if (AppConfig.useMock) {
      // Demo：1s 后模拟重试成功
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _onOcrEvent({
            'kind': 'p33',
            'receiptId': r.id,
            'amountCents': 12345,
            'confidence': 0.95,
            'currency': 'CNY',
          });
        }
      });
      return;
    }
    try {
      await ref.read(billRepositoryProvider).retryOcr(widget.billId, r.id);
      if (mounted) showAaToast(context, '已重新识别');
    } catch (e) {
      if (mounted) showAaToast(context, '重试失败：$e');
    }
  }

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
    _serverReceipts = bill?.receipts ?? [];
    if (bill == null) {
      return AaScaffold(appBar: null, body: Center(child: EmptyState(title: '账单不存在')));
    }
    final b = bill;
    final receipts = _allReceipts;

    return AaScaffold(
      appBar: AaAppBar(
        title: '凭证拍照',
        headIcon: 'assets/icons/camera.png',
        iconImage: 'assets/icons/bulb.png',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _CameraFrame(
            onCapture: () => _capture(b),
            preview: receipts.isEmpty ? null : _ReceiptThumb(url: receipts.last.url),
            previewCount: receipts.length,
          ),
          SizedBox(height: 4),
          Text('识别金额仅用于填写账单',
              style: TextStyle(
                  fontFamily: AAFonts.title, fontSize: 11, color: AAColors.inkSoft)),
          SizedBox(height: 12),
          Text('已拍 ${receipts.length} 张：',
              style: TextStyle(
                  fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
          SizedBox(height: 4),
          if (receipts.isEmpty)
            Text('还没有凭证，拍一张吧',
                style: TextStyle(fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft))
          else ...[
            Row(
              children: [
                for (var i = 0; i < receipts.take(2).length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: _PolaroidBox(url: receipts[i].url, rotate: i == 0 ? -2 : 2),
                  ),
              ],
            ),
            SizedBox(height: 6),
            for (final r in receipts)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _ocrStatusLine(r),
              ),
          ],
          SizedBox(height: 16),
          DoodleButton(
            label: '完成，回记账页 ✓',
            big: true,
            onPressed: () => context.pop(),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _capture(Bill bill) async {
    if (AppConfig.useMock) {
      // 记账页同款「模拟拍摄凭证」提示弹窗（P30/P33 演示行为一致）
      final ok = await showAaConfirm(
        context,
        title: '模拟拍摄凭证',
        subtitle: 'Demo 中自动生成一张小票',
        confirmLabel: '拍摄',
      );
      if (ok != true || !mounted) return;
      final repo = ref.read(billRepositoryProvider);
      final r = await repo.addReceipt(
        widget.billId,
        Receipt(id: 'r${DateTime.now().millisecondsSinceEpoch}', billId: widget.billId, url: '🧾'),
      );
      _taken.add(r);
      ref.read(refreshProvider.notifier).bump();
      if (!mounted) return;
      setState(() {});
      showAaToast(context, '已拍下一张凭证（演示）');
      // Demo：1s 后模拟识别（与真实 SSE 同一处理路径）
      Future<void>.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _onOcrEvent({
            'kind': 'p33',
            'receiptId': r.id,
            'amountCents': 12345,
            'confidence': 0.95,
            'currency': 'CNY',
          });
        }
      });
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
      // 先本地预览，选中即反馈（不等上传完成）
      final pendingPath = file.path;
      setState(() => _taken.add(Receipt(id: 'tmp-$pendingPath', billId: widget.billId, url: pendingPath)));
      showAaToast(context, '上传中…');
      final uploaded = await ref
          .read(billRepositoryProvider)
          .addReceipt(widget.billId, Receipt(id: '', billId: widget.billId, url: pendingPath));
      debugPrint('P33: upload done');
      _taken.removeWhere((t) => t.id == 'tmp-$pendingPath');
      _taken.add(uploaded);
      ref.read(refreshProvider.notifier).bump();
      if (mounted) setState(() {});
      if (mounted) showAaToast(context, '凭证已上传 ✓');
    } catch (e, st) {
      debugPrint('P33: error $e\n$st');
      // 上传失败：移除临时预览并提示
      if (mounted) {
        setState(() => _taken.removeWhere((t) => t.id.startsWith('tmp-')));
        showAaToast(context, '拍/传失败：$e');
      }
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
          SizedBox(height: 12),
          DoodleButton(
            label: '拍一张',
            leadingImage: 'assets/icons/camera.png',
            expand: true,
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          SizedBox(height: 8),
          DoodleButton(
            label: '从相册选',
            leadingImage: 'assets/icons/picture.png',
            type: DoodleButtonType.secondary,
            expand: true,
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 相对路径 URL 归一化见 widgets/common.dart 的 absReceiptUrl

class _CameraFrame extends StatelessWidget {
  const _CameraFrame({
    required this.onCapture,
    this.preview,
    this.previewCount = 0,
  });
  final VoidCallback onCapture;

  /// 最近一张凭证的缩略图（拍/选后展示在取景框内）
  final Widget? preview;
  final int previewCount;

  static const _frameRadius = BorderRadius.only(
    topLeft: Radius.circular(10),
    topRight: Radius.circular(4),
    bottomRight: Radius.circular(9),
    bottomLeft: Radius.circular(5),
  );

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
              borderRadius: _frameRadius,
              border: Border.all(color: AAColors.inkSoft, width: 2.5),
            ),
            child: preview != null
                // 已有凭证：取景框内展示最近一张缩略图
                ? ClipRRect(
                    borderRadius: _frameRadius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        preview!,
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AAColors.ink.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('已拍 $previewCount 张',
                                style: TextStyle(
                                    fontFamily: AAFonts.title,
                                    fontSize: 11,
                                    color: AAColors.paper)),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image(image: AssetImage('assets/icons/camera.png'), width: 62, height: 62),
                      SizedBox(height: 6),
                      Text('对准小票/截图',
                          style: TextStyle(fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                      SizedBox(height: 2),
                      Text('4:3 · 支持9张 · 自动压缩',
                          style: TextStyle(
                              fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
                    ],
                  ),
          ),
          SizedBox(height: 10),
          // 按钮组（Demo .btn.mini x3）
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DoodleButton(
                label: '闪光灯',
                leadingImage: 'assets/icons/bulb.png',
                mini: true,
                onPressed: () => showAaToast(context, '💡 闪光灯已开'),
              ),
              SizedBox(width: 8),
              DoodleButton(
                label: '从相册选',
                leadingImage: 'assets/icons/picture.png',
                mini: true,
                type: DoodleButtonType.secondary,
                onPressed: onCapture,
              ),
              SizedBox(width: 8),
              DoodleButton(
                label: '拍一张',
                leadingImage: 'assets/icons/camera.png',
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
        decoration: BoxDecoration(
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
              child: _ReceiptThumb(url: url),
            ),
            SizedBox(height: 4),
            SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

/// 凭证缩略图：Demo 🧾 占位 → 本地文件（刚拍/选）→ 服务端 URL。
/// 取景框预览与拍立得列表共用，保证两者一致。
class _ReceiptThumb extends StatelessWidget {
  const _ReceiptThumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('🧾')) {
      return AaIconImage('assets/icons/receipt.png', size: 34);
    }
    final isLocal = !url.startsWith('http') && File(url).existsSync();
    if (isLocal) {
      return Image.file(
        File(url),
        width: 110,
        height: 70,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Text('🧾', style: TextStyle(fontSize: 22)),
      );
    }
    return Image.network(
      absReceiptUrl(url),
      width: 110,
      height: 70,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Text('🧾', style: TextStyle(fontSize: 22)),
    );
  }
}
