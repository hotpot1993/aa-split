import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../models/group.dart';
import '../../models/group_member.dart';
import '../../providers/data_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';

enum _ResultTab { groups, bills, members }

/// P60 全局搜索页
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _q = TextEditingController();
  _ResultTab _tab = _ResultTab.groups;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim();
    final groups = ref.watch(groupsProvider);
    final bills = ref.watch(billsProvider);
    final members = ref.watch(groupMembersProvider).values.expand((e) => e).toList();

    final groupHits = q.isEmpty ? <Group>[] : groups.where((g) => g.name.contains(q)).toList();
    final billHits = q.isEmpty
        ? <Bill>[]
        : bills
            .where((b) =>
                b.title.contains(q) ||
                Cat.label(b.category).contains(q) ||
                b.groupName.contains(q))
            .toList();
    final memberHits = q.isEmpty
        ? <GroupMember>[]
        : members.where((m) => m.nickname.contains(q) || m.accountName.contains(q)).toList();

    final text = Theme.of(context).textTheme;
    return AaScaffold(
      appBar: AppBar(
        title: TextField(
          controller: _q,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          style: text.titleMedium,
          decoration: const InputDecoration(
            hintText: '输入想找的账',
            hintStyle: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 16),
            border: InputBorder.none,
          ),
        ),
        actions: const [Icon(Icons.search, color: AAColors.inkSoft, size: 24)],
      ),
      body: Column(
        children: [
          Row(
            children: [
              _tabButton('群组', _ResultTab.groups, groupHits.length),
              _tabButton('账单', _ResultTab.bills, billHits.length),
              _tabButton('成员', _ResultTab.members, memberHits.length),
            ],
          ),
          Expanded(child: _results(q, groupHits, billHits, memberHits)),
        ],
      ),
    );
  }

  Widget _tabButton(String label, _ResultTab tab, int count) {
    final on = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = tab),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? AAColors.lemon.withValues(alpha: 0.5) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$label$count',
              style: TextStyle(fontFamily: 'ZCOOLKuaiLe', fontSize: 13, color: on ? AAColors.coral : AAColors.inkSoft)),
        ),
      ),
    );
  }

  Widget _results(String q, List<Group> groups, List<Bill> bills, List<GroupMember> members) {
    final text = Theme.of(context).textTheme;
    if (q.isEmpty) {
      return const Center(
        child: EmptyState(
          title: '搜一群、一笔账、一个人',
          subtitle: '请输入想找的关键词',
        ),
      );
    }
    final empty = EmptyState(
      title: '翻来覆去没找到…换个关键词？',
      subtitle: '试试群名、成员名或账单标题',
    );

    switch (_tab) {
      case _ResultTab.groups:
        if (groups.isEmpty) return _withFill(empty);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: groups
              .map((g) => GestureDetector(
                    onTap: () => context.push('/groups/${g.id}'),
                    child: Row(
                      children: [
                        Text(g.avatar, style: const TextStyle(fontSize: 26)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: HighlightPartText(
                            text: g.name,
                            parts: [q],
                            style: text.titleMedium,
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AAColors.inkSoft),
                      ],
                    ),
                  ))
              .toList(),
        );
      case _ResultTab.bills:
        if (bills.isEmpty) return _withFill(empty);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: bills
              .map((b) => GestureDetector(
                    onTap: () => context.push('/bills/${b.id}'),
                    child: Row(
                      children: [
                        CategoryIcon(category: b.category, size: 38),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              HighlightPartText(text: b.title, parts: [q], style: text.titleMedium),
                              Text('${b.groupName} · ${Fmt.dateShort(b.billDate)}', style: text.bodySmall),
                            ],
                          ),
                        ),
                        HandAmount(amountCents: -b.amountCents, color: AAColors.ink, size: 18),
                      ],
                    ),
                  ))
              .toList(),
        );
      case _ResultTab.members:
        if (members.isEmpty) return _withFill(empty);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: members
              .map((m) => Row(
                    children: [
                      SketchAvatar(emoji: m.avatarUrl, size: 38, name: m.nickname),
                      const SizedBox(width: 10),
                      HighlightPartText(text: m.nickname, parts: [q], style: text.titleMedium),
                    ],
                  ))
              .toList(),
        );
    }
  }

  Widget _withFill(Widget child) => Center(child: child);
}
