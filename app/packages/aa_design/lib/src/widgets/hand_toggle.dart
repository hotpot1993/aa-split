import 'package:flutter/material.dart';
import '../tokens/aa_colors.dart';
import '../tokens/aa_tokens.dart';

/// 手绘拨动开关 —— 严格照搬 Demo `.swt`：
/// `width:46px;height:26px;border:2.5px solid var(--ink);border-radius:999px;background:#fff`
/// 旋钮 `.swt:after`：`top:1.5px;left:3px;width:17px;height:17px;border-radius:50%;
/// background:var(--ink2);border:2px solid var(--ink)`
/// 开启 `.swt.on`：`background:#EDF7EE`，旋钮 `left:22px;background:var(--mint)`
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
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 46,
        height: 26,
        decoration: BoxDecoration(
          color: value ? const Color(0xFFEDF7EE) : AAColors.cardWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AAColors.ink, width: 2.5),
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              top: 1.5,
              left: value ? 22 : 3,
              child: Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: value ? AASemantic.amountPos : AAColors.inkSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: AAColors.ink, width: 2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 手绘单选框/复选框 —— 严格照搬 Demo `.cbx`：
/// `width:22px;height:22px;border:2.5px solid var(--ink);
///  border-radius:7px 3px 8px 3px;background:#fff`
/// 选中 `.cbx.on:after`：`✓` 15px 珊瑚橙、-6° 旋转
class AaCheckbox extends StatelessWidget {
  const AaCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.size = 22,
  });

  final bool value;
  final VoidCallback? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AAColors.cardWhite,
          border: Border.all(color: AAColors.ink, width: AATokens.stroke),
          borderRadius: AARadii.cbx,
        ),
        child: value
            ? Transform.rotate(
                angle: -6 * 3.14159265 / 180,
                child: Text(
                  '✓',
                  style: TextStyle(
                    fontSize: size * 0.68,
                    height: 1,
                    color: AAColors.coral,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// 分块进度条（P32 已选人数进度）
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
