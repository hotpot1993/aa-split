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

/// P22 邀请成员页
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
    final text = Theme.of(context).textTheme;
    final members = (ref.watch(groupMembersProvider).value ?? const {})[widget.groupId] ?? const [];

    return AaScaffold(
      appBar: AppBar(title: const Text('邀请小伙伴')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PaperCard(
            withPin: true,
            tiltSeed: 'invite-${widget.groupId}',
            child: Column(
              children: [
                Text('邀请链接', style: text.titleSmall),
                const SizedBox(height: 4),
                Text(_link, style: const TextStyle(color: AAColors.sky, fontFamily: 'ZCOOLKuaiLe', fontSize: 13)),
                const SizedBox(height: 10),
                DoodleButton(
                  label: '复制邀请链接',
                  type: DoodleButtonType.secondary,
                  expand: true,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _link));
                    showAaToast(context, '链接已复制，发给TA吧');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AAColors.cardWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AAColors.ink, width: 2),
                  ),
                  child: QrImageView(
                    data: _link,
                    size: 190,
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
                const Positioned(top: -6, left: -6, child: PinDecorator()),
                const Positioned(top: -6, right: -6, child: PinDecorator()),
                const Positioned(bottom: -6, left: -6, child: PinDecorator()),
                const Positioned(bottom: -6, right: -6, child: PinDecorator()),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text('扫码 → 打开App → 登录 → 确认加入', style: text.bodySmall),
          ),
          const SizedBox(height: 20),
          SectionTitle('按账户名添加'),
          Row(
            children: [
              Expanded(
                child: HandTextField(
                  controller: _account,
                  hint: '输入对方账户名',
                  keyboardType: TextInputType.text,
                ),
              ),
              const SizedBox(width: 8),
              DoodleButton(
                label: '添加',
                type: DoodleButtonType.secondary,
                onPressed: _add,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_added.isEmpty)
            Text('已添加：${members.isEmpty ? '暂无' : members.map((m) => m.nickname).join('、')}',
                style: text.bodySmall)
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _added
                  .map((n) => HandTag(label: '$n ✓', color: AAColors.mint))
                  .toList(),
            ),
          const SizedBox(height: 20),
          DoodleButton(
            label: '完成，进入群组',
            expand: true,
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
      _account.clear();
      showAaToast(context, '已添加 $name');
    } catch (e) {
      showAaToast(context, '添加失败：$e');
    }
  }
}
