import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aa_design/aa_design.dart';

import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';

/// P41 提醒设置页
class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});
  @override
  ConsumerState<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends ConsumerState<ReminderSettingsScreen> {
  final _text = TextEditingController();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    _text.text = ref.read(notifyPrefsProvider).remindDefaultText;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notifyPrefsProvider);
    final ctrl = ref.read(notifyPrefsProvider.notifier);
    final text = Theme.of(context).textTheme;

    return AaScaffold(
      appBar: AppBar(title: const Text('提醒设置')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _ToggleRow(
            icon: Icons.receipt_long,
            label: '新账单提醒',
            value: prefs.newBill,
            onChanged: (v) => ctrl.set(newBill: v),
          ),
          _ToggleRow(
            icon: Icons.notifications_active,
            label: '催款提醒',
            value: prefs.remind,
            onChanged: (v) => ctrl.set(remind: v),
          ),
          _ToggleRow(
            icon: Icons.repeat,
            label: '定期账单提醒',
            value: prefs.regular,
            onChanged: (v) => ctrl.set(regular: v),
          ),
          _ToggleRow(
            icon: Icons.alternate_email,
            label: '群组动态 @ 我',
            value: prefs.mention,
            onChanged: (v) => ctrl.set(mention: v),
          ),
          const SizedBox(height: 16),
          SectionTitle('免打扰时段'),
          PaperCard(
            child: Row(
              children: [
                const Text('🌙', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Text('${prefs.dndStart} – ${prefs.dndEnd}',
                    style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 16)),
                const SizedBox(width: 8),
                Text('默认免打扰', style: const TextStyle(fontSize: 12, color: AAColors.inkSoft)),
                const Spacer(),
                HandToggle(
                  value: prefs.dndEnabled,
                  activeColor: AAColors.lilac,
                  onChanged: (v) => ctrl.set(dndEnabled: v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle('催款默认文案'),
          PaperCard(
            child: HandTextField(
              controller: _text,
              maxLines: 4,
              hint: '默认催款文案',
              onChanged: (v) => ctrl.setText(v),
            ),
          ),
          const SizedBox(height: 8),
          Text('可以在这里改催款时带的默认话术', style: text.bodySmall),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: AAColors.inkSoft, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: text.titleMedium)),
          HandToggle(value: value, activeColor: AAColors.mint, onChanged: onChanged),
        ],
      ),
    );
  }
}
