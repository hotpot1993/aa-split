import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aa_design/aa_design.dart';

import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P41 提醒设置 —— 对齐 docs/ui-demo/index.html
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

    return AaScaffold(
      appBar: AaAppBar(
        title: '提醒设置',
        headIcon: 'assets/icons/notify.png',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                _line('🧾 新账单提醒', prefs.newBill, (v) => ctrl.set(newBill: v)),
                _line('📢 催款提醒', prefs.remind, (v) => ctrl.set(remind: v)),
                _line('⏰ 定期账单提醒', prefs.regular, (v) => ctrl.set(regular: v)),
                _line('👥 群组动态@我', prefs.mention, (v) => ctrl.set(mention: v)),
                _line(
                  '免打扰时段 ${prefs.dndStart} - ${prefs.dndEnd} ▾',
                  prefs.dndEnabled,
                  (v) => ctrl.set(dndEnabled: v),
                  leadImage: 'assets/icons/sleep.png',
                  showBorder: false,
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
              hint: '嗨～上一笔AA你还没付哦，记得转我一下 🙏',
              onChanged: (v) => ctrl.setText(v),
            ),
          ),
          const SizedBox(height: 8),
          const Text('可以在这里改催款时带的默认话术',
              style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
          const SizedBox(height: 16),
          DoodleButton(
            label: '保存设置',
            big: true,
            onPressed: () => {
              showAaToast(context, '💾 提醒设置已保存'),
              Navigator.of(context).maybePop(),
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _line(String label, bool value, ValueChanged<bool> onChanged,
      {String? leadImage, bool showBorder = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (leadImage != null) ...[
                    AaIconImage(leadImage, size: 16),
                    const SizedBox(width: 6),
                  ],
                  Text(label,
                      style: const TextStyle(
                          fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft)),
                ],
              ),
              HandToggle(value: value, activeColor: AAColors.mint, onChanged: onChanged),
            ],
          ),
        ),
        if (showBorder)
          CustomPaint(size: const Size(double.infinity, 2.5), painter: _TogDash()),
      ],
    );
  }
}

class _TogDash extends CustomPainter {
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
