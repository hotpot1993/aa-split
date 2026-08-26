import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/group.dart';
import '../../models/group_member.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P27 群组设置 —— 对齐 docs/ui-demo/index.html
/// 仅群主可进入（普通成员从详情页无入口；此处守卫深链直达）。
class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _intro;
  Set<String> _exemptIds = {};
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final groups = ref.read(groupsProvider).value ?? const <Group>[];
    Group? group;
    for (final g in groups) {
      if (g.id == widget.groupId) {
        group = g;
        break;
      }
    }
    _name = TextEditingController(text: group?.name ?? '');
    _intro = TextEditingController(text: group?.intro ?? '');
    _exemptIds = {...?group?.defaultExemptUserIds};
  }

  @override
  void dispose() {
    _name.dispose();
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    Group? group;
    for (final g in groups) {
      if (g.id == widget.groupId) {
        group = g;
        break;
      }
    }
    if (group == null) {
      return AaScaffold(appBar: null, body: Center(child: EmptyState(title: '群组不存在')));
    }
    final g = group;
    final me = ref.watch(currentUserProvider)?.id ?? 'me';
    final isOwner = g.ownerId == me;

    // 普通成员无打开群组设置页权限（守卫：仅群主可进入）
    if (!isOwner) {
      return AaScaffold(
        appBar: AaAppBar(title: '群组设置'),
        body: const Center(
          child: EmptyState(
            title: '只有群主才能进入群组设置哦',
            subtitle: '群信息、免分摊人员等由群主统一维护',
          ),
        ),
      );
    }

    final members =
        (ref.watch(groupMembersProvider).value ?? {})[widget.groupId] ?? [];
    final exemptNames = members
        .where((m) => _exemptIds.contains(m.userId))
        .map((m) => m.nickname)
        .toList();

    return AaScaffold(
      appBar: AaAppBar(
        title: '群组设置',
        iconImage: 'assets/icons/settings.png',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                // 名称/简介弹层入口（Demo .line：✏️ 头像/名称/简介）
                GestureDetector(
                  onTap: () => showAaSheet(
                    context,
                    child: _InfoSheet(
                      name: _name,
                      intro: _intro,
                      onSave: () {
                        _save();
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                  child: AaLine(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('群组信息',
                            style: TextStyle(
                                fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
                        Flexible(
                          child: Text('✏️ ${_name.text} / ${_intro.text.isEmpty ? '未写简介' : _intro.text}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                        ),
                      ],
                    ),
                  ),
                ),
                // 默认免分摊人员：点击弹出成员多选清单（可正常操作/交互）
                GestureDetector(
                  onTap: _pickExempt,
                  behavior: HitTestBehavior.opaque,
                  child: AaLine(
                    showBorder: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('免分摊人员默认',
                            style: TextStyle(
                                fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
                        Flexible(
                          child: Text(
                            exemptNames.isEmpty ? '无 ▾' : '${exemptNames.join('、')} ▾',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          DoodleButton(
            label: '保存设置',
            big: true,
            onPressed: _save,
          ),
          SizedBox(height: 10),
          if (isOwner)
            DoodleButton(
              label: '解散群组',
              leadingImage: 'assets/icons/flame.png',
              type: DoodleButtonType.danger,
              big: true,
              onPressed: () => _disband(g),
            ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 免分摊人员默认：弹出成员多选清单，选择后保存到群组设置
  Future<void> _pickExempt() async {
    final members =
        (ref.read(groupMembersProvider).value ?? {})[widget.groupId] ?? [];
    if (members.isEmpty) {
      showAaToast(context, '群内还没有成员');
      return;
    }
    final picked = await showAaSheet<Set<String>>(
      context,
      child: _ExemptMembersSheet(
        members: members,
        initialSelected: {..._exemptIds},
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _exemptIds = picked);
    await ref.read(groupRepositoryProvider).update(
          widget.groupId,
          defaultExemptUserIds: picked.toList(),
        );
    ref.read(refreshProvider.notifier).bump();
    if (mounted) {
      showAaToast(context,
          picked.isEmpty ? '已清除默认免分摊人员' : '已保存默认免分摊人员（${picked.length}人）');
    }
  }

  void _save() {
    ref.read(groupRepositoryProvider).update(
          widget.groupId,
          name: _name.text.trim().isEmpty ? null : _name.text.trim(),
          intro: _intro.text.trim(),
        );
    ref.read(refreshProvider.notifier).bump();
    showAaToast(context, '💾 已保存设置');
  }

  Future<void> _disband(Group group) async {
    final ok = await showAaConfirm(
      context,
      title: '要解散「${group.name}」吗？',
      subtitle: '解散后成员看不到这个群了，操作不可恢复',
      confirmLabel: '解散',
    );
    if (ok != true || !mounted) return;
    try {
      // 先等服务端解散完成，再刷新列表（避免列表先于删除请求返回导致残留）
      await ref.read(groupRepositoryProvider).disband(widget.groupId);
      ref.read(refreshProvider.notifier).bump();
      if (!mounted) return;
      showAaToast(context, '群组已解散');
      context.go('/groups');
    } catch (e) {
      if (mounted) showAaToast(context, '解散失败：$e');
    }
  }
}

/// 群组信息弹层（名称 + 简介 + 保存）
class _InfoSheet extends StatelessWidget {
  const _InfoSheet({required this.name, required this.intro, required this.onSave});
  final TextEditingController name;
  final TextEditingController intro;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('✏️ 头像/名称/简介',
            style: TextStyle(fontFamily: AAFonts.title, fontSize: 18, color: AAColors.ink)),
        SizedBox(height: 12),
        Text('名称', style: TextStyle(fontFamily: AAFonts.title, fontSize: 14, color: AAColors.inkSoft)),
        HandTextField(controller: name),
        SizedBox(height: 12),
        Text('简介', style: TextStyle(fontFamily: AAFonts.title, fontSize: 14, color: AAColors.inkSoft)),
        HandTextField(controller: intro, maxLines: 2),
        SizedBox(height: 16),
        DoodleButton(label: '保存', expand: true, onPressed: onSave),
        SizedBox(height: 8),
      ],
    );
  }
}

/// 默认免分摊人员多选（Demo .line 行 + .cbx 勾选）：
/// 选中的人默认不参与群内新账单分摊（请客者/司机等），保存后写入群组设置。
class _ExemptMembersSheet extends StatefulWidget {
  const _ExemptMembersSheet({required this.members, required this.initialSelected});
  final List<GroupMember> members;
  final Set<String> initialSelected;

  @override
  State<_ExemptMembersSheet> createState() => _ExemptMembersSheetState();
}

class _ExemptMembersSheetState extends State<_ExemptMembersSheet> {
  late final Set<String> _selected = {...widget.initialSelected};

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('👥 默认免分摊人员',
            style: TextStyle(fontFamily: AAFonts.title, fontSize: 18, color: AAColors.ink)),
        SizedBox(height: 4),
        Text('这些人默认不参与群内账单分摊',
            style: TextStyle(fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
        SizedBox(height: 10),
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
        Text('已选 ${_selected.length} 人',
            style: TextStyle(fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
        SizedBox(height: 10),
        DoodleButton(
          label: '确定（${_selected.length}人免分摊）✓',
          big: true,
          onPressed: () => Navigator.of(context).pop(_selected),
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
                      background: const Color(0xFFF0F6FB),
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
          CustomPaint(size: Size(double.infinity, 2.5), painter: _ExemptDash()),
      ],
    );
  }
}

class _ExemptDash extends CustomPainter {
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
