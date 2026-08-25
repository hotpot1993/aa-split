import 'dart:io' show File;

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
    final all = ref.watch(billsProvider).value ?? const <Bill>[];
    for (final b in all) {
      if (b.id == widget.billId) return b;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(billsProvider);
    final bill = _bill;
    final me = ref.watch(currentUserProvider)?.id ?? 'me';
    // 深链/通知点击进入时数据可能仍在加载：等待而非误报"账单不存在"
    if (bill == null && billsAsync.isLoading) {
      return AaScaffold(
        appBar: null,
        body: Center(child: AaLoading()),
      );
    }
    if (bill == null) {
      return AaScaffold(
        appBar: null,
        body: Center(child: EmptyState(title: '这张小票已经烧掉了🔥')),
      );
    }

    final perPerson = bill.participants.isEmpty
        ? 0
        : bill.amountCents ~/ bill.participants.length;
    final canManage = bill.payerId == me;

    return AaScaffold(
      appBar: AaAppBar(
        title: '账单详情',
        headIcon: 'assets/icons/receipt.png',
        backLabel: '‹ 返回',
        iconImage: canManage ? 'assets/icons/edit.png' : null,
        onIconTap: canManage ? () => _edit(bill) : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 金额卡 Demo：标题 22px + 金额 42px + mini 信息行
          PaperCard(
            withTape: true,
            tiltSeed: bill.id,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('${bill.title} ${Cat.emoji(bill.category)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: AAFonts.title, fontSize: 22, color: AAColors.ink)),
                SizedBox(height: 6),
                HandAmount(amountCents: bill.amountCents, color: AASemantic.amountNeg, size: 42),
                SizedBox(height: 4),
                Text(
                  '${Fmt.date(bill.billDate)} · ${bill.groupName} · ${Cat.label(bill.category)}'
                  '${bill.location.isEmpty ? '' : ' · ${bill.location}'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft),
                ),
              ],
            ),
          ),
          // 拍立得凭证（Demo：两张拍立得 + 小字标题）
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (bill.receipts.isEmpty)
                GestureDetector(
                  onTap: () => context.push('/bills/${bill.id}/receipt'),
                  child: _Polaroid(
                      emoji: '📷', image: 'assets/icons/camera.png', caption: '拍小票📷', rotate: -2),
                )
              else ...[
                for (var i = 0; i < bill.receipts.take(2).length; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 14),
                    child: _Polaroid(
                      emoji: i == 0 ? '🧾' : '🍲',
                      image: i == 0
                          ? 'assets/icons/receipt.png'
                          : 'assets/icons/food.png',
                      caption: i == 0 ? '小票📷' : '凭据',
                      rotate: i == 0 ? -2 : 2,
                      url: bill.receipts[i].url,
                      // 点击缩略图：大图预览 + 重新拍照/相册换图
                      onTap: () => context.push(
                          '/bills/${bill.id}/receipt/preview?receipt=${bill.receipts[i].id}'),
                    ),
                  ),
              ],
              if (bill.receipts.isEmpty) SizedBox(width: 14),
              if (bill.receipts.isEmpty)
                _Polaroid(
                    emoji: '🧾', image: 'assets/icons/receipt.png', caption: '结账单', rotate: 2),
            ],
          ),
          SizedBox(height: 16),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                AaLine(
                  label: '垫付人',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('垫付人',
                          style: TextStyle(
                              fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
                      Text.rich(TextSpan(children: [
                        TextSpan(
                            text: '${bill.payerName} ',
                            style: TextStyle(
                                fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                        TextSpan(
                            text: '（已垫付 ${Fmt.yuan(bill.amountCents)}）',
                            style: TextStyle(
                                fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
                      ])),
                    ],
                  ),
                ),
                AaLine(
                  label: '分摊方式',
                  value: '${SplitText.label(bill.splitType)} ${Fmt.yuan(perPerson)} / 人',
                  showBorder: false,
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('👥 谁还没付？',
                    style: TextStyle(fontFamily: AAFonts.title, fontSize: 14, color: AAColors.ink)),
                SizedBox(height: 4),
                ...bill.participants.map((p) => _ParticipantLine(
                      participant: p,
                      isPayer: p.userId == bill.payerId,
                      onTap: canManage ? () => _markPaid(bill) : null,
                    )),
              ],
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DoodleButton(
                  label: '📢 催款',
                  type: DoodleButtonType.secondary,
                  mini: true,
                  expand: true,
                  onPressed: () => context.push('/groups/${bill.groupId}/remind'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: DoodleButton(
                  label: canManage ? '✓ 标记已付' : '✓ 我付了',
                  mini: true,
                  expand: true,
                  onPressed: () => _markPaid(bill),
                ),
              ),
            ],
          ),
          if (canManage) ...[
            SizedBox(height: 16),
            DoodleButton(
              label: '删除账单',
              type: DoodleButtonType.secondary,
              expand: true,
              color: AAColors.berry,
              textColor: AAColors.berry,
              onPressed: () => _delete(bill),
            ),
          ],
          SizedBox(height: 16),
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

/// 拍立得 —— Demo `.polaroid`：`background:#fff;border:2.5px solid var(--ink);
/// padding:8px 8px 22px;border-radius:4px;rotate(-2deg);width:132px;
/// box-shadow:3px 3px 0 rgba(68,58,50,.2)`，内图 92px（纸米底虚线）。
class _Polaroid extends StatelessWidget {
  const _Polaroid({
    required this.emoji,
    required this.caption,
    required this.rotate,
    this.url = '',
    this.image,
    this.onTap,
  });
  final String emoji;
  final String? image;
  final String caption;
  final double rotate;
  final String url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Transform.rotate(
      angle: rotate / 180 * 3.14159265,
      child: Container(
        width: 132,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.fromBorderSide(BorderSide(color: AAColors.ink, width: 2.5)),
          borderRadius: BorderRadius.all(Radius.circular(4)),
          boxShadow: [AATokens.polaroidShadow],
        ),
        child: Column(
          children: [
            Container(
              height: 92,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AAColors.paperDeep,
                border: Border.all(color: AAColors.inkSoft, width: 2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: url.isEmpty || url.startsWith('🧾')
                  ? (image != null
                      ? AaIconImage(image!, size: 44)
                      : Text(emoji, style: TextStyle(fontSize: 40)))
                  : File(url).existsSync()
                      ? Image.file(
                          File(url),
                          width: 132,
                          height: 92,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(emoji,
                              style: TextStyle(fontSize: 40)),
                        )
                      : Image.network(
                          absReceiptUrl(url),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(emoji,
                              style: TextStyle(fontSize: 40)),
                        ),
            ),
            SizedBox(height: 4),
            Text(caption,
                style: TextStyle(
                    fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
            SizedBox(height: 18),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}

/// 参与人行 —— Demo `.line`：`✓ 我（已付）/ ○ 张三` + 右侧小胶囊（已付/未付 ¥xx）
class _ParticipantLine extends StatelessWidget {
  const _ParticipantLine({required this.participant, required this.isPayer, this.onTap});
  final BillParticipant participant;
  final bool isPayer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final paid = participant.paid;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${participant.paid ? '✓' : '○'} ${participant.nickname}${paid ? '（已付）' : ''}',
              style: TextStyle(
                  fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink),
            ),
            if (participant.exempt)
              const HandTag.label(label: '全免', dense: true, color: AAColors.lemon)
            else if (paid)
              const HandTag.label(label: '已付', dense: true, variant: ChipVariant.green)
            else
              HandTag(
                '未付 ${Fmt.yuan(participant.shareAmountCents, trimZero: true)}',
                dense: true,
                variant: ChipVariant.orange,
              ),
          ],
        ),
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
        SizedBox(height: 8),
        Text('勾选已把钱转给垫付人的小伙伴', style: text.bodySmall),
        SizedBox(height: 12),
        ...widget.bill.participants.map((p) {
          if (p.exempt || p.userId == widget.bill.payerId) return const SizedBox.shrink();
          final on = _toPay.contains(p.userId);
          return GestureDetector(
            onTap: () => setState(() {
              if (on) {
                _toPay.remove(p.userId);
              } else {
                _toPay.add(p.userId);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(p.nickname,
                      style: TextStyle(
                          fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                  AaCheckbox(
                    value: on,
                    onChanged: () => setState(() {
                      if (on) {
                        _toPay.remove(p.userId);
                      } else {
                        _toPay.add(p.userId);
                      }
                    }),
                  ),
                ],
              ),
            ),
          );
        }),
        SizedBox(height: 16),
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
        SizedBox(height: 8),
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
        SizedBox(height: 12),
        Text('标题', style: text.bodyMedium),
        HandTextField(controller: _title),
        SizedBox(height: 12),
        Text('金额', style: text.bodyMedium),
        HandTextField(controller: _amount, keyboardType: TextInputType.number),
        SizedBox(height: 16),
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
        SizedBox(height: 8),
      ],
    );
  }

  int? _parseCents(String s) {
    final v = double.tryParse(s);
    if (v == null || v < 0) return null;
    return (v * 100).round();
  }
}
