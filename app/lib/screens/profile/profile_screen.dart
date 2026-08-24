import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../models/group.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_providers.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P50 个人主页
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return const AaScaffold(appBar: null, body: Center(child: EmptyState(title: '还没登录哦')));
    }
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final bills = ref.watch(billsProvider).value ?? const <Bill>[];
    final totalAA = bills.fold<int>(0, (s, b) => s + b.amountCents);
    final text = Theme.of(context).textTheme;

    return AaScaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          IconButton(
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings, size: 24, color: AAColors.ink),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 头像 + 资料
          Row(
            children: [
              GestureDetector(
                onTap: () => _editProfile(context, ref),
                child: const TuanTuan(size: 92, emotion: TuanTuanEmotion.happy),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.nickname, style: text.headlineMedium),
                    Text('@${user.accountName}', style: text.bodySmall),
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(user.bio, style: text.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 数据卡
          Row(
            children: [
              _DataCard(label: '我的群组', value: '${groups.length}', emoji: '👥'),
              const SizedBox(width: 10),
              _DataCard(label: '账单笔数', value: '${bills.length}', emoji: '🧾'),
              const SizedBox(width: 10),
              _DataCard(label: '累计AA', value: Fmt.yuanNoSymbol(totalAA), emoji: '💰'),
            ],
          ),
          const SizedBox(height: 20),
          _MenuRow(
            icon: Icons.download,
            emoji: '📦',
            label: '数据导出',
            onTap: () => context.push('/export'),
          ),
          _MenuRow(
            icon: Icons.person,
            emoji: '👤',
            label: '编辑昵称 / 头像',
            onTap: () => _editProfile(context, ref),
          ),
          _MenuRow(
            icon: Icons.settings,
            emoji: '⚙️',
            label: '设置',
            onTap: () => context.push('/settings'),
          ),
        ],
      ),
    );
  }

  void _editProfile(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    showAaSheet(
      context,
      child: _EditProfileSheet(
        nickname: user.nickname,
        bio: user.bio,
        onSave: (nickname, bio) async {
          try {
            await ref.read(authProvider.notifier).updateProfile(
                  nickname: nickname,
                  bio: bio,
                  avatarUrl: user.avatarUrl,
                );
            if (!context.mounted) return;
            showAaToast(context, '资料已更新');
          } catch (e) {
            if (!context.mounted) return;
            showAaToast(context, '保存失败：$e');
          }
        },
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard({required this.label, required this.value, required this.emoji});
  final String label;
  final String value;
  final String emoji;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: PaperCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        tiltSeed: label,
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontFamily: 'LongCang', fontSize: 22, color: AAColors.ink)),
            Text(label, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.emoji, required this.label, required this.onTap});
  final IconData icon;
  final String emoji;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: PaperCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: text.titleMedium)),
            const Icon(Icons.arrow_forward, color: AAColors.inkSoft, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.nickname,
    required this.bio,
    required this.onSave,
  });
  final String nickname;
  final String bio;
  final Future<void> Function(String nickname, String bio) onSave;
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nickname = TextEditingController(text: widget.nickname);
  late final TextEditingController _bio = TextEditingController(text: widget.bio);

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('编辑资料', style: text.headlineSmall),
        const SizedBox(height: 12),
        Text('昵称', style: text.bodyMedium),
        HandTextField(controller: _nickname),
        const SizedBox(height: 12),
        Text('个性签名', style: text.bodyMedium),
        HandTextField(controller: _bio, maxLines: 2),
        const SizedBox(height: 16),
        DoodleButton(
          label: '保存',
          expand: true,
          onPressed: _nickname.text.trim().isEmpty
              ? null
              : () async {
                  await widget.onSave(_nickname.text.trim(), _bio.text.trim());
                  if (context.mounted) Navigator.of(context).pop();
                },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
