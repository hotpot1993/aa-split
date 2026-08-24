import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/group.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

const _avatars = ['🐼', '🐶', '🐰', '🐻', '🐱', '🦊', '🐹', '🦌'];

/// P21 创建群组页
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  final _intro = TextEditingController();
  String _avatar = '🐼';
  GroupDefaultSplit _split = GroupDefaultSplit.even;

  @override
  void dispose() {
    _name.dispose();
    _intro.dispose();
    super.dispose();
  }

  bool get _canSubmit => _name.text.trim().isNotEmpty && _name.text.length <= 20;

  Future<void> _create() async {
    if (!_canSubmit) return;
    try {
      final group = await ref.read(groupRepositoryProvider).create(
            name: _name.text.trim(),
            intro: _intro.text.trim(),
            avatar: _avatar,
            defaultSplit: _split,
          );
      ref.read(refreshProvider.notifier).bump();
      if (!mounted) return;
      showAaToast(context, '创建成功，拉上小伙伴吧');
      // 引导邀请
      if (mounted) context.pushReplacement('/groups/${group.id}/invite');
    } catch (e) {
      showAaToast(context, '创建失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AaScaffold(
      appBar: AppBar(title: const Text('创建群组')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionTitle('选个群头像'),
          SizedBox(
            height: 76,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _avatars
                  .map((a) => GestureDetector(
                        onTap: () => setState(() => _avatar = a),
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _avatar == a ? AAColors.lemon.withValues(alpha: 0.6) : AAColors.cardWhite,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _avatar == a ? AAColors.coral : AAColors.ink,
                              width: 2,
                            ),
                          ),
                          child: Text(a, style: const TextStyle(fontSize: 30)),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle('群组名称（≤20字）'),
          HandTextField(
            controller: _name,
            hint: '如 饭友群',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SectionTitle('群简介（选填，≤50字）'),
          HandTextField(
            controller: _intro,
            hint: '一句话介绍这个群',
            maxLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          SectionTitle('默认分摊方式'),
          Row(
            children: [
              _SplitChip(
                label: '均摊',
                selected: _split == GroupDefaultSplit.even,
                onTap: () => setState(() => _split = GroupDefaultSplit.even),
              ),
              const SizedBox(width: 8),
              _SplitChip(
                label: '自定义',
                selected: _split == GroupDefaultSplit.custom,
                onTap: () => setState(() => _split = GroupDefaultSplit.custom),
              ),
              const SizedBox(width: 8),
              _SplitChip(
                label: '按比例',
                selected: _split == GroupDefaultSplit.ratio,
                onTap: () => setState(() => _split = GroupDefaultSplit.ratio),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const FieldHint(text: '新建账单会默认用这个分摊方式，随时可改'),
          const SizedBox(height: 28),
          DoodleButton(
            label: '创建群组',
            expand: true,
            onPressed: _canSubmit ? _create : null,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SplitChip extends StatelessWidget {
  const _SplitChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AAColors.mint.withValues(alpha: 0.3) : AAColors.cardWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AAColors.mint : AAColors.ink, width: 1.5),
          ),
          child: Text(label,
              style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 14, color: AAColors.ink)),
        ),
      ),
    );
  }
}

class FieldHint extends StatelessWidget {
  const FieldHint({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
