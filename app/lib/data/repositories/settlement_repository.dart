import 'dart:math';

import '../../core/api/api_client.dart';
import '../../core/api/codec.dart';
import '../../core/config.dart';
import '../../models/bill.dart';
import '../../models/transfer.dart';
import '../mock/mock_store.dart';

/// 结算仓库。
/// Demo 模式本地按技术方案 §5 贪心计算（与服务端算法一致）；
/// 真实模式调用 GET /groups/:id/settlement（服务端 summarizeBalances +
/// computeSettlement），transfer 的姓名用成员表补充。
class SettlementRepository {
  SettlementRepository();

  /// 最少转账笔数方案（技术方案 §5 贪心算法）
  Future<SettlementPlan> compute(String groupId) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final members = store.activeMembersOf(groupId);
      final net = _net(store, groupId, members.map((m) => m.userId).toSet());

      final creditors = <String>[
        for (final e in net.entries)
          if (e.value > 0) e.key
      ]..sort((a, b) => net[b]!.compareTo(net[a]!));
      final debtors = <String>[
        for (final e in net.entries)
          if (e.value < 0) e.key
      ]..sort((a, b) => net[a]!.compareTo(net[b]!)); // 最负在前

      final transfers = <Transfer>[];
      var i = 0, j = 0;
      while (i < debtors.length && j < creditors.length) {
        final d = debtors[i];
        final c = creditors[j];
        var dv = net[d]!;
        var cv = net[c]!;
        final t = min(-dv, cv);
        if (t > 0) {
          transfers.add(_transfer(store, groupId, d, c, t, store.billsForGroup(groupId)));
        }
        cv -= t;
        dv += t;
        net[d] = dv;
        net[c] = cv;
        if (dv >= 0) i++;
        if (cv <= 0) j++;
      }

      transfers.sort((a, b) => b.amountCents.compareTo(a.amountCents));
      return SettlementPlan(transferCount: transfers.length, transfers: transfers);
    }

    final res = await ApiClient.instance.get('/groups/$groupId/settlement');
    final j = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
    final members = await _memberNames(groupId);
    final raw = (j['transfers'] is List) ? j['transfers'] as List : const [];
    final transfers = raw.map((e) {
      final t = parseTransfer(e);
      return Transfer(
        fromUserId: t.fromUserId,
        fromName: members[t.fromUserId] ?? t.fromUserId,
        toUserId: t.toUserId,
        toName: members[t.toUserId] ?? t.toUserId,
        amountCents: t.amountCents,
        billIds: t.billIds,
      );
    }).toList()
      ..sort((a, b) => b.amountCents.compareTo(a.amountCents));
    return SettlementPlan(
      transferCount: (j['transferCount'] as num?)?.toInt() ?? transfers.length,
      transfers: transfers,
    );
  }

  /// 逐笔结算方案（P25 切到"逐笔结算"模式）
  Future<List<Transfer>> perBill(String groupId) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final out = <Transfer>[];
      for (final b in store.billsForGroup(groupId)) {
        if (b.fullySettled) continue;
        for (final p in b.participants) {
          if (p.exempt || p.userId == b.payerId || p.paid) continue;
          if (p.shareAmountCents <= 0) continue;
          out.add(Transfer(
            fromUserId: p.userId,
            fromName: p.nickname,
            toUserId: b.payerId,
            toName: b.payerName,
            amountCents: p.shareAmountCents,
            billIds: [b.id],
          ));
        }
      }
      return out;
    }

    final res = await ApiClient.instance.get('/groups/$groupId/bills',
        query: {'page': 1, 'pageSize': 100});
    final j = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
    final members = await _memberNames(groupId);
    final list = (j['list'] is List) ? j['list'] as List : const [];
    final out = <Transfer>[];
    for (final e in list) {
      final b = parseBill(e);
      if (b.fullySettled) continue;
      for (final p in b.participants) {
        if (p.exempt || p.userId == b.payerId || p.paid) continue;
        if (p.shareAmountCents <= 0) continue;
        out.add(Transfer(
          fromUserId: p.userId,
          fromName: members[p.userId] ?? p.nickname,
          toUserId: b.payerId,
          toName: members[b.payerId] ?? b.payerName,
          amountCents: p.shareAmountCents,
          billIds: [b.id],
        ));
      }
    }
    return out;
  }

  Map<String, int> _net(MockStore store, String groupId, Set<String> memberIds) {
    final net = <String, int>{};
    for (final id in memberIds) {
      net[id] = 0;
    }
    for (final b in store.billsForGroup(groupId)) {
      if (b.fullySettled) continue;
      final payer = b.payerId;
      var credit = 0;
      for (final p in b.participants) {
        if (p.exempt || p.userId == payer || p.paid) continue;
        net[p.userId] = (net[p.userId] ?? 0) - p.shareAmountCents;
        credit += p.shareAmountCents;
      }
      net[payer] = (net[payer] ?? 0) + credit;
    }
    return net;
  }

  Transfer _transfer(
    MockStore store,
    String groupId,
    String from,
    String to,
    int amount,
    List<Bill> bills,
  ) {
    final fromMember = store.memberOf(groupId, from);
    final toMember = store.memberOf(groupId, to);
    // 关联未结账单（简化：取未结清账单中含该付款关系的，用于"对应账单"展示）
    final billIds = <String>[];
    for (final b in bills) {
      if (b.fullySettled) continue;
      final relatesTo = b.participants.any((p) =>
          !p.exempt && !p.paid && (p.userId == from || p.userId == to));
      if (relatesTo) billIds.add(b.id);
    }
    return Transfer(
      fromUserId: from,
      fromName: fromMember?.nickname ?? from,
      toUserId: to,
      toName: toMember?.nickname ?? to,
      amountCents: amount,
      billIds: billIds,
    );
  }

  Future<Map<String, String>> _memberNames(String groupId) async {
    try {
      final res = await ApiClient.instance.get('/groups/$groupId');
      final j = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
      final raw = (j['members'] is List) ? j['members'] as List : const [];
      return {
        for (final e in raw)
          parseGroupMember(e).userId: parseGroupMember(e).nickname,
      };
    } catch (_) {
      return const {};
    }
  }
}
