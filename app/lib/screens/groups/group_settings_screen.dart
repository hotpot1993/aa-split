import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/group.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P27 群组设置页
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
    final text = Theme.of(context).textTheme;
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
      appBar: AppBar(title: const Text('群组设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionTitle('群组信息'),
          PaperCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('名称', style: text.bodyMedium),
                HandTextField(controller: _name),
                const SizedBox(height: 12),
                Text('简介', style: text.bodyMedium),
                HandTextField(controller: _intro, maxLines: 2),
                const SizedBox(height: 12),
                DoodleButton(
                  label: '保存修改',
                  type: DoodleButtonType.secondary,
                  expand: true,
                  onPressed: _save,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle('默认分摊方式'),
          Row(
            children: [
              _chip('均摊', GroupDefaultSplit.even),
              const SizedBox(width: 8),
              _chip('自定义', GroupDefaultSplit.custom),
              const SizedBox(width: 8),
              _chip('按比例', GroupDefaultSplit.ratio),
            ],
          ),
          const SizedBox(height: 24),
          if (isOwner) ...[
            Divider(height: 30),
            DoodleButton(
              label: '⚠ 解散群组',
              type: DoodleButtonType.secondary,
              color: AAColors.berry,
              textColor: AAColors.berry,
              expand: true,
              onPressed: () => _disband(g),
            ),
            const SizedBox(height: 10),
            DoodleButton(
              label: '删除我的所有数据',
              type: DoodleButtonType.secondary,
              color: AAColors.inkSoft,
              textColor: AAColors.inkSoft,
              expand: true,
              onPressed: () => _deleteAll(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, GroupDefaultSplit value) {
    final selected = _split == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _split = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AAColors.mint.withValues(alpha: 0.3) : AAColors.cardWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AAColors.mint : AAColors.ink, width: 1.5),
          ),
          child: Text(label,
              style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 14, color: AAColors.ink)),
        ),
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
    showAaToast(context, '保存成功');
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

  Future<void> _deleteAll() async {
    final ok = await showAaConfirm(
      context,
      title: '删除我的所有数据？',
      subtitle: '30天内会彻底物理删除',
      confirmLabel: '删除',
    );
    if (ok == true) {
      if (!mounted) return;
      showAaToast(context, '已提交删除申请');
    }
  }
}
