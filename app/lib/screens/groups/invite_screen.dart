import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:aa_design/aa_design.dart';

import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P22 邀请成员 —— 对齐 docs/ui-demo/index.html
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _account = TextEditingController();
  final List<String> _added = [];
  String _link = '';

  @override
  void initState() {
    super.initState();
    _loadLink();
  }

  Future<void> _loadLink() async {
    try {
      final link =
          await ref.read(groupRepositoryProvider).inviteLink(widget.groupId);
      if (mounted) setState(() => _link = link);
    } catch (_) {
      // 链接拉取失败时留空，用户仍可通过成员列表页回到群组
    }
  }

  @override
  void dispose() {
    _account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final members =
        (ref.watch(groupMembersProvider).value ?? const {})[widget.groupId] ?? const [];

    return AaScaffold(
      appBar: AaAppBar(title: '📮 邀请成员', icon: '🎁'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 二维码卡（Demo：居中二维码 + .qr 纸框 + 链接 + 三颗小按钮）
          PaperCard(
            withTape: true,
            tapeColor: AATokens.tapeLemon,
            child: Column(
              children: [
                const SizedBox(height: 6),
                const Text('扫一扫 / 点链接 加入「饭友群」',
                    style: TextStyle(
                        fontFamily: 'ZCOOLKuaiLe', fontSize: 14, color: AAColors.ink)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AARadii.qr,
                    border: Border.all(color: AAColors.ink, width: 2.5),
                  ),
                  child: QrImageView(
                    data: _link,
                    size: 150,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: AAColors.ink,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: AAColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // 邀请链接：英文/数字点缀（规范 §4 第五级：Caveat 手写体）
                Text(_link,
                    style: const TextStyle(
                        fontFamily: 'Caveat',
                        fontSize: 16,
                        color: AAColors.inkSoft)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DoodleButton(
                      label: '复制链接',
                      mini: true,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _link));
                        showAaToast(context, '📋 邀请链接已复制');
                      },
                    ),
                    const SizedBox(width: 8),
                    DoodleButton(
                      label: '保存二维码',
                      mini: true,
                      onPressed: () => showAaToast(context, '🖼 已保存到相册'),
                    ),
                    const SizedBox(width: 8),
                    DoodleButton(
                      label: '分享',
                      mini: true,
                      onPressed: () => showAaToast(context, '📤 分享到微信'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 方式二：账户名直加
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                AaLine(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('方式二：账户名直加',
                          style: TextStyle(
                              fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 130,
                            child: HandTextField(
                              controller: _account,
                              hint: '🔍 输入账户名',
                              textAlign: TextAlign.end,
                            ),
                          ),
                          const SizedBox(width: 6),
                          DoodleButton(
                            label: '添加',
                            mini: true,
                            onPressed: _add,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AaLine(
                  showBorder: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('已添加',
                          style: TextStyle(
                              fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft)),
                      if (_added.isEmpty)
                        Text(
                          members.isEmpty
                              ? '暂无'
                              : members.map((m) => m.nickname).join('、'),
                          style: const TextStyle(
                              fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _added
                              .map((n) => HandTag.label(label: '$n ✓', color: AAColors.mint))
                              .toList(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DoodleButton(
            label: '完成，进入群组 →',
            big: true,
            onPressed: () => context.go('/groups/${widget.groupId}'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final name = _account.text.trim();
    if (name.isEmpty) {
      showAaToast(context, '先输入对方账户名');
      return;
    }
    try {
      await ref.read(groupRepositoryProvider).addMember(widget.groupId, name);
      if (!mounted) return;
      ref.read(refreshProvider.notifier).bump();
      setState(() => _added.add(name));
      showAaToast(context, '已添加 $name');
    } catch (_) {
      if (!mounted) return;
      showAaToast(context, '添加失败，检查一下名字');
    }
  }
}
