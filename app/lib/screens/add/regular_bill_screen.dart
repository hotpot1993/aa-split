import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../models/regular_bill.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P34 定期账单设置/管理页
class RegularBillScreen extends ConsumerStatefulWidget {
  const RegularBillScreen({super.key});
  @override
  ConsumerState<RegularBillScreen> createState() => _RegularBillScreenState();
}

class _RegularBillScreenState extends ConsumerState<RegularBillScreen> {
  @override
  Widget build(BuildContext context) {
    final regulars = ref.watch(regularBillsProvider);

    return AaScaffold(
      appBar: AppBar(
        title: const Text('定期账单'),
        actions: [
          IconButton(
            onPressed: _create,
            icon: const Icon(Icons.add, color: AAColors.ink, size: 26),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (regulars.any((r) => r.active))
            _Banner(),
          if (regulars.isEmpty)
            EmptyState(
              title: '还没有定期账单',
              subtitle: '房租、水电、会员费…交给团团记着',
              buttonLabel: '＋ 新建定期账单',
              onButtonTap: _create,
            )
          else
            ...regulars.map((r) => _RegularCard(
                  regular: r,
                  onToggle: (v) {
                    ref.read(billRepositoryProvider).toggleRegular(r.id, v);
                    ref.read(refreshProvider.notifier).bump();
                  },
                )),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final result = await showAaSheet<_RegularDraft>(
      context,
      child: _CreateRegularSheet(),
    );
    if (result != null) {
      if (!mounted) return;
      ref.read(billRepositoryProvider).createRegular(
            groupId: result.groupId,
            groupName: result.groupName,
            title: result.title,
            amountCents: result.amountCents,
            category: result.category,
            cycle: result.cycle,
            dayOfMonth: result.dayOfMonth,
          );
      ref.read(refreshProvider.notifier).bump();
      showAaToast(context, '⏰ 交给团团记着！');
    }
  }
}

class _Banner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AAColors.lemon.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AAColors.coral, width: 1.5),
      ),
      child: const Row(
        children: [
          Text('⏰', style: TextStyle(fontSize: 20)),
          SizedBox(width: 8),
          Expanded(
            child: Text('交给团团记着！到点自动生成账单',
                style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 14, color: AAColors.ink)),
          ),
        ],
      ),
    );
  }
}

class _RegularCard extends StatelessWidget {
  const _RegularCard({required this.regular, required this.onToggle});
  final RegularBill regular;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      margin: const EdgeInsets.only(bottom: 12),
      withTape: true,
      tiltSeed: regular.id,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(regular.title, style: text.titleLarge),
              const Spacer(),
              HandToggle(value: regular.active, activeColor: AAColors.mint, onChanged: onToggle),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              HandAmount(amountCents: regular.amountCents, color: AAColors.ink, size: 22),
              const SizedBox(width: 10),
              HandTag(label: Cat.label(regular.category), icon: Icons.repeat),
              const SizedBox(width: 6),
              HandTag(label: _cycleText(regular), color: AAColors.lilac),
            ],
          ),
        ],
      ),
    );
  }

  String _cycleText(RegularBill r) => switch (r.cycle) {
        RegularCycle.weekly => '每周',
        RegularCycle.biweekly => '每两周',
        RegularCycle.monthly => '每月${r.dayOfMonth}号',
      };
}

class _CreateRegularSheet extends ConsumerStatefulWidget {
  const _CreateRegularSheet();
  @override
  ConsumerState<_CreateRegularSheet> createState() => _CreateRegularSheetState();
}

class _CreateRegularSheetState extends ConsumerState<_CreateRegularSheet> {
  final _title = TextEditingController(text: '房租');
  final _amount = TextEditingController(text: '1500');
  RegularCycle _cycle = RegularCycle.monthly;
  int _day = 1;
  BillCategory _category = BillCategory.hotel;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('新建定期账单', style: text.headlineSmall),
        const SizedBox(height: 12),
        _CalendarTear(),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final c in RegularCycle.values)
              Expanded(
                child: _cycleChip(c),
              ),
          ],
        ),
        if (_cycle == RegularCycle.monthly) ...[
          const SizedBox(height: 10),
          Text('每月几号？', style: text.bodySmall),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: List.generate(31, (i) {
                final d = i + 1;
                final on = d == _day;
                return GestureDetector(
                  onTap: () => setState(() => _day = d),
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? AAColors.lemon : AAColors.cardWhite,
                      shape: BoxShape.circle,
                      border: Border.all(color: on ? AAColors.coral : AAColors.ink, width: 1.5),
                    ),
                    child: Text('$d', style: const TextStyle(fontSize: 13)),
                  ),
                );
              }),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Text('标题', style: text.bodyMedium),
        HandTextField(controller: _title),
        const SizedBox(height: 10),
        Text('金额（元）', style: text.bodyMedium),
        HandTextField(controller: _amount, keyboardType: TextInputType.number),
        const SizedBox(height: 12),
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
        const SizedBox(height: 16),
        DoodleButton(
          label: '开启自动生成',
          expand: true,
          onPressed: _open,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _cycleChip(RegularCycle c) {
    final on = _cycle == c;
    final label = switch (c) {
      RegularCycle.weekly => '每周',
      RegularCycle.biweekly => '每两周',
      RegularCycle.monthly => '每月',
    };
    return GestureDetector(
      onTap: () => setState(() => _cycle = c),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AAColors.mint.withValues(alpha: 0.3) : AAColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? AAColors.mint : AAColors.ink, width: 1.5),
        ),
        child: Text(label, style: const TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 13, color: AAColors.ink)),
      ),
    );
  }

  void _open() {
    final groups = ref.read(groupsProvider);
    final groupId = groups.isEmpty ? '' : groups.first.id;
    final groupName = groups.isEmpty ? '' : groups.first.name;
    final cents = (double.tryParse(_amount.text) ?? 0) * 100;
    Navigator.of(context).pop(_RegularDraft(
      title: _title.text.trim().isEmpty ? '定期账单' : _title.text.trim(),
      groupId: groupId,
      groupName: groupName,
      amountCents: cents.round(),
      category: _category,
      cycle: _cycle,
      dayOfMonth: _day,
    ));
  }
}

class _RegularDraft {
  const _RegularDraft({
    required this.title,
    required this.groupId,
    required this.groupName,
    required this.amountCents,
    required this.category,
    required this.cycle,
    required this.dayOfMonth,
  });
  final String title;
  final String groupId;
  final String groupName;
  final int amountCents;
  final BillCategory category;
  final RegularCycle cycle;
  final int dayOfMonth;
}

class _CalendarTear extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AAColors.cardWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AAColors.ink, width: 1.5),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month, color: AAColors.ink, size: 30),
          SizedBox(width: 8),
          Text('选个周期，到点自动生成', style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 14, color: AAColors.ink)),
        ],
      ),
    );
  }
}
