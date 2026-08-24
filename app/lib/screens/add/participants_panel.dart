import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/group_member.dart';
import '../../widgets/avatar.dart';

/// 选择参与人面板（P32）—— 多选 + [全选/反选/仅我]，返回选中 userId 集合
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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('选择参与人', style: text.headlineSmall),
        const SizedBox(height: 4),
        Text('已选 ${_selected.length} / ${widget.members.length} 人',
            style: text.bodySmall),
        const SizedBox(height: 8),
        Row(
          children: [
            _quick('全选', () => setState(() => _selected.addAll(widget.members.map((m) => m.userId)))),
            const SizedBox(width: 8),
            _quick('反选', () => setState(() {
                  final reversed = widget.members
                      .map((m) => m.userId)
                      .where((id) => !_selected.contains(id))
                      .toSet();
                  _selected
                    ..clear()
                    ..addAll(reversed);
                })),
            const SizedBox(width: 8),
            _quick('仅我', () => setState(() => _selected..clear()..add(widget.myId))),
          ],
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: ListView(
            shrinkWrap: true,
            children: widget.members.map((m) {
              final on = _selected.contains(m.userId);
              return GestureDetector(
                onTap: () => setState(() {
                  if (on) {
                    _selected.remove(m.userId);
                  } else {
                    _selected.add(m.userId);
                  }
                }),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: Row(
                    children: [
                      SketchAvatar(emoji: m.avatarUrl, size: 40, name: m.nickname),
                      const SizedBox(width: 10),
                      Expanded(child: Text(m.nickname, style: text.titleMedium)),
                      Icon(
                        on ? Icons.check_circle : Icons.circle_outlined,
                        color: on ? AAColors.mint : AAColors.inkSoft,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        ProgressPencil(progress: _selected.length / (widget.members.isEmpty ? 1 : widget.members.length)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DoodleButton(
                label: '确定',
                expand: true,
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
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _quick(String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AAColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AAColors.ink, width: 1.5),
          ),
          child: Text(label,
              style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 13, color: AAColors.ink)),
        ),
      ),
    );
  }
}
