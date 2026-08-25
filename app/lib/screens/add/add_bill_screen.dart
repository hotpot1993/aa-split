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
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final members = (ref.watch(groupMembersProvider).value ?? const {})[_groupId] ?? const [];
    final n = _selectedMembers.length;
    final perEven = n == 0 ? 0 : _amountCents ~/ n;

    if (_saved) {
      return _Celebration(onDone: () {
        if (mounted) context.pop();
      });
    }

    return AaScaffold(
      appBar: AaAppBar(
        title: '记一笔',
        back: false,
        headIcon: 'assets/icons/notebook.png',
        iconImage: 'assets/icons/camera.png',
        onIconTap: _addReceipt,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // 金额区（Demo：¥ + 58px 数字 + 虚线 + chip）
              Container(
                height: 210,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 92,
                      child: TextField(
                        controller: _amountCtrl,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'LongCang', fontSize: 58, color: AAColors.ink, height: 1.1),
                        onChanged: (v) => setState(() {
                          _amountCents = _parseCents(v);
                        }),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          hintStyle: TextStyle(fontFamily: 'LongCang', fontSize: 58, color: AAColors.inkSoft),
                          // Demo P30：¥ 用知音漫兴体 40px
                          prefixText: '¥ ',
                          prefixStyle: TextStyle(fontFamily: 'ZhiMangXing', fontSize: 40, color: AAColors.inkSoft),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    // 虚线（Demo：repeating-linear-gradient ink 0 10px, transparent 10px 15px）
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.6,
                      child: CustomPaint(
                        size: const Size(double.infinity, 3),
                        painter: _AmountDashPainter(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (n > 0)
                      HandTag(
                        '$n人 × ${Fmt.yuan(perEven, trimZero: true)} 均摊',
                        fontSize: 13,
                        variant: ChipVariant.orange,
                      )
                    else
                      const Text('输入金额，实时预览均摊',
                          style: TextStyle(
                              fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PaperCard(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                child: Column(
                  children: [
                    _FieldRow(
                      label: '标题',
                      child: HandTextField(controller: _titleCtrl, hint: '如 今晚聚餐'),
                    ),
                    _FieldRow(
                      label: '日期',
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(Fmt.date(_date),
                                style: const TextStyle(
                                    fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
                            const Text('▾', style: TextStyle(fontSize: 16, color: AAColors.inkSoft, height: 1)),
                          ],
                        ),
                      ),
                    ),
                    _FieldRow(
                      label: '群组',
                      child: groups.isEmpty
                          ? const Text('还没有群组',
                              style: TextStyle(
                                  fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft))
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _groupId,
                                isExpanded: true,
                                icon: const Text('▾',
                                    style: TextStyle(fontSize: 16, color: AAColors.inkSoft, height: 1)),
                                items: groups
                                    .map((g) =>
                                        DropdownMenuItem(value: g.id, child: Text(g.name)))
                                    .toList(),
                                onChanged: (v) => setState(() {
                                  _groupId = v ?? _groupId;
                                  _resetForGroup();
                                }),
                              ),
                            ),
                    ),
                    _FieldRow(
                      label: '分类',
                      child: GestureDetector(
                        onTap: _pickCategory,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${Cat.emoji(_category)} ${Cat.label(_category)}',
                                style: const TextStyle(
                                    fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
                            const Text('▾', style: TextStyle(fontSize: 16, color: AAColors.inkSoft, height: 1)),
                          ],
                        ),
                      ),
                    ),
                    _FieldRow(
                      label: '垫付人',
                      child: _payerChooser(members),
                    ),
                    _FieldRow(
                      label: '参与者',
                      child: GestureDetector(
                        onTap: _pickParticipants,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${_selectedIds.length}人',
                                style: const TextStyle(
                                    fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink)),
                            const Text('▾', style: TextStyle(fontSize: 16, color: AAColors.inkSoft, height: 1)),
                          ],
                        ),
                      ),
                    ),
                    _FieldRow(
                      label: '分摊方式',
                      child: GestureDetector(
                        onTap: _pickSplit,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _split?.summary ??
                                  '${SplitText.label(members.isEmpty ? SplitType.even : _defaultSplitType)} '
                                      '${_evenPerPersonText(members.length)}',
                              style: const TextStyle(
                                  fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.ink),
                            ),
                            const Text('▾', style: TextStyle(fontSize: 16, color: AAColors.inkSoft, height: 1)),
                          ],
                        ),
                      ),
                    ),
                    _FieldRow(
                      label: '凭证',
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: _addReceipt,
                            child: const Text('📷 拍照/相册',
                                style: TextStyle(
                                    fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.sky)),
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
                    // 定期账单（Demo：`.cbx` + `.mini` 文案）
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          AaCheckbox(
                            value: _isRegular,
                            onChanged: () => setState(() => _isRegular = !_isRegular),
                          ),
                          const SizedBox(width: 8),
                          const Text('⏰ 设为定期账单（每月自动生成）',
                              style: TextStyle(
                                  fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.ink)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DoodleButton(
                label: '收下这张小票！✓',
                big: true,
                onPressed: _canSave ? _save : null,
              ),
              const SizedBox(height: 10),
              const Text('📷 拍照凭证 · 只要30秒就记好啦',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
              const SizedBox(height: 16),
            ],
          ),
          // 💰 涂鸦装饰（Demo .doodle）→ 金币素材
          const Positioned(
            top: 70,
            right: 10,
            child: Opacity(
              opacity: 0.5,
              child: AaIconImage('assets/icons/coin.png', size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _evenPerPersonText(int n) {
    if (n <= 0 || _amountCents <= 0) return '';
    return '${Fmt.yuan(_amountCents ~/ n, trimZero: true)}/人';
  }

  Future<void> _pickCategory() async {
    final picked = await showAaSheet<BillCategory>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选个分类',
              style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 18, color: AAColors.ink)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: Cat.all.map((c) {
              final on = _category == c;
              return GestureDetector(
                onTap: () => Navigator.of(context).pop(c),
                child: HandTag(
                  '${Cat.emoji(c)} ${Cat.label(c)}',
                  selected: on,
                  fontSize: on ? 13 : 12,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (picked != null) setState(() => _category = picked);
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
        icon: const Text('▾', style: TextStyle(fontSize: 16, color: AAColors.inkSoft, height: 1)),
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
    // 手绘纸日历（替代系统 DatePicker 弹窗）
    final d = await showAaSheet<DateTime>(
      context,
      child: _HandDateSheet(initial: _date),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 64,
                child: Text(label,
                    style: const TextStyle(
                        fontFamily: 'ZCOOLKuaiLe', fontSize: 15, color: AAColors.inkSoft)),
              ),
              Expanded(child: Align(alignment: Alignment.centerRight, child: child)),
            ],
          ),
        ),
        CustomPaint(size: const Size(double.infinity, 2.5), painter: _DashLine2()),
      ],
    );
  }
}

class _DashLine2 extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AAColors.ink
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.butt;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1.25), Offset(x + 7, 1.25), p);
      x += 14;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 金额下方虚线 —— Demo：`repeating-linear-gradient(90deg,var(--ink) 0 10px,transparent 10px 15px)`
