import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';

/// 手绘拨动开关（滑轨 + 圆豆旋钮，UI规范 §7.5）
class HandToggle extends StatelessWidget {
  const HandToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = AAColors.mint,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 52,
        height: 28,
        decoration: BoxDecoration(
          color: value ? activeColor.withValues(alpha: 0.45) : AAColors.paperDeep,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AAColors.ink, width: 2),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: AAColors.cardWhite,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: value ? activeColor : AAColors.inkSoft,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 分块进度条（"笔芯长度" —— P32 已选人数进度）
class ProgressPencil extends StatelessWidget {
  const ProgressPencil({
    super.key,
    required this.progress,
    this.color = AAColors.coral,
  });

  /// 0-1
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            ColoredBox(color: AAColors.paperDeep),
            FractionallySizedBox(
              widthFactor: progress.clamp(0, 1),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
