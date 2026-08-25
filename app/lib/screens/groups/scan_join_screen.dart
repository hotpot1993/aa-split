import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/invite_link.dart';
import '../../providers/refresh_provider.dart';
import '../../providers/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// 扫一扫入群 —— 扫描群组邀请二维码，识别后自动加入对应群组。
///
/// 页面：相机取景 + 手绘四角框 + 两个兜底入口（从相册扫 / 粘贴邀请链接）。
/// 相机不可用（权限拒绝/模拟器异常）时展示友好错误页，仍可通过链接入群。
class ScanJoinScreen extends ConsumerStatefulWidget {
  const ScanJoinScreen({super.key});

  @override
  ConsumerState<ScanJoinScreen> createState() => _ScanJoinScreenState();
}

class _ScanJoinScreenState extends ConsumerState<ScanJoinScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );

  /// 正在处理（防重复识别 / 防重复加入）
  bool _handling = false;

  /// 最近一次未识别的码内容（避免同一个无效码刷屏提示）
  String? _lastBad;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 统一的「识别到一个二维码 → 解析 → 入群」入口
  Future<void> _handleValue(String value) async {
    if (_handling || !mounted) return;
    final code = parseInviteCode(value);
    if (code == null) {
      if (_lastBad != value) {
        _lastBad = value;
        showAaToast(context, '这不是群组邀请码，换一张试试');
      }
      return;
    }
    _handling = true;
    try {
      final result = await ref.read(groupRepositoryProvider).join(code);
      if (!mounted) return;
      ref.read(refreshProvider.notifier).bump();
      await _controller.stop();
      if (!mounted) return;
      showAaToast(context,
          result.alreadyJoined ? '已在「${result.name}」中' : '已加入「${result.name}」🎉');
      context.pushReplacement('/groups/${result.id}');
    } catch (_) {
      _handling = false;
      if (!mounted) return;
      showAaToast(context, '邀请码无效，请确认是群主发来的二维码');
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling || !mounted) return;
    final value = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    await _handleValue(value);
  }

  /// 兜底一：从相册选择二维码图片识别（Android / 真机 iOS 支持）
  Future<void> _pickFromAlbum() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null || !mounted) return;
      final capture = await _controller.analyzeImage(picked.path);
      if (!mounted) return;
      final value = (capture == null || capture.barcodes.isEmpty)
          ? null
          : capture.barcodes.first.rawValue;
      if (value == null || value.isEmpty) {
        showAaToast(context, '没识别到二维码，换张图片试试');
        return;
      }
      await _handleValue(value);
    } catch (_) {
      if (!mounted) return;
      showAaToast(context, '当前设备不支持相册识别，请直接对着二维码扫');
    }
  }

  void _toggleTorch() {
    try {
      _controller.toggleTorch();
    } catch (_) {
      // 个别机型不支持闪光灯，忽略
    }
  }

  @override
  Widget build(BuildContext context) {
    return AaScaffold(
      appBar: AaAppBar(title: '📷 扫一扫', icon: '🔦', onIconTap: _toggleTorch),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PaperCard(
            withTape: true,
            tapeColor: AATokens.tapeMint,
            child: Column(
              children: [
                SizedBox(height: 6),
                Text('对准群组邀请二维码',
                    style: TextStyle(
                        fontFamily: AAFonts.title,
                        fontSize: 14,
                        color: AAColors.ink)),
                SizedBox(height: 10),
                // 取景区：手绘圆角框 + 相机预览 + 四角定位框
                Container(
                  decoration: BoxDecoration(
                    color: AAColors.ink,
                    borderRadius: AARadii.qr,
                    border: Border.all(color: AAColors.ink, width: 2.5),
                  ),
                  child: ClipRRect(
                    borderRadius: AARadii.qr,
                    child: SizedBox(
                      height: 280,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: _controller,
                            onDetect: _onDetect,
                            placeholderBuilder: (_) => Center(
                              child: Text('📷 相机启动中…',
                                  style: TextStyle(
                                      fontFamily: AAFonts.title,
                                      fontSize: 13,
                                      color: AAColors.paper)),
                            ),
                            errorBuilder: (_, error) => _CameraError(
                                permissionDenied: error.errorCode ==
                                    MobileScannerErrorCode.permissionDenied),
                          ),
                          // 四角定位框（仅装饰提示，识别范围覆盖整屏）
                          IgnorePointer(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: CustomPaint(painter: _CornerPainter()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 10),
                Text('识别到群组邀请码后会自动加入',
                    style: TextStyle(
                        fontFamily: AAFonts.title,
                        fontSize: 13,
                        color: AAColors.inkSoft)),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DoodleButton(
                      label: '🖼 从相册扫',
                      type: DoodleButtonType.ghost,
                      mini: true,
                      onPressed: _pickFromAlbum,
                    ),
                    SizedBox(width: 8),
                    DoodleButton(
                      label: '🔗 粘贴链接',
                      type: DoodleButtonType.ghost,
                      mini: true,
                      onPressed: () => context.push('/groups/join-link'),
                    ),
                  ],
                ),
                SizedBox(height: 6),
              ],
            ),
          ),
          SizedBox(height: 16),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Text(
              '怎么拿到邀请码？让群主在群组里点「邀请成员」，把邀请二维码发给你；'
              '或直接把邀请链接复制给你。',
              style: TextStyle(
                  fontFamily: AAFonts.title, fontSize: 13, color: AAColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

/// 相机不可用时的错误占位
class _CameraError extends StatelessWidget {
  const _CameraError({required this.permissionDenied});

  final bool permissionDenied;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AAColors.ink,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('😿',
              style: TextStyle(fontSize: 26, color: AAColors.paper)),
          SizedBox(height: 6),
          Text(
            permissionDenied
                ? '相机权限被拒绝了\n去系统设置里给 AA分账 开相机权限'
                : '相机暂不可用',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AAFonts.title, fontSize: 13, color: AAColors.paper),
          ),
          SizedBox(height: 6),
          Text('也可以试试下方的「粘贴链接」入群',
              style: TextStyle(
                  fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
        ],
      ),
    );
  }
}

/// 手绘四角定位框
class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AAColors.paper
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 22.0;
    final w = size.width;
    final h = size.height;
    // 左上
    canvas.drawLine(const Offset(0, len), Offset.zero, p);
    canvas.drawLine(Offset.zero, Offset(len, 0), p);
    // 右上
    canvas.drawLine(Offset(w - len, 0), Offset(w, 0), p);
    canvas.drawLine(Offset(w, 0), Offset(w, len), p);
    // 左下
    canvas.drawLine(Offset(0, h - len), Offset(0, h), p);
    canvas.drawLine(Offset(0, h), Offset(len, h), p);
    // 右下
    canvas.drawLine(Offset(w, h - len), Offset(w, h), p);
    canvas.drawLine(Offset(w, h), Offset(w - len, h), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
