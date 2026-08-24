import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../models/bill_participant.dart';
import '../../models/group.dart';
import '../../models/group_member.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';
import 'bill_draft.dart';
import 'participants_panel.dart';
import 'split_panel.dart';

/// P30 记一笔（核心表单）
class AddBillScreen extends ConsumerStatefulWidget {
  const AddBillScreen({super.key, this.initialGroupId});
  final String? initialGroupId;
  @override
  ConsumerState<AddBillScreen> createState() => _AddBillScreenState();
}

class _AddBillScreenState extends ConsumerState<AddBillScreen> {
  final _amountCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  int _amountCents = 0;
  DateTime _date = DateTime.now();
  late String _groupId = '';
  BillCategory _category = BillCategory.food;
  late String _payerId = '';
  late Set<String> _selectedIds = {};
  SplitResult? _split;
  List<Receipt> _receipts = [];
  bool _isRegular = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final groups = await ref.read(groupsProvider.future);
    if (!mounted) return;
    setState(() {
      _groupId = widget.initialGroupId ??
          (groups.isEmpty ? '' : groups.first.id);
    });
    await _resetForGroup();
  }

  Future<void> _resetForGroup() async {
    final me = ref.read(currentUserProvider)?.id ?? 'me';
    final members =
        (await ref.read(groupMembersProvider.future))[_groupId] ?? const [];
    _payerId = me;
    _selectedIds = members.map((m) => m.userId).toSet();
    _split = null;
    _receipts = [];
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  List<GroupMember> get _selectedMembers {
    final all =
        (ref.read(groupMembersProvider).value ?? const {})[_groupId] ??
            const [];
    return all.where((m) => _selectedIds.contains(m.userId)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final members = (ref.watch(groupMembersProvider).value ?? const {})[_groupId] ?? const [];
    final amountH = (MediaQuery.of(context).size.height / 3).clamp(150.0, 300.0);
    final n = _selectedMembers.length;
    final perEven = n == 0 ? 0 : _amountCents ~/ n;

    if (_saved) {
      return _Celebration(onDone: () {
        if (mounted) context.pop();
      });
    }

    return AaScaffold(
      appBar: AppBar(
        title: const Text('✏️ 记一笔'),
        actions: [
          TextButton(
            onPressed: _amountCents > 0 && _groupId.isNotEmpty && _selectedIds.isNotEmpty ? _save : null,
            child: const Text('保存',
                style: TextStyle(color: AAColors.coral, fontFamily: 'ZCOOLKuaiLe', fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 金额区
          Container(
            height: amountH,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                SizedBox(
                  height: 90,
                  child: TextField(
                    controller: _amountCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'LongCang', fontSize: 56, color: AAColors.ink),
                    onChanged: (v) => setState(() {
                      _amountCents = _parseCents(v);
                    }),
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      hintStyle: TextStyle(fontFamily: 'LongCang', fontSize: 44, color: AAColors.inkSoft),
                      prefixText: '¥ ',
                      prefixStyle: TextStyle(fontFamily: 'LongCang', fontSize: 30, color: AAColors.inkSoft),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                _ShakeUnderline(),
                const SizedBox(height: 12),
                if (n > 0 && _amountCents > 0)
                  Center(
                    child: HighlightText(
                      '均摊 ${Fmt.yuan(perEven)}/人',
                      style: const TextStyle(fontFamily: 'LongCang', fontSize: 20, color: AAColors.ink),
                    ),
                  )
                else
                  Text('输入金额，实时预览均摊', style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _FieldRow(
            label: '标题',
            child: HandTextField(controller: _titleCtrl, hint: '如 今晚聚餐'),
          ),
          _FieldRow(
            label: '日期',
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickDate,
                  child: Text(Fmt.date(_date), style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
                ),
                const Icon(Icons.arrow_drop_down, color: AAColors.inkSoft),
              ],
            ),
          ),
          _FieldRow(
            label: '群组',
            child: groups.isEmpty
                ? const Text('还没有群组', style: TextStyle(color: AAColors.inkSoft))
                : DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _groupId,
                      isExpanded: true,
                      items: groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))).toList(),
                      onChanged: (v) => setState(() {
                        _groupId = v ?? _groupId;
                        _resetForGroup();
                      }),
                    ),
                  ),
          ),
          SectionTitle('分类'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Cat.all.map((c) {
              final on = _category == c;
              return GestureDetector(
                onTap: () => setState(() => _category = c),
                child: HandTag(
                  label: '${Cat.emoji(c)} ${Cat.label(c)}',
                  color: on ? AAColors.coral : AAColors.inkSoft,
                  textColor: on ? AAColors.coral : AAColors.ink,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _FieldRow(
            label: '垫付人',
            child: _payerChooser(members),
          ),
          _FieldRow(
            label: '参与者',
            child: GestureDetector(
              onTap: _pickParticipants,
              child: Text(
                '${_selectedIds.length}人',
                style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.sky),
              ),
            ),
          ),
          _FieldRow(
            label: '分摊',
            child: GestureDetector(
              onTap: _pickSplit,
              child: Text(
                _split?.summary ?? '自动（${SplitText.label(members.isEmpty ? SplitType.even : _defaultSplitType)}）',
                style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.sky),
              ),
            ),
          ),
          _FieldRow(
            label: '凭证',
            child: Row(
              children: [
                GestureDetector(
                  onTap: _addReceipt,
                  child: const Text('📷 拍照/相册', style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.sky)),
                ),
                if (_receipts.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  ..._receipts.map((r) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _MiniReceipt(emoji: r.url),
                      )),
                ],
              ],
            ),
          ),
          _FieldRow(
            label: '定期',
            child: GestureDetector(
              onTap: () => setState(() => _isRegular = !_isRegular),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isRegular) const Text('⏰ 交给团团记着！', style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 14, color: AAColors.coral)),
                  const SizedBox(width: 8),
                  HandToggle(
                    value: _isRegular,
                    activeColor: AAColors.mint,
                    onChanged: (v) => setState(() => _isRegular = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          DoodleButton(
            label: '收下这张小票！',
            expand: true,
            onPressed: _canSave ? _save : null,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  SplitType get _defaultSplitType {
    final group = _group;
    return switch (group?.defaultSplit.name ?? 'even') {
      'custom' => SplitType.custom,
      'ratio' => SplitType.ratio,
      _ => SplitType.even,
    };
  }

  Group? get _group {
    for (final g in ref.read(groupsProvider).value ?? const <Group>[]) {
      if (g.id == _groupId) return g;
    }
    return null;
  }

  bool get _canSave =>
      _amountCents > 0 && _groupId.isNotEmpty && _selectedIds.isNotEmpty && _payerInParticipants;

  bool get _payerInParticipants =>
      _payerId.isEmpty || _selectedIds.isEmpty || _selectedIds.contains(_payerId);

  Widget _payerChooser(List<GroupMember> members) {
    if (members.isEmpty) return const Text('—');
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _payerId.isEmpty ? null : _payerId,
        isExpanded: true,
        items: members.map((m) => DropdownMenuItem(value: m.userId, child: Text(m.nickname))).toList(),
        onChanged: (v) => setState(() {
          if (v != null) {
            _payerId = v;
            _selectedIds.add(v);
          }
        }),
      ),
    );
  }

  Future<void> _pickParticipants() async {
    final result = await showAaSheet<Set<String>>(
      context,
      child: ParticipantsPanel(
        members: (ref.read(groupMembersProvider).value ?? const {})[_groupId] ?? const [],
        myId: ref.read(currentUserProvider)?.id ?? 'me',
        initialSelected: _selectedIds,
      ),
    );
    if (result != null) {
      setState(() {
        _selectedIds = result;
        if (!_selectedIds.contains(_payerId) && _selectedIds.isNotEmpty) {
          _payerId = _selectedIds.first;
        }
      });
    }
  }

  Future<void> _pickSplit() async {
    final result = await showAaSheet<SplitResult>(
      context,
      child: SplitPanel(
        amountCents: _amountCents,
        members: _selectedMembers,
        initialType: _split?.type ?? _defaultSplitType,
        initialShares: _split == null ? const {} : {for (final l in _split!.lines) l.userId: l.amountCents},
        initialExempt: _split == null ? const {} : {for (final l in _split!.lines) if (l.exempt) l.userId},
      ),
    );
    if (result != null) setState(() => _split = result);
  }

  Future<void> _addReceipt() async {
    final ok = await showAaConfirm(context, title: '模拟拍摄凭证', subtitle: 'Demo 中自动生成一张小票', confirmLabel: '拍摄');
    if (ok == true) {
      setState(() => _receipts = [..._receipts, Receipt(id: 'r${_receipts.length}', billId: '', url: '🧾')]);
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _date = d);
  }

  int _parseCents(String v) {
    final d = double.tryParse(v);
    return d == null ? 0 : (d * 100).round();
  }

  Future<void> _save() async {
    if (!_canSave) return;
    final repo = ref.read(billRepositoryProvider);
    final user = ref.read(currentUserProvider)!;
    final group = _group;

    List<BillParticipant> participants;
    if (_split != null) {
      participants = _split!.lines.map((l) {
        return BillParticipant(
          userId: l.userId,
          nickname: l.name,
          avatarUrl: l.avatarUrl,
          shareAmountCents: l.exempt ? 0 : l.amountCents,
          paid: l.userId == _payerId,
          exempt: l.exempt,
        );
      }).toList();
    } else {
      final lines = computeEven(_amountCents, _selectedMembers, const {});
      participants = lines.map((l) {
        return BillParticipant(
          userId: l.userId,
          nickname: l.name,
          avatarUrl: l.avatarUrl,
          shareAmountCents: l.amountCents,
          paid: l.userId == _payerId,
          exempt: l.exempt,
        );
      }).toList();
    }

    await repo.create(
      groupId: _groupId,
      groupName: group?.name ?? '',
      title: _titleCtrl.text.trim().isEmpty ? '未命名账单' : _titleCtrl.text.trim(),
      amountCents: _amountCents,
      billDate: _date,
      category: _category,
      payerId: _payerId,
      payerName: user.nickname,
      participants: participants,
      splitType: _split?.type ?? SplitType.even,
      receipts: _receipts,
      isRegular: _isRegular,
    );
    ref.read(refreshProvider.notifier).bump();
    if (mounted) setState(() => _saved = true);
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 60, child: Text(label, style: text.bodyMedium)),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ShakeUnderline extends StatelessWidget {
  const _ShakeUnderline();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 6),
      painter: _Underline2(),
    );
  }
}

class _Underline2 extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AAColors.coral
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..quadraticBezierTo(size.width * 0.3, size.height / 2 + 3, size.width * 0.55, size.height / 2)
      ..quadraticBezierTo(size.width * 0.8, size.height / 2 - 3, size.width, size.height / 2);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _MiniReceipt extends StatelessWidget {
  const _MiniReceipt({required this.emoji});
  final String emoji;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AAColors.cardWhite,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AAColors.ink, width: 1.2),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }
}

class _Celebration extends StatelessWidget {
  const _Celebration({required this.onDone});
  final VoidCallback onDone;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AAColors.paper,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CheckDraw(color: AAColors.mint, size: 96),
            const SizedBox(height: 8),
            Text('已保存，等TA们摊钱咯~', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const CoinBurst(count: 6),
            const SizedBox(height: 20),
            DoodleButton(label: '好的', type: DoodleButtonType.secondary, onPressed: onDone),
          ],
        ),
      ),
    );
  }
}
