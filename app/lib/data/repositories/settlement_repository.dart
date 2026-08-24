import 'dart:math';

import '../../core/config.dart';
import '../../models/bill.dart';
import '../../models/transfer.dart';
import '../mock/mock_store.dart';

/// 结算仓库（Demo 模式走 MockStore）
///
/// 非 Demo 模式：应改为 async 并调用 ApiClient 的 `/groups/:id/settlement`
/// （技术方案 §4.4 / §5 最小化转账算法）。
class SettlementRepository {
  SettlementRepository();

  /// 最少转账笔数方案（技术方案 §5 贪心算法）
  SettlementPlan compute(String groupId) {
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
    throw UnsupportedError('useMock=false：compute 需 async + ApiClient');
  }

  /// 逐笔结算方案（P25 切到"逐笔结算"模式）
  List<Transfer> perBill(String groupId) {
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
    throw UnsupportedError('useMock=false：perBill 需 async + ApiClient');
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
}
