import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

import '../core/config.dart';

/// 相对路径（/uploads/xxx）→ 完整 URL；Demo 占位 emoji 原样返回。
/// 凭证 URL 存相对路径以兼容域名变更；展示时拼接当前 API origin。
String absReceiptUrl(String url) {
  if (url.isEmpty || url.startsWith('http') || url.startsWith('🧾')) return url;
  final origin = AppConfig.baseUrl.replaceFirst(RegExp(r'/api/v1$'), '');
  return '$origin$url';
}

/// 页面骨架：速写纸背景 + 可选顶部涂鸦导航栏
class AaScaffold extends StatelessWidget {
  const AaScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomBar,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomBar;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 纸米底（Demo body 背景 var(--paper)），避免透出系统窗口背景（深色模式下为黑色）
      backgroundColor: AAColors.paper,
      appBar: appBar,
      // 无顶部导航栏时（如首页），body 内容需避开状态栏
      body: SketchPaper(
        child: SafeArea(top: appBar == null, bottom: false, child: body),
      ),
      bottomNavigationBar: bottomBar,
    );
  }
}

/// 自有图标素材（docs/pic → assets/icons，透明底 512px）
class AaIconImage extends StatelessWidget {
  const AaIconImage(this.asset, {super.key, this.size = 22});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      cacheWidth: (size * 4).round(),
      fit: BoxFit.contain,
    );
  }
}

/// 顶部涂鸦导航 —— 严格照搬 Demo `.nav`：
/// `<span class="back">‹ 返回</span><h2>标题</h2><span class="ic">✂️</span>`
/// back 18px / 标题 22px（站酷快乐体）/ 右侧图标 17px，下方间距 10px
class AaAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AaAppBar({
    super.key,
    required this.title,
    this.back = true,
    this.backLabel = '‹ 返回',
    this.onBack,
    this.icon,
    this.iconImage,
    this.onIconTap,
    this.headIcon,
    this.actions = const [],
  });

  final String title;

  /// 是否显示返回键（‹ 返回）
  final bool back;
  final String backLabel;
  final VoidCallback? onBack;

  /// 右侧图标（emoji 字符串 / 任意 widget）
  final String? icon;

  /// 右侧图标（自有素材图片路径）
  final String? iconImage;
  final VoidCallback? onIconTap;

  /// 标题前的图标素材（自有图片）
  final String? headIcon;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context) {
    // 自定义导航栏需自行处理状态栏内边距（Scaffold 只把 appBar 放在 y=0）
    // 左右 16px 留白：与页面内容边距、Demo .screen padding 一致，标题不贴屏幕边
    return SafeArea(
      bottom: false,
      child: Container(
        height: 46,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        alignment: Alignment.bottomCenter,
        child: Row(
          children: [
            if (back) ...[
              InkWell(
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, top: 8),
                  child: Text(
                    backLabel,
                    style: TextStyle(
                      fontFamily: AAFonts.title,
                      fontSize: 18,
                      color: AAColors.ink,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
            if (headIcon != null) ...[
              Padding(
                padding: const EdgeInsets.only(right: 6, top: 8),
                child: AaIconImage(headIcon!, size: 20),
              ),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AAFonts.title,
                  fontSize: 22,
                  color: AAColors.ink,
                  height: 1.2,
                ),
              ),
            ),
            ...actions,
            if (iconImage != null) ...[
              InkWell(
                onTap: onIconTap,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, top: 8),
                  child: AaIconImage(iconImage!, size: 22),
                ),
              ),
              SizedBox(width: 2),
            ],
            if (icon != null) ...[
              InkWell(
                onTap: onIconTap,
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, top: 8),
                  child: Text(icon!, style: TextStyle(fontSize: 17)),
                ),
              ),
              SizedBox(width: 2),
            ],
          ],
        ),
      ),
    );
  }
}

/// 小节标题 —— 严格照搬 Demo `.sect`：
/// `[虚线][span 14px 墨色][emoji]`，虚线为 repeating-linear-gradient
/// (90deg, ink2 0 6px, transparent 6px 12px) 高 2px
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.emoji, this.emojiImage});

  final String text;
  final Widget? trailing;

  /// 文字右侧的 emoji（.sect em）
  final String? emoji;

  /// 文字右侧的素材图片（替代 emoji）
  final String? emojiImage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(
        children: [
          Expanded(child: _DashLine()),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontFamily: AAFonts.title,
              fontSize: 14,
              color: AAColors.ink,
              height: 1.3,
            ),
          ),
          if (emojiImage != null) ...[
            SizedBox(width: 6),
            AaIconImage(emojiImage!, size: 16),
          ],
          if (emoji != null) ...[
            SizedBox(width: 6),
            Text(emoji!, style: TextStyle(fontSize: 13)),
          ],
          ?trailing,
        ],
      ),
    );
  }
}

class _DashLine extends StatelessWidget {
  const _DashLine();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, 2),
      painter: _DashLinePainter(),
    );
  }
}

class _DashLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AAColors.inkSoft
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.butt;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1), Offset(x + 6, 1), p);
      x += 12;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 表单行 —— 严格照搬 Demo `.line`：
/// `display:flex;justify-content:space-between;align-items:center;
///  border-bottom:2.5px dashed var(--ink);padding:11px 2px;font-size:15px`
class AaLine extends StatelessWidget {
  const AaLine({
    super.key,
    this.label,
    this.value,
    this.child,
    this.trailing,
    this.showBorder = true,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(2, 11, 2, 11),
  });

  /// 左侧标签（.line span，淡墨）
  final String? label;

  /// 右侧值（.line b，墨色 15px）
  final String? value;

  /// 整体内容（label + value 省略时）
  final Widget? child;

  /// 右侧自定义内容（替代 value）
  final Widget? trailing;

  /// 是否显示底部虚线（最后一行不带）
  final bool showBorder;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    Widget row = Padding(
      padding: padding,
      child: child ??
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (label != null)
                Text(
                  label!,
                  style: TextStyle(
                    fontFamily: AAFonts.title,
                    fontSize: 15,
                    color: AAColors.inkSoft,
                    height: 1.3,
                  ),
                ),
              if (value != null) Text(value!, style: _valueStyle),
              ?trailing,
            ],
          ),
    );
    row = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        if (showBorder)
          CustomPaint(size: Size(double.infinity, 2.5), painter: _DashLinePainter()),
      ],
    );
    if (onTap != null) {
      row = GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: row);
    }
    return row;
  }

  static final TextStyle _valueStyle = TextStyle(
    fontFamily: AAFonts.title,
    fontSize: 15,
    color: AAColors.ink,
    height: 1.3,
  );
}

/// 内容加载/占位后的统一包裹：添加统一外边距
class AaBody extends StatelessWidget {
  const AaBody({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: child,
    );
  }
}
