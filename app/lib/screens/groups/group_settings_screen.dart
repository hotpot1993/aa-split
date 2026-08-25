import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/group.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P27 群组设置 —— 对齐 docs/ui-demo/index.html
class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _intro;
  GroupDefaultSplit _split = GroupDefaultSplit.even;
  bool _notifyAll = true;
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
    if (group != null) {
      _name = TextEditingController(text: group.name);
      _intro = TextEditingController(text: group.intro);
      _split = group.defaultSplit;
    } else {
      _name = TextEditingController();
      _intro = TextEditingController();
    }
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
      return const AaScaffold(appBar: null, body: Center(child: EmptyState(title: '群组不存在')));
    }
    final g = group;
    final me = ref.watch(currentUserProvider)?.id ?? 'me';
    final isOwner = g.ownerId == me;

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
                        const Text('群组信息',
                            style: TextStyle(
                                fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft)),
                        Text('✏️ ${_name.text} / ${_intro.text.isEmpty ? '未写简介' : _intro.text}',
                            style: const TextStyle(
                                fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
                      ],
                    ),
                  ),
                ),
                // 默认分摊方式（Demo：均摊 ▾）
                AaLine(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('默认分摊方式',
                          style: TextStyle(
                              fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft)),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<GroupDefaultSplit>(
                          value: _split,
                          icon: const Text('▾',
                              style: TextStyle(fontSize: 16, color: AAColors.inkSoft, height: 1)),
                          items: GroupDefaultSplit.values
                              .map((s) => DropdownMenuItem(
                                  value: s, child: Text(GroupSplit.label(s))))
                              .toList(),
                          onChanged: (v) => setState(() => _split = v ?? _split),
                        ),
                      ),
                    ],
                  ),
                ),
                // 新账单@全部成员（Demo .swt）
                AaLine(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('新账单@全部成员',
                          style: TextStyle(
                              fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft)),
                      HandToggle(
                        value: _notifyAll,
                        activeColor: AAColors.mint,
                        onChanged: (v) => setState(() => _notifyAll = v),
                      ),
                    ],
                  ),
                ),
                AaLine(
                  showBorder: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('免分摊人员默认',
                          style: TextStyle(
                              fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft)),
                      const Text('无 ▾',
                          style: TextStyle(
                              fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DoodleButton(
            label: '保存设置',
            big: true,
            onPressed: _save,
          ),
          const SizedBox(height: 10),
          if (isOwner)
            DoodleButton(
              label: '🔥 解散群组',
              type: DoodleButtonType.danger,
              big: true,
              onPressed: () => _disband(g),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
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
    if (ok == true) {
      if (!mounted) return;
      ref.read(groupRepositoryProvider).disband(widget.groupId);
      ref.read(refreshProvider.notifier).bump();
      showAaToast(context, '群组已解散');
      context.go('/groups');
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
        const Text('✏️ 头像/名称/简介',
            style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 18, color: AAColors.ink)),
        const SizedBox(height: 12),
        const Text('名称', style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 14, color: AAColors.inkSoft)),
        HandTextField(controller: name),
        const SizedBox(height: 12),
        const Text('简介', style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 14, color: AAColors.inkSoft)),
        HandTextField(controller: intro, maxLines: 2),
        const SizedBox(height: 16),
        DoodleButton(label: '保存', expand: true, onPressed: onSave),
        const SizedBox(height: 8),
      ],
    );
  }
}
