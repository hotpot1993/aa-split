import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/group.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

const _avatars = ['🐼', '🐶', '🐱', '🐰', '🦊'];

/// P21 创建群组 —— 对齐 docs/ui-demo/index.html
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _name = TextEditingController();
  final _intro = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  String _avatar = '🐼';
  GroupDefaultSplit _split = GroupDefaultSplit.even;

  @override
  void dispose() {
    _name.dispose();
    _intro.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    // 校验未通过时给出明确反馈（不再静默禁用按钮）
    if (_name.text.trim().isEmpty) {
      showAaToast(context, '先给群组起个名吧～');
      _nameFocus.requestFocus();
      return;
    }
    if (_name.text.trim().length > 20) {
      showAaToast(context, '群名太长啦，20个字以内哦');
      _nameFocus.requestFocus();
      return;
    }
    try {
      final group = await ref.read(groupRepositoryProvider).create(
            name: _name.text.trim(),
            intro: _intro.text.trim(),
            avatar: _avatar,
            defaultSplit: _split,
          );
      ref.read(refreshProvider.notifier).bump();
      if (!mounted) return;
      showAaToast(context, '🍡 群组创建成功！');
      // 引导邀请
      if (mounted) context.pushReplacement('/groups/${group.id}/invite');
    } catch (e) {
      showAaToast(context, '创建失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AaScaffold(
      appBar: AaAppBar(title: '🏕 创建群组', icon: '🎨'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 选队徽（Demo：五枚 .ava，选中荧光笔黄底）
          SizedBox(height: 6),
          Center(
            child: Text('选一个队伍头像：',
                style: TextStyle(
                    fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
          ),
          SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _avatars.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: GestureDetector(
                    onTap: () => setState(() => _avatar = _avatars[i]),
                    child: SketchAvatar(
                      emoji: _avatars[i],
                      size: 44,
                      background: _avatar == _avatars[i]
                          ? AAColors.marker
                          : AAColors.cardWhite,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 14),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                AaLine(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('群组名称',
                          style: TextStyle(
                              fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
                      SizedBox(
                        width: 180,
                        child: HandTextField(
                          controller: _name,
                          focusNode: _nameFocus,
                          hint: '饭友群',
                          textAlign: TextAlign.end,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                AaLine(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('简介（选填）',
                          style: TextStyle(
                              fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
                      SizedBox(
                        width: 180,
                        child: HandTextField(
                          controller: _intro,
                          hint: '干饭第一名！',
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ),
                AaLine(
                  showBorder: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('默认分摊',
                          style: TextStyle(
                              fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
                      DropdownButtonHideUnderline(
                        child: DropdownButton<GroupDefaultSplit>(
                          value: _split,
                          icon: Text('▾',
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
              ],
            ),
          ),
          SizedBox(height: 16),
          DoodleButton(
            label: '创建，拉上小伙伴 →',
            big: true,
            onPressed: _create,
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
}
