import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../models/bill_participant.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P14 账单详情页
class BillDetailScreen extends ConsumerStatefulWidget {
  const BillDetailScreen({super.key, required this.billId});
  final String billId;

  @override
  ConsumerState<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends ConsumerState<BillDetailScreen> {
  Bill? get _bill {
    final all = ref.read(billsProvider).value ?? const <Bill>[];
    for (final b in all) {
      if (b.id == widget.billId) return b;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bill = _bill;
    final text = Theme.of(context).textTheme;
    final me = ref.watch(currentUserProvider)?.id ?? 'me';
    if (bill == null) {
      return const AaScaffold(
        appBar: null,
        body: Center(child: EmptyState(title: '这张小票已经烧掉了🔥')),
      );
    }

    final perPerson = bill.participants.isEmpty
        ? 0
        : bill.amountCents ~/ bill.participants.length;
    final canManage = bill.payerId == me;

    return AaScaffold(
      appBar: AppBar(
        title: const Text('账单详情'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.edit, size: 22, color: AAColors.ink),
              onPressed: () => _edit(bill),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PaperCard(
            withTape: true,
            tiltSeed: bill.id,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(bill.title, style: text.headlineSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    // P33 拍凭证入口
                    IconButton(
                      onPressed: () => context.push('/bills/${bill.id}/receipt'),
                      tooltip: '拍凭证',
                      icon: const Icon(Icons.photo_camera, color: AAColors.ink, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                HandAmount(amountCents: bill.amountCents, color: AAColors.ink, size: 34),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    HandTag(label: Fmt.date(bill.billDate), icon: Icons.calendar_today),
                    HandTag(label: bill.groupName, icon: Icons.group),
                    HandTag(label: Cat.label(bill.category), icon: Icons.category),
                    if (bill.location.isNotEmpty) HandTag(label: bill.location, color: AAColors.mint),
                  ],
                ),
                if (bill.receipts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: bill.receipts
                        .map((r) => _ReceiptTile(url: r.url))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          PaperCard(
            color: AAColors.paperDeep,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.money, size: 18, color: AAColors.inkSoft),
                    const SizedBox(width: 6),
                    Text('我付了', style: text.titleSmall),
                    const Spacer(),
                    HandAmount(
                      amountCents: bill.amountCents,
                      color: AAColors.coral,
                      size: 22,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('垫付人：${bill.payerName}', style: text.bodySmall),
                const SizedBox(height: 10),
                Text(
                  '参与者 ${bill.participants.length} 人 · ${SplitText.label(bill.splitType)}'
                  '${bill.splitType == SplitType.even ? ' ${Fmt.yuan(perPerson)}/人' : ''}',
                  style: text.titleSmall,
                ),
                if (bill.fullySettled) ...[
                  const SizedBox(height: 8),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [StampBadge(text: '已结清')],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle('谁还没付'),
          ...bill.participants.map((p) => _ParticipantRow(participant: p, isPayer: p.userId == bill.payerId)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: DoodleButton(
                  label: '催款',
                  type: DoodleButtonType.secondary,
                  expand: true,
                  onPressed: () => context.push('/groups/${bill.groupId}/remind'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DoodleButton(
                  label: '标记已付',
                  expand: true,
                  onPressed: () => _markPaid(bill),
                ),
              ),
            ],
          ),
          if (canManage) ...[
            const SizedBox(height: 16),
            DoodleButton(
              label: '删除账单',
              type: DoodleButtonType.secondary,
              expand: true,
              color: AAColors.berry,
              textColor: AAColors.berry,
              onPressed: () => _delete(bill),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _markPaid(Bill bill) async {
    final result = await showAaSheet<bool>(
      context,
      child: _MarkPaidSheet(bill: bill),
    );
    if (result == true) {
      if (!mounted) return;
      ref.read(refreshProvider.notifier).bump();
      showAaToast(context, '已更新付款状态');
    }
  }

  void _edit(Bill bill) {
    showAaSheet(
      context,
      child: _EditSheet(bill: bill, onSave: (title, cents) async {
        await ref.read(billRepositoryProvider).update(bill.id, title: title, amountCents: cents);
        if (!mounted) return;
        ref.read(refreshProvider.notifier).bump();
        showAaToast(context, '账单已更新');
      }),
    );
  }

  Future<void> _delete(Bill bill) async {
    final ok = await showAaConfirm(
      context,
      title: '要撕掉这张小票吗？',
      subtitle: '删除后从流水里消失，撤销不了了哦',
      confirmLabel: '撕掉',
    );
    if (ok == true) {
      if (!mounted) return;
      await ref.read(billRepositoryProvider).delete(bill.id);
      if (!mounted) return;
      ref.read(refreshProvider.notifier).bump();
      showAaToast(context, '小票已撕掉');
      context.pop();
    }
  }
}

class _ReceiptTile extends StatelessWidget {
  const _ReceiptTile({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    // Demo 模式为 emoji 占位；真实模式展示上传后的凭证图片
    if (url.startsWith('🧾') || url.isEmpty) {
      return Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AAColors.cardWhite,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AAColors.ink, width: 1.5),
        ),
        child: Text(url, style: const TextStyle(fontSize: 30)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.network(
        absReceiptUrl(url),
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AAColors.cardWhite,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AAColors.ink, width: 1.5),
          ),
          child: const Icon(Icons.broken_image, color: AAColors.inkSoft, size: 24),
        ),
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({required this.participant, required this.isPayer});
  final BillParticipant participant;
  final bool isPayer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final paid = participant.paid;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          SketchAvatar(emoji: participant.avatarUrl, size: 40, name: participant.nickname),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              participant.nickname,
              style: text.titleMedium,
            ),
          ),
          if (participant.exempt)
            const HandTag(label: '全免', color: AAColors.lemon, icon: Icons.emoji_events)
          else if (isPayer)
            const HandTag(label: '垫付人', color: AAColors.sky)
          else
            Text(
              paid ? '✓ 已付' : '○ 未付',
              style: TextStyle(
                fontFamily: 'ZCOOLKuaiLe',
                color: paid ? AAColors.mint : AAColors.coral,
                fontSize: 14,
              ),
            ),
          const SizedBox(width: 8),
          if (!participant.exempt)
            HandAmount(amountCents: participant.shareAmountCents, color: AAColors.ink, size: 18),
        ],
      ),
    );
  }
}

class _MarkPaidSheet extends ConsumerStatefulWidget {
  const _MarkPaidSheet({required this.bill});
  final Bill bill;
  @override
  ConsumerState<_MarkPaidSheet> createState() => _MarkPaidSheetState();
}

class _MarkPaidSheetState extends ConsumerState<_MarkPaidSheet> {
  late final Set<String> _toPay = {
    for (final p in widget.bill.participants)
      if (!p.paid && !p.exempt && p.userId != widget.bill.payerId) p.userId,
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('标记谁已付？', style: text.headlineSmall),
        const SizedBox(height: 8),
        Text('勾选已把钱转给垫付人的小伙伴', style: text.bodySmall),
        const SizedBox(height: 12),
        ...widget.bill.participants.map((p) {
          if (p.exempt || p.userId == widget.bill.payerId) return const SizedBox.shrink();
          final on = _toPay.contains(p.userId);
          return CheckboxListTile(
            value: on,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AAColors.mint,
            title: Text(p.nickname, style: text.titleMedium),
            onChanged: (v) => setState(() {
              if (v == true) {
                _toPay.add(p.userId);
              } else {
                _toPay.remove(p.userId);
              }
            }),
          );
        }),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: DoodleButton(
                label: '批量标记已付',
                expand: true,
                onPressed: () {
                  _apply();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Future<void> _apply() async {
    final repo = ref.read(billRepositoryProvider);
    for (final id in _toPay) {
      await repo.markPaid(widget.bill.id, id, true);
    }
    if (mounted) Navigator.of(context).pop(true);
  }
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.bill, required this.onSave});
  final Bill bill;
  final void Function(String title, int cents) onSave;
  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _title = TextEditingController(text: widget.bill.title);
  late final TextEditingController _amount = TextEditingController(
      text: '${(widget.bill.amountCents ~/ 100)}.${(widget.bill.amountCents % 100).toString().padLeft(2, '0')}');

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cents = _parseCents(_amount.text);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('编辑账单', style: text.headlineSmall),
        const SizedBox(height: 12),
        Text('标题', style: text.bodyMedium),
        HandTextField(controller: _title),
        const SizedBox(height: 12),
        Text('金额', style: text.bodyMedium),
        HandTextField(controller: _amount, keyboardType: TextInputType.number),
        const SizedBox(height: 16),
        DoodleButton(
          label: '保存',
          expand: true,
          onPressed: cents != null && _title.text.isNotEmpty
              ? () {
                  widget.onSave(_title.text, cents);
                  Navigator.of(context).pop();
                }
              : null,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  int? _parseCents(String s) {
    final v = double.tryParse(s);
    if (v == null || v < 0) return null;
    return (v * 100).round();
  }
}
