import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/currency.dart';
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
  // 日期取自可注入时钟：golden 截图跨时段稳定（默认即系统时间）
  late DateTime _date = Fmt.clock();
  late String _groupId = '';
  /// 旅行常用货币（默认人民币）
  TravelCurrency _currency = travelCurrencies.first;
  BillCategory _category = BillCategory.food;
  late String _payerId = '';
  late Set<String> _selectedIds = {};
  SplitResult? _split;
  List<Receipt> _receipts = [];
  bool _isRegular = false;
  bool _saved = false;

  /// 防重复提交：保存进行中置位，重复点击直接忽略（单次操作仅生成一张账单）
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final groups = await ref.read(groupsProvider.future);
    if (!mounted) return;
    setState(() {
      // 群组详情进入时预选该群；id 失效/不存在则回退第一个群
      // （Dropdown 的 value 必须命中 items，否则会断言崩溃）
      final requested = widget.initialGroupId;
      final valid =
          requested != null && groups.any((g) => g.id == requested);
      _groupId = valid ? requested : (groups.isEmpty ? '' : groups.first.id);
    });
    await _resetForGroup();
  }

  Future<void> _resetForGroup() async {
    final me = ref.read(currentUserProvider)?.id ?? 'me';
    final members =
        (await ref.read(groupMembersProvider.future))[_groupId] ?? [];
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
        (ref.read(groupMembersProvider).value ?? {})[_groupId] ??
            [];
    return all.where((m) => _selectedIds.contains(m.userId)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final members = (ref.watch(groupMembersProvider).value ?? {})[_groupId] ?? [];
    final n = _selectedMembers.length;
    // 外币时按今日汇率折算成人民币（分）展示/均摊/入账
    final rateAsync = ref.watch(exchangeRateProvider(_currency.code));
    final rateResult = rateAsync.value;
    final rateReady = _currency.isCny || rateResult != null;
    final rmbCents = _currency.isCny
        ? _amountCents
        : (_amountCents * (rateResult?.rate ?? 1)).round();
    final perEven = n == 0 ? 0 : rmbCents ~/ n;

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
                        style: TextStyle(fontFamily: AAFonts.hand, fontSize: 58, color: AAColors.ink, height: 1.1),
                        onChanged: (v) => setState(() {
                          _amountCents = _parseCents(v);
                        }),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          hintStyle: TextStyle(fontFamily: AAFonts.hand, fontSize: 58, color: AAColors.inkSoft),
                          // 货币符号统一 JetBrains Mono 40px（外币时用对应货币符号）
                          prefixText: '${_currency.symbol} ',
                          prefixStyle: TextStyle(fontFamily: AAFonts.currency, fontSize: 40, color: AAColors.inkSoft),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    // 虚线（Demo：repeating-linear-gradient ink 0 10px, transparent 10px 15px）
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.6,
                      child: CustomPaint(
                        size: Size(double.infinity, 3),
                        painter: _AmountDashPainter(),
                      ),
                    ),
                    SizedBox(height: 10),
                    if (n > 0)
                      HandTag(
                        '$n人 × ${Fmt.yuan(perEven, trimZero: true)} 均摊',
                        fontSize: 13,
                        variant: ChipVariant.orange,
                      )
                    else
                      Text('输入金额，实时预览均摊',
                          style: TextStyle(
                              fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
                    // 外币：今日汇率折算提示
                    if (!_currency.isCny && _amountCents > 0) ...[
                      SizedBox(height: 8),
                      if (!rateReady)
                        Text('正在获取今日汇率…',
                            style: TextStyle(
                                fontFamily: AAFonts.title,
                                fontSize: 12,
                                color: AAColors.inkSoft))
                      else
                        Text(
                          '≈ ¥${Fmt.yuanNoSymbol(rmbCents)} · 今日汇率 1 ${_currency.code} ≈ '
                          '${rateResult!.rate.toStringAsFixed(4)}'
                          '${rateResult.isReference ? '（参考汇率）' : ''}',
                          style: TextStyle(
                              fontFamily: AAFonts.title,
                              fontSize: 12,
                              color: AAColors.inkSoft),
                        ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 12),
              PaperCard(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                child: Column(
                  children: [
                    _FieldRow(
                      label: '标题',
                      child: HandTextField(controller: _titleCtrl, hint: '如 今晚聚餐'),
                    ),
                    _FieldRow(
                      label: '货币',
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _currency.code,
                          isExpanded: true,
                          alignment: Alignment.centerRight,
                          icon: Text('▾',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: AAColors.inkSoft,
                                  height: 1)),
                          items: [
                            for (final c in travelCurrencies)
                              DropdownMenuItem(
                                value: c.code,
                                child: Text('${c.name} (${c.code})',
                                    style: TextStyle(
                                        fontFamily: AAFonts.title,
                                        fontSize: 15,
                                        color: AAColors.ink)),
                              ),
                          ],
                          onChanged: (v) => setState(() {
                            if (v == null) return;
                            _currency = travelCurrencies.firstWhere(
                                (c) => c.code == v,
                                orElse: () => travelCurrencies.first);
                            // 分摊明细按金额换算，换币种后作废重算
                            _split = null;
                          }),
                        ),
                      ),
                    ),
                    _FieldRow(
                      label: '日期',
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(Fmt.date(_date),
                                style: TextStyle(
                                    fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                            Text('▾', style: TextStyle(fontSize: 16, color: AAColors.inkSoft, height: 1)),
                          ],
                        ),
                      ),
                    ),
                    _FieldRow(
                      label: '群组',
                      child: groups.isEmpty
                          ? Text('还没有群组',
                              style: TextStyle(
                                  fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft))
                          : DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _groupId,
                                isExpanded: true,
                                alignment: Alignment.centerRight,
                                icon: Text('▾',
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
                                style: TextStyle(
                                    fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                            Text('▾', style: TextStyle(fontSize: 16, color: AAColors.inkSoft, height: 1)),
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
                                style: TextStyle(
                                    fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                            Text('▾', style: TextStyle(fontSize: 16, color: AAColors.inkSoft, height: 1)),
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
                              style: TextStyle(
                                  fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink),
                            ),
                            Text('▾', style: TextStyle(fontSize: 16, color: AAColors.inkSoft, height: 1)),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AaIconImage('assets/icons/camera.png', size: 16),
                                SizedBox(width: 4),
                                Text('拍照/相册',
                                    style: TextStyle(
                                        fontFamily: AAFonts.title,
                                        fontSize: 15,
                                        color: AAColors.sky)),
                              ],
                            ),
                          ),
                          if (_receipts.isNotEmpty) ...[
                            SizedBox(width: 8),
                            ..._receipts.map((r) => Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: _MiniReceipt(url: r.url),
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
                          SizedBox(width: 8),
                          AaIconImage('assets/icons/clock.png', size: 14),
                          SizedBox(width: 4),
                          Text('设为定期账单（每月自动生成）',
                              style: TextStyle(
                                  fontFamily: AAFonts.title, fontSize: 12, color: AAColors.ink)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12),
              DoodleButton(
                label: _saving ? '记账中…' : '收下这张小票！✓',
                big: true,
                onPressed: _canSave && !_saving ? _save : null,
              ),
              SizedBox(height: 10),
              Text('📷 拍照凭证 · 只要30秒就记好啦',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
              SizedBox(height: 16),
            ],
          ),
          // 💰 涂鸦装饰（Demo .doodle）→ 金币素材
          Positioned(
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

  /// 当前金额折算后的人民币（分）—— 外币时依赖当日汇率（未就绪时按 1 兜底，保存前会校验）
  int get _rmbCents {
    if (_currency.isCny) return _amountCents;
    final rate = ref.read(exchangeRateProvider(_currency.code)).value?.rate ?? 1;
    return (_amountCents * rate).round();
  }

  String _evenPerPersonText(int n) {
    if (n <= 0 || _rmbCents <= 0) return '';
    return '${Fmt.yuan(_rmbCents ~/ n, trimZero: true)}/人';
  }

  Future<void> _pickCategory() async {
    final picked = await showAaSheet<BillCategory>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选个分类',
              style: TextStyle(fontFamily: AAFonts.title, fontSize: 18, color: AAColors.ink)),
          SizedBox(height: 10),
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
          SizedBox(height: 8),
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
      _amountCents > 0 &&
      _groupId.isNotEmpty &&
      _selectedIds.isNotEmpty &&
      _payerInParticipants &&
      // 外币需等今日汇率就绪（避免按 1:1 误存）
      (_currency.isCny ||
          ref.read(exchangeRateProvider(_currency.code)).value != null);

  bool get _payerInParticipants =>
      _payerId.isEmpty || _selectedIds.isEmpty || _selectedIds.contains(_payerId);

  Widget _payerChooser(List<GroupMember> members) {
    if (members.isEmpty) return Text('—');
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _payerId.isEmpty ? null : _payerId,
        isExpanded: true,
        alignment: Alignment.centerRight,
        icon: Text('▾', style: TextStyle(fontSize: 16, color: AAColors.inkSoft, height: 1)),
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
        members: (ref.read(groupMembersProvider).value ?? {})[_groupId] ?? [],
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
        amountCents: _rmbCents,
        members: _selectedMembers,
        initialType: _split?.type ?? _defaultSplitType,
        initialShares: _split == null ? {} : {for (final l in _split!.lines) l.userId: l.amountCents},
        initialExempt: _split == null ? {} : {for (final l in _split!.lines) if (l.exempt) l.userId},
      ),
    );
    if (result != null) setState(() => _split = result);
  }

  /// 拍照/相册 → 直接调起系统相机/相册（P30 与 P33 真机链路一致），
  /// 选中的图片加入草稿凭证列表（本地文件路径，随账单保存）。
  Future<void> _addReceipt() async {
    final src = await showAaSheet<ImageSource>(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('凭证来源',
              style: TextStyle(fontFamily: AAFonts.title, fontSize: 18, color: AAColors.ink)),
          SizedBox(height: 12),
          DoodleButton(
            label: '拍一张',
            leadingImage: 'assets/icons/camera.png',
            expand: true,
            onPressed: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          SizedBox(height: 8),
          DoodleButton(
            label: '从相册选',
            leadingImage: 'assets/icons/picture.png',
            type: DoodleButtonType.secondary,
            expand: true,
            onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
    if (src == null || !mounted) return;
    try {
      // 系统相机/相册（Android 走 intent，无需 CAMERA 权限）
      final file = await ImagePicker().pickImage(
        source: src,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;
      setState(() {
        _receipts = [..._receipts, Receipt(id: 'r${_receipts.length}', billId: '', url: file.path)];
      });
    } catch (e) {
      if (mounted) showAaToast(context, '拍/选失败：$e');
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
    if (!_canSave || _saving || _saved) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(billRepositoryProvider);
      final user = ref.read(currentUserProvider)!;
      final group = _group;
      // 外币 → 按当日汇率折算成人民币（分）入账
      final rmbCents = _rmbCents;

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
        final lines = computeEven(rmbCents, _selectedMembers, {});
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
        amountCents: rmbCents,
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
      // 成功：不重置 _saving —— 页面随即切换为庆祝页，杜绝同帧连点窗口
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAaToast(context, '记账失败：$e');
      }
    }
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
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft)),
              ),
              Expanded(child: Align(alignment: Alignment.centerRight, child: child)),
            ],
          ),
        ),
        CustomPaint(size: Size(double.infinity, 2.5), painter: _DashLine2()),
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
  const _MiniReceipt({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final local = !url.startsWith('🧾') &&
        !url.startsWith('http') &&
        File(url).existsSync();
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AAColors.paperDeep,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AAColors.ink, width: 1.2),
      ),
      child: local
          ? Image.file(
              File(url),
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Text('🧾', style: TextStyle(fontSize: 18)),
            )
          : Text(url.startsWith('🧾') ? '🧾' : '📷',
              style: TextStyle(fontSize: 18)),
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
            CheckDraw(color: AAColors.mint, size: 96),
            SizedBox(height: 8),
            Text('已保存，等TA们摊钱咯~', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            CoinBurst(count: 6),
            SizedBox(height: 20),
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
              child: Text('‹', style: TextStyle(fontSize: 24, color: AAColors.ink)),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text('$_y年$_m月',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 18, color: AAColors.ink)),
            ),
            SizedBox(width: 14),
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
        SizedBox(height: 8),
        CustomPaint(size: Size(double.infinity, 2.5), painter: _CalDash()),
        SizedBox(height: 10),
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
                            fontFamily: AAFonts.title,
                            fontSize: 13,
                            color: selected ? AAColors.ink : AAColors.inkSoft)),
                  ),
                );
              }),
          ],
        ),
        SizedBox(height: 12),
        DoodleButton(
          label: '就选 $_y年$_m月$_d日 ✓',
          big: true,
          onPressed: () => Navigator.of(context).pop(DateTime(_y, _m, _d)),
        ),
        SizedBox(height: 8),
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
