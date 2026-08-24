import 'dart:math';

import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../models/group_member.dart';
import 'bill_draft.dart';

/// 分摊设置面板（P31）—— 均摊/自定义/按比例/免分摊
/// 在底部弹层中使用；「生效」时通过 Navigator.pop 返回 SplitResult。
class SplitPanel extends StatefulWidget {
  const SplitPanel({
    super.key,
    required this.amountCents,
    required this.members,
    this.initialType = SplitType.even,
    this.initialShares = const {},
    this.initialExempt = const {},
    this.onApply,
  });

  final int amountCents;
  final List<GroupMember> members;
  final SplitType initialType;
  final Map<String, int> initialShares;
  final Set<String> initialExempt;

  /// 生效回调。为 null 时默认通过 Navigator.pop(result) 返回。
  final void Function(SplitResult result)? onApply;

  @override
  State<SplitPanel> createState() => _SplitPanelState();
}

class _SplitPanelState extends State<SplitPanel> {
  late SplitType _type = widget.initialType;
  late final Set<String> _exempt = {...widget.initialExempt};
  final Map<String, TextEditingController> _ctrl = {};
  final Map<String, double> _percent = {};

  @override
  void initState() {
    super.initState();
    for (final m in widget.members) {
      final cents = widget.initialShares[m.userId] ?? 0;
      _ctrl[m.userId] = TextEditingController(text: _fmtYuan(cents));
      _percent[m.userId] = defaultPercent(widget.members)[m.userId] ?? 0;
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _fmtYuan(int cents) => '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('分摊设置', style: text.headlineSmall),
        const SizedBox(height: 4),
        Text('总额 ${Fmt.yuan(widget.amountCents)}', style: text.bodySmall),
        const SizedBox(height: 12),
        _TypeRow(
          selected: _type,
          onSelect: (t) => setState(() => _type = t),
        ),
        const SizedBox(height: 12),
        _body(),
        const SizedBox(height: 12),
        DoodleButton(
          label: '生效',
          expand: true,
          onPressed: _apply,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _body() {
    final text = Theme.of(context).textTheme;
    switch (_type) {
      case SplitType.even:
        final per = widget.members.isEmpty
            ? 0
            : widget.amountCents ~/ widget.members.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.members.length > 1)
              Center(child: _PizzaPreview(slices: widget.members.length)),
            const SizedBox(height: 8),
            Text('每人均摊', textAlign: TextAlign.center, style: text.titleSmall),
            const SizedBox(height: 4),
            Center(
              child: HighlightText(
                '¥${(per ~/ 100)}.${(per % 100).toString().padLeft(2, '0')}/人',
                style: const TextStyle(fontFamily: 'LongCang', fontSize: 30, color: AAColors.ink),
              ),
            ),
            const SizedBox(height: 4),
            Text('共 ${widget.members.length} 人 · 追加免分摊人员请切到"免分摊"',
                textAlign: TextAlign.center, style: text.bodySmall),
          ],
        );
      case SplitType.custom:
        return Column(
          children: [
            for (final m in widget.members) _customRow(m),
            const SizedBox(height: 8),
            Text(
              '合计 ${Fmt.yuan(_customSum())} ${_customSum() == widget.amountCents ? '' : '（需等于总额 ${Fmt.yuan(widget.amountCents)}）'}',
              style: text.bodySmall,
            ),
          ],
        );
      case SplitType.ratio:
        return Column(
          children: [
            for (final m in widget.members)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(m.nickname, style: text.titleMedium),
                    const Spacer(),
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: TextEditingController(text: _percent[m.userId]?.toStringAsFixed(0) ?? '0'),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'LongCang', fontSize: 20),
                        onChanged: (v) => setState(() {
                          _percent[m.userId] = double.tryParse(v) ?? 0;
                        }),
                        decoration: const InputDecoration(isDense: true),
                      ),
                    ),
                    const Text('%', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text('总占比 ${_totalPercent().toStringAsFixed(0)}%', style: text.bodySmall),
          ],
        );
      case SplitType.exempt:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('勾选要免摊的人（请客者/司机等）', style: text.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.members.map((m) {
                final on = _exempt.contains(m.userId);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (on) {
                      _exempt.remove(m.userId);
                    } else {
                      _exempt.add(m.userId);
                    }
                  }),
                  child: Chip(
                    avatar: Text(on ? '🏅' : ''),
                    label: Text(m.nickname, style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 13, color: AAColors.ink)),
                    backgroundColor: on ? AAColors.lemon : AAColors.cardWhite,
                    side: const BorderSide(color: AAColors.ink, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            const Text('免摊人金额清零，其余人重新平均', style: TextStyle(fontSize: 12, color: AAColors.inkSoft)),
          ],
        );
    }
  }

  Widget _customRow(GroupMember m) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(m.nickname, style: text.titleMedium),
          const Spacer(),
          SizedBox(
            width: 90,
            child: TextField(
              controller: _ctrl[m.userId],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'LongCang', fontSize: 20),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixText: '¥',
                prefixStyle: const TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _customSum() {
    var s = 0;
    for (final m in widget.members) {
      s += _parseCents(_ctrl[m.userId]!.text);
    }
    return s;
  }

  int _totalPercent() {
    var p = 0.0;
    for (final m in widget.members) {
      p += _percent[m.userId] ?? 0;
    }
    return p.round();
  }

  int _parseCents(String s) {
    final v = double.tryParse(s);
    return v == null ? 0 : (v * 100).round();
  }

  void _apply() {
    List<ShareLine> lines;
    var summary = '';
    switch (_type) {
      case SplitType.even:
        lines = computeEven(widget.amountCents, widget.members, _exempt);
        summary = '均摊·共${widget.members.length}人';
      case SplitType.custom:
        final sum = _customSum();
        if (sum != widget.amountCents) {
          _toast(context, '分摊金额合计要等于账单金额哦');
          return;
        }
        lines = widget.members
            .map((m) => ShareLine(userId: m.userId, name: m.nickname, avatarUrl: m.avatarUrl, amountCents: _customCents(m)))
            .toList();
        summary = '自定义';
      case SplitType.ratio:
        lines = computeRatio(widget.amountCents, widget.members, _percent, _exempt);
        summary = '按比例';
      case SplitType.exempt:
        lines = applyExempt(widget.amountCents, widget.members, _exempt);
        summary = '免分摊·${_exempt.length}人免';
    }
    final result = SplitResult(type: _type, lines: lines, summary: summary);
    if (widget.onApply != null) {
      widget.onApply!(result);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  int _customCents(GroupMember m) => _parseCents(_ctrl[m.userId]!.text);
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.selected, required this.onSelect});
  final SplitType selected;
  final ValueChanged<SplitType> onSelect;

  static const _items = [
    (SplitType.even, '均摊'),
    (SplitType.custom, '自定义'),
    (SplitType.ratio, '按比例'),
    (SplitType.exempt, '免分摊'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _items
          .map((it) => Expanded(
                child: GestureDetector(
                  onTap: () => onSelect(it.$1),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected == it.$1 ? AAColors.mint.withValues(alpha: 0.3) : AAColors.cardWhite,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: selected == it.$1 ? AAColors.mint : AAColors.ink, width: 1.5),
                    ),
                    child: Text(it.$2,
                        style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 13, color: AAColors.ink)),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _PizzaPreview extends StatelessWidget {
  const _PizzaPreview({required this.slices});
  final int slices;
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(120, 120),
      painter: _PizzaPainter(slices),
    );
  }
}

class _PizzaPainter extends CustomPainter {
  _PizzaPainter(this.slices);
  final int slices;
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 4;
    final n = slices < 1 ? 1 : slices;
    final ink = Paint()
      ..color = AAColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var i = 0; i < n; i++) {
      final a0 = -1.57 + 2 * pi * i / n;
      final a1 = -1.57 + 2 * pi * (i + 1) / n;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + r * cos(a0), c.dy + r * sin(a0))
        ..arcTo(Rect.fromCircle(center: c, radius: r), a0, a1 - a0, false)
        ..close();
      canvas.drawPath(path, Paint()..color = AAColors.lemon.withValues(alpha: 0.5));
      canvas.drawPath(path, ink);
    }
    // 中间小脸（团团简笔）
    canvas.drawCircle(c, r * 0.22, Paint()..color = AAColors.cardWhite);
    canvas.drawCircle(c, r * 0.22, ink);
    canvas.drawCircle(c.translate(-r * 0.07, -r * 0.04), 2, Paint()..color = AAColors.ink);
    canvas.drawCircle(c.translate(r * 0.07, -r * 0.04), 2, Paint()..color = AAColors.ink);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * 0.1), 0.2, 2.6, false, ink);
  }

  @override
  bool shouldRepaint(covariant _PizzaPainter old) => old.slices != slices;
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(milliseconds: 1200)),
  );
}
