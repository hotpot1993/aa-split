import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/group_member.dart';
import '../../widgets/avatar.dart';

/// 选择参与人面板（P32）—— 对齐 docs/ui-demo/index.html：
/// `.chip` 快捷操作 + `.line` 名单行（`.cbx` 勾选）+ 底部说明 + 大按钮
class ParticipantsPanel extends StatefulWidget {
  const ParticipantsPanel({
    super.key,
    required this.members,
    required this.myId,
    this.initialSelected = const {},
    this.onApply,
  });

  final List<GroupMember> members;
  final String myId;
  final Set<String> initialSelected;
  final void Function(Set<String> selected)? onApply;

  @override
  State<ParticipantsPanel> createState() => _ParticipantsPanelState();
}

class _ParticipantsPanelState extends State<ParticipantsPanel> {
  late final Set<String> _selected = {...widget.initialSelected};

  static const _tints = [
    Color(0xFFFFF1EA),
    Color(0xFFEDF7EE),
    Color(0xFFF0F6FB),
    Color(0xFFF7F0FB),
    Color(0xFFF4E8D3),
  ];

  bool get _allSelected =>
      widget.members.isNotEmpty && _selected.length == widget.members.length;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('👥 选择参与人',
            style: TextStyle(fontFamily: AAFonts.title, fontSize: 18, color: AAColors.ink)),
        SizedBox(height: 10),
        Row(
          children: [
            _quick(
              '全选',
              () => setState(() => _selected.addAll(widget.members.map((m) => m.userId))),
              selected: _allSelected,
            ),
            SizedBox(width: 8),
            _quick('反选', () => setState(() {
              final reversed = widget.members
                  .map((m) => m.userId)
                  .where((id) => !_selected.contains(id))
                  .toSet();
              _selected
                ..clear()
                ..addAll(reversed);
            })),
            SizedBox(width: 8),
            _quick('仅我', () => setState(() => _selected..clear()..add(widget.myId))),
          ],
        ),
        SizedBox(height: 10),
        // 名单卡（Demo：.line 行 + .cbx）
        PaperCard(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Column(
            children: [
              for (var i = 0; i < widget.members.length; i++)
                _memberLine(i, widget.members[i]),
            ],
          ),
        ),
        SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Text('已选 ${_selected.length}人',
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
              SizedBox(width: 6),
              if (widget.members.length > _selected.length)
                Text('· 还有小伙伴不参与',
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
            ],
          ),
        ),
        SizedBox(height: 10),
        DoodleButton(
          label: '确定（${_selected.length}人参加）✓',
          big: true,
          onPressed: _selected.isNotEmpty
              ? () {
                  if (widget.onApply != null) {
                    widget.onApply!(_selected);
                  } else {
                    Navigator.of(context).pop(_selected);
                  }
                }
              : null,
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _memberLine(int index, GroupMember m) {
    final on = _selected.contains(m.userId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() {
            if (on) {
              _selected.remove(m.userId);
            } else {
              _selected.add(m.userId);
            }
          }),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SketchAvatar(
                      emoji: m.avatarUrl,
                      size: 34,
                      name: m.nickname,
                      background: _tints[index % _tints.length],
                      dimmed: !on,
                    ),
                    SizedBox(width: 10),
                    Text(
                      m.nickname,
                      style: TextStyle(
                        fontFamily: AAFonts.title,
                        fontSize: 15,
                        color: on ? AAColors.ink : AAColors.inkSoft,
                      ),
                    ),
                  ],
                ),
                AaCheckbox(
                  value: on,
                  size: 22,
                  onChanged: () => setState(() {
                    if (on) {
                      _selected.remove(m.userId);
                    } else {
                      _selected.add(m.userId);
                    }
                  }),
                ),
              ],
            ),
          ),
        ),
        if (index != widget.members.length - 1)
          CustomPaint(size: Size(double.infinity, 2.5), painter: _OptDash()),
      ],
    );
  }

  Widget _quick(String label, VoidCallback onTap, {bool selected = false}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: HandTag(label, selected: selected, fontSize: 12),
      ),
    );
  }
}

class _OptDash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AAColors.ink
      ..strokeWidth = 2.5;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1.25), Offset(x + 7, 1.25), p);
      x += 14;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
