import '../../models/bill.dart';
import '../../models/group_member.dart';

/// 单行分摊结果
class ShareLine {
  ShareLine({required this.userId, required this.name, this.avatarUrl = '🐼', required this.amountCents, this.exempt = false});
  final String userId;
  final String name;
  final String avatarUrl;
  int amountCents;
  bool exempt;
}

/// 分摊结果
class SplitResult {
  const SplitResult({required this.type, required this.lines, required this.summary});
  final SplitType type;
  final List<ShareLine> lines;
  final String summary;
  int get totalCents => lines.fold(0, (s, e) => s + e.amountCents);
}

/// 均摊：把 amountCents 均匀分给 nonExempt
List<ShareLine> computeEven(int amountCents, List<GroupMember> members, Set<String> exemptIds) {
  final active = members.where((m) => !exemptIds.contains(m.userId)).toList();
  final n = active.isEmpty ? 1 : active.length;
  final base = amountCents ~/ n;
  var rem = amountCents - base * n;
  return members.map((m) {
    final exempt = exemptIds.contains(m.userId);
    var amt = exempt ? 0 : base;
    if (!exempt && rem > 0) {
      amt += rem;
      rem--;
    }
    return ShareLine(userId: m.userId, name: m.nickname, avatarUrl: m.avatarUrl, amountCents: amt, exempt: exempt);
  }).toList();
}

/// 按比例：给出 percent，按总量换算（此处以 percentage 0-100）
List<ShareLine> computeRatio(int amountCents, List<GroupMember> members, Map<String, double> percent, Set<String> exemptIds) {
  final totalPct = members
      .where((m) => !exemptIds.contains(m.userId))
      .fold<double>(0, (s, m) => s + (percent[m.userId] ?? 0));
  var used = 0;
  final out = members.map((m) {
    final exempt = exemptIds.contains(m.userId);
    var amt = 0;
    if (!exempt && totalPct > 0) {
      amt = (amountCents * (percent[m.userId] ?? 0) / totalPct).round();
      used += amt;
    }
    return ShareLine(userId: m.userId, name: m.nickname, avatarUrl: m.avatarUrl, amountCents: amt, exempt: exempt);
  }).toList();
  // 修正舍入差
  final diff = amountCents - used;
  if (diff != 0) {
    for (var i = 0; i < out.length; i++) {
      if (!out[i].exempt && (out[i].amountCents + diff) >= 0) {
        out[i].amountCents += diff;
        break;
      }
    }
  }
  return out;
}

/// 免分摊：基于均摊，把豁免者的份额平摊给其余人
List<ShareLine> applyExempt(int amountCents, List<GroupMember> members, Set<String> exemptIds) {
  final active = members.where((m) => !exemptIds.contains(m.userId)).toList();
  if (active.isEmpty) {
    return members
        .map((m) => ShareLine(userId: m.userId, name: m.nickname, avatarUrl: m.avatarUrl, amountCents: 0, exempt: true))
        .toList();
  }
  return computeEven(amountCents, members, exemptIds);
}

/// 生成平均分摊的默认百分比（用于按比例 UI 展示）
Map<String, double> defaultPercent(List<GroupMember> members) {
  final n = members.isEmpty ? 1 : members.length;
  final p = 100 / n;
  return {for (final m in members) m.userId: p};
}
