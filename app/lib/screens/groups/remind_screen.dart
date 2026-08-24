import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P26 催款页
class RemindScreen extends ConsumerStatefulWidget {
  const RemindScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<RemindScreen> createState() => _RemindScreenState();
}

class _RemindScreenState extends ConsumerState<RemindScreen> {
  late final TextEditingController _message = TextEditingController();
  late Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(notifyPrefsProvider);
    _message.text = prefs.remindDefaultText;
    // 默认全选未付成员
    _selected = _unpaidTargets().map((e) => e.userId).toSet();
  }

  List<_Target> _unpaidTargets() {
    final bills = (ref.read(billsProvider).value ?? const <Bill>[])
        .where((b) => b.groupId == widget.groupId)
        .toList();
    final set = <String, _Target>{};
    for (final b in bills) {
      if (b.fullySettled) continue;
      for (final p in b.participants) {
        if (p.exempt || p.paid || p.userId == b.payerId) continue;
        set[p.userId] = _Target(p.userId, p.nickname, p.avatarUrl, b.title, p.shareAmountCents);
      }
    }
    return set.values.toList();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final targets = _unpaidTargets();
    final sending = _selected.isNotEmpty && _message.text.trim().isNotEmpty;

    if (targets.isEmpty) {
      return AaScaffold(
        appBar: AppBar(title: const Text('催款')),
        body: const Center(
          child: EmptyState(
            title: '没有欠款要催，大家都超靠谱！',
            emotion: TuanTuanEmotion.happy,
          ),
        ),
      );
    }

    return AaScaffold(
      appBar: AppBar(title: const Text('催款')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SectionTitle('选择催款对象（默认全选）'),
          ...targets.map((t) => _TargetTile(
                target: t,
                selected: _selected.contains(t.userId),
                onChanged: (v) => setState(() {
                  if (v) {
                    _selected.add(t.userId);
                  } else {
                    _selected.remove(t.userId);
                  }
                }),
              )),
          const SizedBox(height: 16),
          SectionTitle('催款文案'),
          PaperCard(
            child: HandTextField(
              controller: _message,
              maxLines: 4,
              hint: '写下你温柔又不失礼貌的催款话',
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DoodleButton(
                  label: '📣 发送',
                  expand: true,
                  onPressed: sending ? _send : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('发送后对方会在「消息」里收到催款提醒',
              textAlign: TextAlign.center, style: text.bodySmall),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final bills = (ref.read(billsProvider).value ?? const <Bill>[])
        .where((b) => b.groupId == widget.groupId)
        .toList();
    final firstBill = bills.firstWhere((b) => b.hasUnpaid, orElse: () => bills.first);
    await ref.read(billRepositoryProvider).remind(firstBill.id, _selected.toList(), _message.text);
    for (final t in _unpaidTargets()) {
      if (_selected.contains(t.userId)) {
        await ref.read(notificationRepositoryProvider).sendRemind(
              billId: firstBill.id,
              billTitle: t.billTitle,
              userIds: [t.userId],
              message: _message.text,
            );
      }
    }
    if (!mounted) return;
    ref.read(refreshProvider.notifier).bump();
    showAaToast(context, '已催款，等TA们自觉');
  }
}

class _Target {
  const _Target(this.userId, this.nickname, this.avatar, this.billTitle, this.amountCents);
  final String userId;
  final String nickname;
  final String avatar;
  final String billTitle;
  final int amountCents;
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({
    required this.target,
    required this.selected,
    required this.onChanged,
  });
  final _Target target;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AAColors.lemon.withValues(alpha: 0.35) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SketchAvatar(emoji: target.avatar, size: 40, name: target.nickname),
                if (selected)
                  const Positioned(
                    top: -4,
                    child: Text('💰', style: TextStyle(fontSize: 18)),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(target.nickname, style: text.titleMedium),
                  Text('${target.billTitle} · ${Fmt.yuan(target.amountCents)}',
                      style: text.bodySmall),
                ],
              ),
            ),
            Checkbox(
              value: selected,
              activeColor: AAColors.mint,
              shape: const CircleBorder(side: BorderSide(color: AAColors.ink, width: 1.5)),
              onChanged: (v) => onChanged(v ?? false),
            ),
          ],
        ),
      ),
    );
  }
}
