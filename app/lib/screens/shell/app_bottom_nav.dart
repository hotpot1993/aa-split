import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

/// 自定义底部导航（UI规范 §7.5）：
/// 白纸底 + 顶部墨线；选中项 = 珊瑚橙涂鸦圆包围 + 图标上扬；
/// 中央 ➕ 为放大版铅笔涂鸦按钮，凸起于栏上，不选中任何 Tab。
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

  static const _tabs = [
    (icon: Icons.home, iconOut: Icons.home_outlined, label: '总览'),
    (icon: Icons.group, iconOut: Icons.group_outlined, label: '群组'),
    (icon: Icons.notifications, iconOut: Icons.notifications_none, label: '消息'),
    (icon: Icons.person, iconOut: Icons.person_outline, label: '我的'),
  ];

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: const Border(top: BorderSide(color: AAColors.ink, width: 2)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              _TabItem(
                icon: _tabs[0].icon,
                iconOut: _tabs[0].iconOut,
                label: _tabs[0].label,
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _TabItem(
                icon: _tabs[1].icon,
                iconOut: _tabs[1].iconOut,
                label: _tabs[1].label,
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _AddButton(onTap: onAdd),
              _TabItem(
                icon: _tabs[2].icon,
                iconOut: _tabs[2].iconOut,
                label: _tabs[2].label,
                selected: currentIndex == 2,
                onTap: () => onTap(2),
                badge: unreadCount,
              ),
              _TabItem(
                icon: _tabs[3].icon,
                iconOut: _tabs[3].iconOut,
                label: _tabs[3].label,
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
            Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: AAColors.coral,
                  shape: SketchyBorder(
                    side: const BorderSide(color: AAColors.ink, width: AATokens.stroke),
                    seed: 47,
                    bow: 5,
                  ),
                  shadows: const [
                    BoxShadow(color: AAColors.ink, offset: AATokens.shadowOffset),
                  ],
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.iconOut,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final IconData iconOut;
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
          duration: const Duration(milliseconds: 200),
          curve: springCurve,
          transform: Matrix4.translationValues(0, selected ? -4 : 0, 0),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 40,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? AAColors.coral : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      selected ? icon : iconOut,
                      color: color,
                      size: 24,
                    ),
                  ),
                  if (badge > 0)
                    Positioned(
                      right: 2,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        decoration: const BoxDecoration(
                          color: AAColors.berry,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            badge > 99 ? '99+' : '$badge',
                            style: const TextStyle(fontSize: 9, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'ZCOOLKuaiLe',
                  fontSize: 11,
                  color: selected ? AAColors.coral : AAColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
