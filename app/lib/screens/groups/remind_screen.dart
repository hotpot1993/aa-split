import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/bill.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P26 催款页 —— 对齐 docs/ui-demo/index.html
class RemindScreen extends ConsumerStatefulWidget {
  const RemindScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<RemindScreen> createState() => _RemindScreenState();
}

class _RemindScreenState extends ConsumerState<RemindScreen> {
  late final TextEditingController _message = TextEditingController();
  late Set<String> _selected = {};
  int _remindCount = 1;

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
    final targets = _unpaidTargets();
    final sending = _selected.isNotEmpty && _message.text.trim().isNotEmpty;

    if (targets.isEmpty) {
      return AaScaffold(
        appBar: AaAppBar(
        title: '催款',
        headIcon: 'assets/icons/broadcast.png',
      ),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: EmptyState(
            title: '没有欠款要催，大家都超靠谱！',
            tag: 'P26 催款',
            art: '✅🍉',
          ),
        ),
      );
    }

    return AaScaffold(
      appBar: AaAppBar(
        title: '催款',
        headIcon: 'assets/icons/broadcast.png',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text('选一选还没付的小伙伴（默认全选）：',
              style: TextStyle(fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
          SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: targets.map((t) {
              final on = _selected.contains(t.userId);
              return GestureDetector(
                onTap: () => setState(() {
                  if (on) {
                    _selected.remove(t.userId);
                  } else {
                    _selected.add(t.userId);
                  }
                }),
                child: HandTag(
                  '${t.avatar} ${t.nickname}${on ? ' 💰' : ''}',
                  fontSize: 15,
                  selected: on,
                  vpad: 7,
                  hpad: 14,
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 12),
          // 催款小纸条：tape pink 卡 + 可编辑文案
          PaperCard(
            withTape: true,
            tapeColor: AATokens.tapePink,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('催款小纸条（可编辑）',
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
                SizedBox(height: 6),
                HandTextField(
                  controller: _message,
                  maxLines: 4,
                  hint: '嗨～上一笔AA你还没付哦，记得转我一下 🙏',
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          DoodleButton(
            label: '发送催款 ✈️',
            big: true,
            onPressed: sending ? _send : null,
          ),
          SizedBox(height: 10),
          Text(
            '已催过 $_remindCount 次 · 发送后对方会收到🔔提醒',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft),
          ),
          SizedBox(height: 16),
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
    setState(() => _remindCount++);
    showAaToast(context, '✈️ 催款已发出');
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
