import 'dart:math';

import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

/// 手绘 Toast —— 严格照搬 Demo `.toast`：
/// `background:#443A32;color:#FBF3E4;font-size:13px;padding:9px 16px;
///  border-radius:12px 5px 11px 6px;bottom:104px`
/// 出现：淡入 + 上移 8px → 0（.toast.show，250ms）；1.6s 后消失
void showAaToast(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(
    builder: (_) => AaToast(message: message),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 1600), entry.remove);
}

class AaToast extends StatefulWidget {
  const AaToast({super.key, required this.message});
  final String message;

  @override
  State<AaToast> createState() => _AaToastState();
}

class _AaToastState extends State<AaToast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 键盘弹出时自动上移，避免被键盘遮挡
    final kb = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_c.value);
        return Positioned(
          left: 0,
          right: 0,
          bottom: 104 + kb,
          child: IgnorePointer(
            child: Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - t)),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 320),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: AAColors.ink,
                      borderRadius: AARadii.toast,
                    ),
                    child: Text(
                      widget.message,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'ZCOOLKuaiLe',
                        fontSize: 13,
                        color: AAColors.paper,
                        height: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 破坏性操作二次确认弹窗（撕纸顶边 + 图钉 + 团团）—— UI规范 §9.3
/// [showMascot] 为 false 时不展示吉祥物（如「退出登录」弹窗保持简洁）。
Future<bool?> showAaConfirm(
  BuildContext context, {
  required String title,
  String? subtitle,
  String confirmLabel = '确认',
  bool showMascot = true,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AAColors.ink.withValues(alpha: 0.35),
    // 必须 isScrollControlled：否则弹层高度被限制在 9/16 屏高内，
    // FractionallySizedBox(0.5) 再叠乘后内容被截断（底部按钮显示不全）
    isScrollControlled: true,
    builder: (ctx) => _ConfirmSheet(
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
      showMascot: showMascot,
    ),
  );
}

/// 通用底部弹层（撕纸顶边 + 图钉）
Future<T?> showAaSheet<T>(
  BuildContext context, {
  required Widget child,
  double maxHeight = 0.86,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: AAColors.ink.withValues(alpha: 0.35),
    builder: (ctx) => _AaSheet(maxHeight: maxHeight, child: child),
  );
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    this.subtitle,
    required this.confirmLabel,
    this.showMascot = true,
  });

  final String title;
  final String? subtitle;
  final String confirmLabel;
  final bool showMascot;

  @override
  Widget build(BuildContext context) {
    return _AaSheet(
      maxHeight: 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showMascot) ...[
            const TuanTuan(emotion: TuanTuanEmotion.excited, size: 84),
            const SizedBox(height: 10),
          ],
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DoodleButton(
                  label: '再想想',
                  type: DoodleButtonType.secondary,
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DoodleButton(
                  label: confirmLabel,
                  expand: true,
                  color: AAColors.berry,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AaSheet extends StatelessWidget {
  const _AaSheet({required this.child, required this.maxHeight});

  final Widget child;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return FractionallySizedBox(
      heightFactor: maxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: ShapeDecoration(
                color: surface,
                shape: _SheetTopShape(),
                shadows: const [
                  BoxShadow(
                    color: AAColors.ink,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 6,
            left: 14,
            child: const PinDecorator(),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 16),
              child: SingleChildScrollView(
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 撕纸顶边形状：顶边平直，顶端往内锯齿（模拟撕开）
class _SheetTopShape extends ShapeBorder {
  @override
  EdgeInsetsGeometry get dimensions =>
      EdgeInsets.only(top: 16).add(const EdgeInsets.all(16));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final rnd = Random(8);
    final path = Path()..moveTo(0, rect.top + 16);
    final w = rect.width;
    const tooth = 5;
    var y = rect.top + 16;
    path.lineTo(0, y);
    var x = 0.0;
    while (x < w) {
      final nx = x + tooth + rnd.nextDouble() * 5;
      path.lineTo(nx, y - 3 + rnd.nextDouble() * 6);
      x = nx + tooth;
      if (x < w) path.lineTo(x, y + 2 + rnd.nextDouble() * 4);
    }
    path.lineTo(w, y);
    path.lineTo(w, rect.bottom);
    path.lineTo(0, rect.bottom);
    path.close();
    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(16), textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}
