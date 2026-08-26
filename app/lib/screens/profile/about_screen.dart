import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';
import 'package:dio/dio.dart';

import '../../core/config.dart';
import '../../core/update/app_update.dart';
import '../../core/update/update_installer.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P54 关于页 —— 对齐 docs/ui-demo/index.html
/// 「检查更新」：手动触发 GET /app/version → 有新版时确认 → 下载 APK → 调起系统安装器。
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final _repo = AppUpdateRepository();
  final _installer = UpdateInstaller();

  bool _checking = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return AaScaffold(
      appBar: AaAppBar(
        title: '关于我们',
        headIcon: 'assets/icons/mail.png',
        icon: '🏷',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SizedBox(height: 18),
          Center(child: TuanTuanPanda(size: 110)),
          SizedBox(height: 6),
          Center(
            child: Text(
              'AA分账',
              style: TextStyle(
                fontFamily: AAFonts.title,
                fontSize: 24,
                color: AAColors.ink,
              ),
            ),
          ),
          SizedBox(height: 2),
          // 版本号与构建号：单一来源 AppConfig（与 pubspec.yaml 一致，见 version_consistency_test）
          // 英文/数字点缀（规范 §4 第五级：Caveat 手写体）
          Center(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'v${AppConfig.appVersion}',
                    style: TextStyle(
                      fontFamily: AAFonts.accent,
                      fontSize: 15,
                      color: AAColors.inkSoft,
                    ),
                  ),
                  TextSpan(
                    text: ' · 构建 ${AppConfig.appBuildNumber} · 由团团和程序员们一起做 💕',
                    style: TextStyle(
                      fontFamily: AAFonts.title,
                      fontSize: 12,
                      color: AAColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                _row(
                  '检查更新',
                  leadImage: 'assets/icons/signal.png',
                  value: _checking
                      ? '检查中…'
                      : (_status.isNotEmpty ? _status : null),
                  onTap: _checking ? null : _checkUpdate,
                ),
                _row(
                  '用户协议',
                  leadImage: 'assets/icons/scroll.png',
                  onTap: () => context.push('/about/agreement'),
                ),
                _row(
                  '隐私政策',
                  leadImage: 'assets/icons/locked.png',
                  onTap: () => context.push('/about/privacy'),
                ),
                _row(
                  '开源声明',
                  leadImage: 'assets/icons/scroll.png',
                  onTap: () => context.push('/about/oss'),
                ),
                _row(
                  '联系我们',
                  leadImage: 'assets/icons/inbox.png',
                  value: 'davedefy@163.com',
                  showBorder: false,
                ),
              ],
            ),
          ),
          SizedBox(height: 6),
          Center(
            child: Text(
              '© 2026 AA分账 · DeepSeek Harness',
              style: TextStyle(
                fontFamily: AAFonts.title,
                fontSize: 12,
                color: AAColors.inkSoft,
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _checkUpdate() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _status = '';
    });
    try {
      final info = await _repo.check();
      if (!mounted) return;
      if (_repo.hasUpdate(info)) {
        setState(() => _status = '发现新版 v${info.latestVersion}');
        final notesPart = info.notes.isEmpty ? '' : '${info.notes}\n\n';
        final go = await showAaConfirm(
          context,
          title: '发现新版本 v${info.latestVersion}',
          subtitle: '$notesPart是否下载新版本并安装？',
          confirmLabel: '下载安装',
          showMascot: false,
        );
        if (go == true && mounted) {
          await _downloadAndInstall(info);
        }
      } else {
        setState(() => _status = '已是最新 v${AppConfig.appVersion}');
        if (mounted) showAaToast(context, '已是最新版本');
      }
    } on Exception catch (e) {
      setState(() => _status = '检查失败');
      if (mounted) showAaToast(context, '检查更新失败：$e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// 下载（进度弹窗，可取消）→ 调起系统安装器
  Future<void> _downloadAndInstall(AppVersionInfo info) async {
    if (!mounted) return;
    final progress = ValueNotifier<double>(0);
    final cancel = CancelToken();
    var installing = false;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ValueListenableBuilder<double>(
              valueListenable: progress,
              builder: (_, v, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('正在下载 v${info.latestVersion}…',
                      style: TextStyle(
                          fontFamily: AAFonts.title,
                          fontSize: 15,
                          color: AAColors.ink)),
                  SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: v,
                      minHeight: 8,
                      backgroundColor: AAColors.paperDeep,
                      color: AAColors.coral,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('${(v * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                          fontFamily: AAFonts.accent,
                          fontSize: 14,
                          color: AAColors.inkSoft)),
                  SizedBox(height: 4),
                  TextButton(
                    onPressed: () => cancel.cancel('用户取消'),
                    child: Text('取消',
                        style: TextStyle(color: AAColors.inkSoft)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final path = await _installer.download(
        info.downloadUrl,
        'aa-split-v${info.latestVersion}.apk',
        onProgress: (p) => progress.value = p,
        cancelToken: cancel,
      );
      if (!mounted) return;
      installing = true;
      Navigator.of(context, rootNavigator: true).pop(); // 关闭进度弹窗
      await _installer.install(path);
      if (mounted) showAaToast(context, '已调起安装，请按系统提示完成');
    } catch (e) {
      if (!installing && mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      if (mounted) showAaToast(context, '更新失败：$e');
    } finally {
      progress.dispose();
    }
  }

  Widget _row(
    String label, {
    String? value,
    String? leadImage,
    VoidCallback? onTap,
    bool showBorder = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (leadImage != null) ...[
                      AaIconImage(leadImage, size: 16),
                      SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: AAFonts.title,
                        fontSize: 15,
                        color: AAColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                if (value != null)
                  Text(
                    value,
                    style: TextStyle(
                      fontFamily: AAFonts.title,
                      fontSize: 15,
                      color: AAColors.ink,
                    ),
                  )
                else
                  Text(
                    '→',
                    style: TextStyle(fontSize: 15, color: AAColors.ink),
                  ),
              ],
            ),
          ),
        ),
        if (showBorder)
          CustomPaint(size: Size(double.infinity, 2.5), painter: _AboutDash()),
      ],
    );
  }
}

class _AboutDash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AAColors.ink
      ..strokeWidth = 2.5;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1.25), Offset(x + 7, 1.25), p);
      x += 14;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
