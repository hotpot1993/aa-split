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
import 'participants_panel.dart';

/// P32 选择参与人（编辑已有账单）
class ParticipantsScreen extends ConsumerStatefulWidget {
  const ParticipantsScreen({super.key, required this.billId});
  final String billId;
  @override
  ConsumerState<ParticipantsScreen> createState() => _ParticipantsScreenState();
}

class _ParticipantsScreenState extends ConsumerState<ParticipantsScreen> {
  @override
  Widget build(BuildContext context) {
    final all = ref.watch(billsProvider).value ?? const <Bill>[];
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
    final members = _toMembers(bill);

    return AaScaffold(
      appBar: AppBar(title: const Text('选择参与人')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ParticipantsPanel(
            members: members,
            myId: ref.watch(currentUserProvider)?.id ?? 'me',
            initialSelected: bill.participants.map((p) => p.userId).toSet(),
            onApply: _save,
          ),
        ],
      ),
    );
  }

  Future<void> _save(Set<String> selected) async {
    Bill? bill;
    for (final b in ref.read(billsProvider).value ?? const <Bill>[]) {
      if (b.id == widget.billId) {
        bill = b;
        break;
      }
    }
    if (bill == null) return;
    final members = _toMembers(bill);
    final keep = members.where((m) => selected.contains(m.userId)).toList();
    final lines = computeEven(bill.amountCents, keep, const {});
    final participants = lines.map((l) {
      BillParticipant? old;
      for (final p in bill!.participants) {
        if (p.userId == l.userId) {
          old = p;
          break;
        }
      }
      return BillParticipant(
        userId: l.userId,
        nickname: l.name,
        avatarUrl: l.avatarUrl,
        shareAmountCents: l.exempt ? 0 : l.amountCents,
        paid: old?.paid ?? false,
        exempt: l.exempt,
      );
    }).toList();
    await ref.read(billRepositoryProvider).replaceParticipants(widget.billId, participants);
    if (!mounted) return;
    ref.read(refreshProvider.notifier).bump();
    showAaToast(context, '参与人已更新');
    if (mounted) context.pop();
  }

  List<GroupMember> _toMembers(Bill bill) => bill.participants
      .map((p) => GroupMember(
            id: '${p.userId}_gm',
            userId: p.userId,
            nickname: p.nickname,
            accountName: '',
            avatarUrl: p.avatarUrl,
            isOwner: false,
          ))
      .toList();
}
