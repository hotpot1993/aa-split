import 'dart:io' show File;

import 'package:flutter/material.dart';

import '../core/config.dart';
import '../core/utils/avatar_ref.dart';
import '../core/utils/format.dart';
import '../models/bill.dart';
import 'package:aa_design/aa_design.dart';

/// 涂鸦头像 —— 严格照搬 Demo `.ava`：
/// `width:44px;height:44px;border:2.5px solid var(--ink);border-radius:50%;
///  font-size:22px;background:#fff`
/// 成员行按 Demo 使用淡彩底（#FFF1EA / #EDF7EE / #F0F6FB / #F7F0FB 等）。
///
/// [emoji] 为 emoji 时渲染涂鸦文字；为本地文件路径（用户自换头像）
/// 或 http(s) URL 时渲染圆形图片。
class SketchAvatar extends StatelessWidget {
  const SketchAvatar({
    super.key,
    required this.emoji,
    this.size = 44,
    this.name = '',
    this.background = AAColors.cardWhite,
    this.dimmed = false,
  });

  final String emoji;
  final double size;
  final String name;

  /// 头像底色（默认白；成员行传淡彩）
  final Color background;

  /// 未选中参与者：`opacity:.5`（Demo P32 王五）
  final bool dimmed;

  /// 网络图 URL（http(s) 或 /uploads 相对路径 → 拼接当前 API origin）
  String get _displayUrl {
    if (emoji.startsWith('http://') || emoji.startsWith('https://')) return emoji;
    if (emoji.startsWith('/uploads/')) {
      final origin = AppConfig.baseUrl.replaceFirst(RegExp(r'/api/v1$'), '');
      return '$origin$emoji';
    }
    return '';
  }

  bool get _isNetwork => _displayUrl.isNotEmpty;

  bool get _isLocalFile {
    if (emoji.isEmpty || _isNetwork) return false;
    // 本地路径：Android /data/...、/storage/...、Windows C:\...、file://...
    if (!isLocalAvatarRef(emoji)) return false;
    return File(emoji).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_isLocalFile) {
      child = ClipOval(
        child: Image.file(
          File(emoji),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    } else if (_isNetwork) {
      child = ClipOval(
        child: Image.network(
          _displayUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(),
        ),
      );
    } else {
      child = _fallback();
    }
    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(color: AAColors.ink, width: 2.5),
        ),
        child: child,
      ),
    );
  }

  Widget _fallback() {
    // 失效的图片路径/URL 不回显原文，回退昵称首字或默认🐼
    final isImageRef = emoji.startsWith('http') ||
        emoji.startsWith('/uploads/') ||
        isLocalAvatarRef(emoji);
    final text = !isImageRef && emoji.trim().isNotEmpty
        ? emoji
        : (name.isEmpty
            ? (isImageRef ? '🐼' : '?')
            : name.substring(0, 1));
    return Text(
      text,
      style: TextStyle(fontSize: size * 0.5, color: AAColors.ink),
    );
  }
}

/// 分类小圆图标（流水行用）—— Demo 账单行的 `.ava`（白底墨线圆 + emoji）
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.category, this.size = 40});

  final BillCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AAColors.cardWhite,
        shape: BoxShape.circle,
        border: Border.all(color: AAColors.ink, width: 2.5),
      ),
      child: Text(
        Cat.emoji(category),
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }
}
