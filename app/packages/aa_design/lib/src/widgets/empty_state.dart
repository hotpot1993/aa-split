import 'package:flutter/material.dart';
import '../mascot/tuan_tuan.dart';
import '../tokens/aa_colors.dart';
import '../tokens/aa_tokens.dart';
import 'doodle_button.dart';
import 'paper_card.dart';

import '../theme/aa_fonts.dart';
/// 空状态卡片 —— 严格照搬 Demo `.emptyc`：
/// `background:#FFFDF6;border-radius:16px 6px 14px 7px/7px 14px 6px 16px;
///  padding:18px 14px 14px;box-shadow:3px 3px 0 rgba(68,58,50,.15);
///  margin:12px 0;text-align:center`
/// 内含：`.tag`（左上角标签）、`.art`（38px 插画）、`h4`（16px）、`p`（12px 淡墨）、按钮
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.buttonLabel,
    this.buttonImage,
    this.onButtonTap,
    this.emotion = TuanTuanEmotion.sleepy,
    this.mascotSize = 130,
    this.compact = false,
    this.tag,
    this.art = '🎒🪙',
    this.artImage,
  });

  final String title;
  final String? subtitle;
  final String? buttonLabel;

  /// 按钮 label 前的素材图标（替代文字 emoji，如「✏️ 记一笔」）
  final String? buttonImage;
  final VoidCallback? onButtonTap;
  final TuanTuanEmotion emotion;
  final double mascotSize;

  /// 紧凑模式（用于卡片内），否则撑起 ≥60% 屏高
  final bool compact;

  /// 左上角标签（.emptyc .tag）
  final String? tag;

  /// 插画 emoji（.emptyc .art）
  final String art;

  /// 插画素材图片（优先于 art emoji）
  final String? artImage;

  @override
  Widget build(BuildContext context) {
    Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (artImage != null)
          Image.asset(artImage!, width: 38, height: 38, fit: BoxFit.contain)
        else
          Text(art, style: TextStyle(fontSize: 38)),
        SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AAFonts.title,
            fontSize: 16,
            color: AAColors.ink,
            height: 1.4,
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AAFonts.title,
              fontSize: 12,
              color: AAColors.inkSoft,
              height: 1.4,
            ),
          ),
        ],
        if (buttonLabel != null) ...[
          SizedBox(height: 10),
          DoodleButton(
            label: buttonLabel!,
            leadingImage: buttonImage,
            onPressed: onButtonTap,
            mini: true,
          ),
        ],
      ],
    );

    Widget card = PaperCard(
      color: AAColors.cardWhite,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
      shadow: AATokens.emptyShadow,
      borderWidth: AATokens.stroke,
      child: body,
    );

    if (tag != null) {
      card = Stack(
        clipBehavior: Clip.none,
        children: [
          card,
          Positioned(
            top: -11,
            left: 10,
            child: Transform.rotate(
              angle: -3 * 3.14159265 / 180,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AAColors.paper,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AAColors.ink, width: 2),
                ),
                child: Text(
                  tag!,
                  style: TextStyle(
                    fontFamily: AAFonts.title,
                    fontSize: 11,
                    color: AAColors.ink,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (compact) return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: card);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: card);
  }
}

/// 手绘加载态：团团 + 淡墨小字（替代系统转圈）
class AaLoading extends StatelessWidget {
  const AaLoading({super.key, this.label = '团团翻账中…', this.mascotSize = 72});

  final String label;
  final double mascotSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TuanTuanPanda(size: mascotSize),
        SizedBox(height: 10),
        Text(label,
            style: TextStyle(
                fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
      ],
    );
  }
}

/// 网络/服务器错误态（§9.3）
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
      subtitle: '团团头顶的WiFi都断了，它也急',
      tag: '全局 · 网络/服务器',
      artImage: 'assets/icons/signal.png',
      buttonLabel: '🔄 重试',
      onButtonTap: onRetry,
    );
  }
}
