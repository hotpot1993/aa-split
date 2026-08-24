import 'package:flutter/material.dart';
import '../mascot/tuan_tuan.dart';
import '../tokens/aa_colors.dart';
import '../tokens/aa_tokens.dart';
import 'doodle_button.dart';
import 'paper_card.dart';

/// 空状态（UI规范 §9）：团团插画 + 手写大字文案 + 可选主按钮
/// 空态文案禁止"无数据/加载失败"系统语言，允许"～"，感叹号每屏 ≤ 1
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.buttonLabel,
    this.onButtonTap,
    this.emotion = TuanTuanEmotion.sleepy,
    this.mascotSize = 130,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final String? buttonLabel;
  final VoidCallback? onButtonTap;
  final TuanTuanEmotion emotion;
  final double mascotSize;

  /// 紧凑模式（用于卡片内），否则撑起 ≥60% 屏高
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TuanTuan(emotion: emotion, size: mascotSize, withPencil: true),
        SizedBox(height: compact ? 12 : AATokens.space6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: text.headlineSmall,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
        ],
        if (buttonLabel != null) ...[
          const SizedBox(height: AATokens.space5),
          DoodleButton(label: buttonLabel!, onPressed: onButtonTap),
        ],
      ],
    );

    final card = PaperCard(
      color: AAColors.cardWhite.withValues(alpha: 0.75),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: body,
    );

    if (compact) return Center(child: card);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: FractionallySizedBox(
          heightFactor: 0.6,
          widthFactor: 1,
          child: Center(child: card),
        ),
      ),
    );
  }
}

/// 网络/服务器错误态（§9.3）：团团摔四脚朝天 + 重试
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    this.title = '网络开小差了…检查一下再试试',
    this.onRetry,
  });

  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: title,
      emotion: TuanTuanEmotion.excited,
      buttonLabel: '重试',
      onButtonTap: onRetry,
    );
  }
}
