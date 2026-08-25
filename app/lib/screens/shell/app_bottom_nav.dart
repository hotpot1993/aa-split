import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

/// 底部导航 —— 严格照搬 Demo `.tabbar`：
/// `height:78px;background:#FFFDF6;border-top:3px solid var(--ink)`
/// `.tab`：`font-size:11px;color:var(--ink2)`，图标 25x25 手绘线条（stroke 2.4）；
/// 选中 `.tab.cur`：珊瑚橙 + `bounce .28s`（0→-5→0）；
/// 中央 `.tab.plus`：34px 珊瑚橙圆 + 2.5px 墨线 + 白色铅笔 + 3px 实心墨影，上浮 20px。
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
    this.unreadCount = 0,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;
  final int unreadCount;

  static const _labels = ['总览', '群组', '', '消息', '我的'];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AAColors.cardWhite,
        border: Border(top: BorderSide(color: AAColors.ink, width: 3)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 78,
          child: Row(
            children: [
              _TabItem(
                icon: _HomeIcon(),
                label: _labels[0],
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _TabItem(
                icon: _GroupIcon(),
                label: _labels[1],
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _AddButton(onTap: onAdd),
              _TabItem(
                icon: _BellIcon(),
                label: _labels[3],
                selected: currentIndex == 2,
                onTap: () => onTap(2),
                badge: unreadCount,
              ),
              _TabItem(
                icon: _PersonIcon(),
                label: _labels[4],
                selected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 中央 ➕（记一笔）：68px 珊瑚橙圆（34px 的两倍）+ 2.5px 墨线 + 白色铅笔，
/// 垂直居中放置于导航栏内（不再上浮出栏），提升视觉平衡与点击区域。
class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 68,
              height: 68,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(8),
              decoration: ShapeDecoration(
                color: AAColors.coral,
                shape: CircleBorder(
                  side: BorderSide(color: AAColors.ink, width: 2.5),
                ),
                shadows: [AATokens.buttonShadow],
              ),
              child: CustomPaint(
                size: Size(52, 52),
                painter: _PencilIconPainter(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final Widget icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AAColors.coral : AAColors.inkSoft;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 280),
          curve: springCurve,
          transform: Matrix4.translationValues(0, selected ? -5 : 0, 0),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconTheme(
                    data: IconThemeData(color: color),
                    child: SizedBox(width: 25, height: 25, child: icon),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -5,
                      top: -3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: BoxDecoration(
                          color: AAColors.berry,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            badge > 99 ? '99+' : '$badge',
                            style: TextStyle(fontSize: 9, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AAFonts.title,
                  fontSize: 11,
                  color: color,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 手绘 Tab 图标基类（Demo `<svg viewBox="0 0 24 24">` 线条，stroke 2.4）
abstract class _SketchIconPainter extends CustomPainter {
  const _SketchIconPainter();

  Paint get _paint => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.4
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  /// 在 24x24 坐标系内构建路径
  Path get canvasPath;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final s = size.width / 24;
    canvas.scale(s);
    canvas.drawPath(canvasPath, _paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeIcon extends StatelessWidget {
  const _HomeIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _HomeIconPainter(), size: Size(25, 25));
  }
}

class _HomeIconPainter extends _SketchIconPainter {
  @override
  Path get canvasPath => Path()
    ..moveTo(4.6, 11.8)
    ..quadraticBezierTo(8.5, 8, 12, 4.9)
    ..quadraticBezierTo(15.6, 8, 19.4, 11.6)
    ..moveTo(7, 10.6)
    ..lineTo(7, 18)
    ..lineTo(17, 18)
    ..lineTo(17, 10.6)
    ..moveTo(10.2, 18)
    ..lineTo(10.2, 13.6)
    ..lineTo(13.8, 13.6)
    ..lineTo(13.8, 18);
}

class _GroupIcon extends StatelessWidget {
  const _GroupIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _GroupIconPainter(), size: Size(25, 25));
  }
}

class _GroupIconPainter extends _SketchIconPainter {
  @override
  Path get canvasPath => Path()
    ..addOval(Rect.fromCircle(center: Offset(8.8, 7), radius: 2.5))
    ..addOval(Rect.fromCircle(center: Offset(15.8, 8.4), radius: 2.1))
    ..moveTo(4.8, 14.6)
    ..quadraticBezierTo(8.8, 10.6, 12.8, 14.6)
    ..moveTo(12.6, 14.2)
    ..quadraticBezierTo(15.4, 11.4, 18.4, 14.2);
}

class _BellIcon extends StatelessWidget {
  const _BellIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BellIconPainter(), size: Size(25, 25));
  }
}

class _BellIconPainter extends _SketchIconPainter {
  @override
  Path get canvasPath => Path()
    ..moveTo(12, 4.4)
    ..quadraticBezierTo(15.8, 6.2, 15.8, 11.4)
    ..lineTo(15.8, 14)
    ..lineTo(18, 16.4)
    ..lineTo(6, 16.4)
    ..lineTo(8.2, 14)
    ..lineTo(8.2, 11.4)
    ..quadraticBezierTo(8.2, 6.2, 12, 4.4)
    ..close()
    ..moveTo(12, 4.4)
    ..lineTo(12, 3.2)
    ..addOval(Rect.fromCircle(center: Offset(12, 18.4), radius: 1.3));
}

class _PersonIcon extends StatelessWidget {
  const _PersonIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _PersonIconPainter(), size: Size(25, 25));
  }
}

class _PersonIconPainter extends _SketchIconPainter {
  @override
  Path get canvasPath => Path()
    ..addOval(Rect.fromCircle(center: Offset(12, 7.4), radius: 3.1))
    ..moveTo(5.8, 18.2)
    ..quadraticBezierTo(6.2, 12.4, 12, 12.4)
    ..quadraticBezierTo(17.8, 12.4, 18.2, 18.2);
}

/// 中央铅笔（.tab.plus svg：`M5 19 L5 15.4 L15.4 5 L19 8.6 L8.6 19 Z M13.2 7.2 L16.8 10.8`）
///
/// Demo 路径只占 viewBox 24 的 5..19 区域（约 58%），直接缩放会显得
/// 偏小且视觉不平衡；这里把该区域归一化放大到 1.2..22.8，保证铅笔在
/// 珊瑚橙圆内居中且与其余 25px 图标尺寸统一（stroke 2.2 同步略增）。
class _PencilIconPainter extends CustomPainter {
  const _PencilIconPainter();

  // 将 Demo 路径坐标 5..19 映射到 1.2..22.8（21.6/14 = 1.542857 倍）
  static double _x(double v) => (v - 5) * 1.542857 + 1.2;
  static double _y(double v) => (v - 5) * 1.542857 + 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.save();
    canvas.scale(s);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(_x(5), _y(19))
        ..lineTo(_x(5), _y(15.4))
        ..lineTo(_x(15.4), _y(5))
        ..lineTo(_x(19), _y(8.6))
        ..lineTo(_x(8.6), _y(19))
        ..close()
        ..moveTo(_x(13.2), _y(7.2))
        ..lineTo(_x(16.8), _y(10.8)),
      p,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
