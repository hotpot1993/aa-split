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

/// P60 全局搜索 —— 对齐 docs/ui-demo/index.html
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _q = TextEditingController();
  _ResultTab _tab = _ResultTab.bills;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim();
    final groups = ref.watch(groupsProvider).value ?? const <Group>[];
    final bills = ref.watch(billsProvider).value ?? const <Bill>[];
    final members = (ref.watch(groupMembersProvider).value ?? {}).values.expand((e) => e).toList();

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

    final hits = switch (_tab) {
      _ResultTab.groups => groupHits,
      _ResultTab.bills => billHits,
      _ResultTab.members => memberHits,
    };

    return AaScaffold(
      appBar: AaAppBar(title: '搜索', headIcon: 'assets/icons/search.png', iconImage: 'assets/icons/sparkle.png'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 搜索行（Demo：.line 底部虚线 + 🔍 + 关键词）
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
            child: Row(
              children: [
                Text('🔍', style: TextStyle(fontSize: 15)),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _q,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink),
                    decoration: InputDecoration(
                      hintText: '输入想找的账',
                      hintStyle: TextStyle(
                          fontFamily: AAFonts.title, fontSize: 15, color: AAColors.inkSoft),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // 类型 chips
          Row(
            children: [
              _chip('群组', _ResultTab.groups, groupHits.length),
              SizedBox(width: 8),
              _chip('账单', _ResultTab.bills, billHits.length),
              SizedBox(width: 8),
              _chip('成员', _ResultTab.members, memberHits.length),
            ],
          ),
          SizedBox(height: 6),
          if (q.isEmpty)
            EmptyState(
              title: '翻来覆去没找到…换个关键词？',
              subtitle: '团团找得眼睛都大了',
              tag: 'P60 搜索',
              artImage: 'assets/icons/sad.png',
              buttonLabel: '清空关键词',
              onButtonTap: () => setState(() => _q.clear()),
            )
          else ...[
            SectionTitle('结果 ${hits.length} 条', emoji: '🍃'),
            if (hits.isEmpty)
              EmptyState(
                title: '翻来覆去没找到…换个关键词？',
                subtitle: '团团找得眼睛都大了',
                tag: 'P60 搜索',
                artImage: 'assets/icons/sad.png',
                buttonLabel: '清空关键词',
                onButtonTap: () => setState(() => _q.clear()),
              )
            else
              ...switch (_tab) {
                _ResultTab.groups => [
                    for (final g in groupHits) _groupCard(g, q),
                  ],
                _ResultTab.bills => [
                    for (final b in billHits) _billCard(b, q),
                  ],
                _ResultTab.members => [
                    for (final m in memberHits) _memberCard(m, q),
                  ],
              },
          ],
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _chip(String label, _ResultTab tab, int count) {
    final on = _tab == tab;
    return GestureDetector(
      onTap: () => setState(() => _tab = tab),
      child: HandTag(
        '$label$count',
        selected: on,
        fontSize: 12,
      ),
    );
  }

  Widget _billCard(Bill b, String q) {
    return PaperCard(
      onTap: () => context.push('/bills/${b.id}'),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CategoryIcon(category: b.category, size: 44),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HighlightPartText(b.title, parts: [q],
                    style:
                        TextStyle(fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                SizedBox(height: 2),
                Text(
                  '${b.groupName} · ${Fmt.yuan(b.amountCents, trimZero: true)} · ${SplitText.label(b.splitType)}',
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          StampBadge(
            text: b.fullySettled ? '已结清' : '待结算',
            color: b.fullySettled ? AASemantic.stampDone : AASemantic.stampMoney,
          ),
        ],
      ),
    );
  }

  Widget _groupCard(Group g, String q) {
    return PaperCard(
      onTap: () => context.push('/groups/${g.id}'),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SketchAvatar(emoji: g.avatar, size: 44, background: Color(0xFFEDF7EE)),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HighlightPartText(g.name, parts: [q],
                    style:
                        TextStyle(fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                SizedBox(height: 2),
                Text('群组 · ${g.memberCount}个小伙伴 · ${g.pendingBillCount}笔待清',
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          SizedBox(width: 8),
          StampBadge(
            text: g.pendingBillCount > 0 ? '${g.pendingBillCount}笔待清' : '✅已清',
            color: g.pendingBillCount > 0 ? AASemantic.stampMoney : AASemantic.stampDone,
          ),
        ],
      ),
    );
  }

  Widget _memberCard(GroupMember m, String q) {
    return PaperCard(
      onTap: null,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SketchAvatar(emoji: m.avatarUrl, size: 44, name: m.nickname),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HighlightPartText(m.nickname, parts: [q],
                    style:
                        TextStyle(fontFamily: AAFonts.title, fontSize: 15, color: AAColors.ink)),
                SizedBox(height: 2),
                Text('@${m.accountName}',
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
