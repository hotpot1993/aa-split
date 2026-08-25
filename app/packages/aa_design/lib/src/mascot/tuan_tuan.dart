import 'dart:math';

import 'package:flutter/material.dart';

/// 吉祥物情绪（保留兼容）。
/// 说明：新视觉规范的 `docs/pic/tuantuan.svg`（书桌前记账的团团）为单表情插画，
/// 情绪差异已由统一插画表达；`emotion` / `withPencil` 参数仅作 API 兼容保留。
enum TuanTuanEmotion { happy, sleepy, excited, celebrate }

/// 吉祥物「团团」（UI规范 §2）
/// 渲染素材：`docs/pic/tuantuan.svg` 的光栅化产物 `assets/mascot/tuantuan.png`
/// （512x512 透明底，由 scripts/process-icons.ps1 生成）。
/// 使用场景：空状态插画、净额卡陪伴、庆祝、引导提示。
class TuanTuan extends StatelessWidget {
  const TuanTuan({
    super.key,
    this.emotion = TuanTuanEmotion.happy,
    this.size = 120,
    this.withPencil = false,
  });

  final TuanTuanEmotion emotion;
  final double size;
  final bool withPencil;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const Image(
        image: AssetImage('assets/mascot/tuantuan.png'),
        fit: BoxFit.contain,
      ),
    );
  }
}

/// 团团插画 —— 可选 `.wob` 摇晃动画（0/100% -3°，50% 3°）。
class TuanTuanPanda extends StatefulWidget {
  const TuanTuanPanda({
    super.key,
    this.size = 110,
    this.wobble = false,
  });

  final double size;

  /// Demo `.wob`：0/100% -3°，50% 3°
  final bool wobble;

  @override
  State<TuanTuanPanda> createState() => _TuanTuanPandaState();
}

class _TuanTuanPandaState extends State<TuanTuanPanda>
    with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void initState() {
    super.initState();
    if (widget.wobble) {
      _c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = const Image(
      image: AssetImage('assets/mascot/tuantuan.png'),
      fit: BoxFit.contain,
    );
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: widget.wobble
          ? AnimatedBuilder(
              animation: _c!,
              builder: (context, _) {
                final t = _c!.value;
                // 0%,100% → -3deg；50% → 3deg
                final angle = -3 + 6 * (1 - (2 * t - 1).abs() / 1);
                return Transform.rotate(
                  angle: angle * pi / 180,
                  child: image,
                );
              },
            )
          : image,
    );
  }
}
