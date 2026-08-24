import 'dart:math';

import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

/// 手绘 Toast（小纸片 + 团团 + 文案）—— UI规范 §7.5 / §8.1
void showAaToast(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final entry = OverlayEntry(
    builder: (_) => AaToast(message: message),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(seconds: 2), entry.remove);
}

class AaToast extends StatelessWidget {
  const AaToast({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 96,
      left: 24,
      right: 24,
      child: Material(
        color: Colors.transparent,
        child: PaperCard(
          color: AAColors.cardWhite,
          withTape: true,
          tapeColor: AAColors.lemon,
          tiltSeed: 'toast',
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const TuanTuan(emotion: TuanTuanEmotion.happy, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'ZCOOLKuaiLe',
                    fontSize: 14,
                    color: AAColors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 破坏性操作二次确认弹窗（撕纸顶边 + 图钉 + 团团）—— UI规范 §9.3
Future<bool?> showAaConfirm(
  BuildContext context, {
  required String title,
  String? subtitle,
  String confirmLabel = '确认',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AAColors.ink.withValues(alpha: 0.35),
    builder: (ctx) => _ConfirmSheet(
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
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
  });

  final String title;
  final String? subtitle;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return _AaSheet(
      maxHeight: 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const TuanTuan(emotion: TuanTuanEmotion.excited, size: 84),
          const SizedBox(height: 10),
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