class _AmountDashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AAColors.ink
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1.5), Offset(x + 10, 1.5), p);
      x += 15;
    }
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

/// 手绘纸日历 —— 替代系统 DatePicker（白纸卡 + 墨线网格 + 手写数字）
class _HandDateSheet extends StatefulWidget {
  const _HandDateSheet({required this.initial});
  final DateTime initial;
  @override
  State<_HandDateSheet> createState() => _HandDateSheetState();
}

class _HandDateSheetState extends State<_HandDateSheet> {
  late int _y = widget.initial.year;
  late int _m = widget.initial.month;
  late int _d = widget.initial.day;

  int get _days {
    final last = DateTime(_y, _m + 1, 0).day;
    return last;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final atNow = _y == now.year && _m == now.month;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => setState(() {
                if (_m == 1) {
                  _m = 12;
                  if (_y > 2020) _y--;
                } else {
                  _m--;
                }
              }),
              child: const Text('‹', style: TextStyle(fontSize: 24, color: AAColors.ink)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text('$_y年$_m月',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontFamily: 'ZCOOLKuaiLe', fontSize: 18, color: AAColors.ink)),
            ),
            const SizedBox(width: 14),
            InkWell(
              onTap: atNow
                  ? null
                  : () => setState(() {
                      if (_m == 12) {
                        _m = 1;
                        _y++;
                      } else {
                        _m++;
                      }
                    }),
              child: Text('›',
                  style: TextStyle(
                      fontSize: 24,
                      color: atNow ? AAColors.inkSoft.withValues(alpha: 0.4) : AAColors.ink)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CustomPaint(size: const Size(double.infinity, 2.5), painter: _CalDash()),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var d = 1; d <= _days; d++)
              Builder(builder: (_) {
                final selected = d == _d;
                return GestureDetector(
                  onTap: () => setState(() => _d = d),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AAColors.marker : AAColors.cardWhite,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? AAColors.ink : AAColors.inkSoft,
                        width: 1.5,
                      ),
                    ),
                    child: Text('$d',
                        style: TextStyle(
                            fontFamily: 'ZCOOLKuaiLe',
                            fontSize: 13,
                            color: selected ? AAColors.ink : AAColors.inkSoft)),
                  ),
                );
              }),
          ],
        ),
        const SizedBox(height: 12),
        DoodleButton(
          label: '就选 $_y年$_m月$_d日 ✓',
          big: true,
          onPressed: () => Navigator.of(context).pop(DateTime(_y, _m, _d)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CalDash extends CustomPainter {
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
