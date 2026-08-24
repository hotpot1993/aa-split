import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/bill.dart';
import '../../models/bill_participant.dart';
import '../../models/group_member.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';
import 'bill_draft.dart';
import 'split_panel.dart';

/// P31 分摊设置（编辑已有账单）
class SplitScreen extends ConsumerStatefulWidget {
  const SplitScreen({super.key, required this.billId});
  final String billId;
  @override
  ConsumerState<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends ConsumerState<SplitScreen> {
  @override
  Widget build(BuildContext context) {
    final all = ref.watch(billsProvider);
    Bill? bill;
    for (final b in all) {
      if (b.id == widget.billId) {
        bill = b;
        break;
      }
    }
    if (bill == null) {
      return const AaScaffold(appBar: null, body: Center(child: EmptyState(title: '账单不存在')));
    }
    final members = bill.participants.map(_toMember).toList();

    return AaScaffold(
      appBar: AppBar(title: const Text('分摊设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SplitPanel(
            amountCents: bill.amountCents,
            members: members,
            initialType: bill.splitType,
            initialExempt: {
              for (final p in bill.participants)
                if (p.exempt) p.userId,
            },
            initialShares: {
              for (final p in bill.participants) p.userId: p.shareAmountCents,
            },
            onApply: _save,
          ),
        ],
      ),
    );
  }

  void _save(SplitResult result) {
    final participants = result.lines.map((l) {
      return BillParticipant(
        userId: l.userId,
        nickname: l.name,
        avatarUrl: l.avatarUrl,
        shareAmountCents: l.exempt ? 0 : l.amountCents,
        paid: false,
        exempt: l.exempt,
      );
    }).toList();
    ref.read(billRepositoryProvider).replaceParticipants(widget.billId, participants);
    ref.read(refreshProvider.notifier).bump();
    showAaToast(context, '分摊已更新');
    if (mounted) context.pop();
  }

  GroupMember _toMember(BillParticipant p) => GroupMember(
        id: '${p.userId}_gm',
        userId: p.userId,
        nickname: p.nickname,
        accountName: '',
        avatarUrl: p.avatarUrl,
        isOwner: false,
      );
}
