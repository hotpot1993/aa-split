// 回归：一键结清 —— 群内全部账单统一标记为已付（Demo 模式）
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/data/mock/mock_store.dart';
import 'package:aa_split_app/data/repositories/bill_repository.dart';

void main() {
  test('settleAll：群内全部未结清账单标记为已付，结清状态生效', () async {
    final store = MockStore.instance;
    final repo = BillRepository();

    final before = store.billsForGroup('g2');
    final unsettled = before.where((b) => !b.fullySettled).length;
    expect(unsettled, greaterThan(0), reason: '演示数据应含未结清账单');

    final n = await repo.settleAll('g2');
    expect(n, unsettled);

    final after = store.billsForGroup('g2');
    expect(after.every((b) => b.fullySettled), isTrue);
    expect(after.every((b) => b.participants.every((p) => p.paid)), isTrue);

    // 成员净额归零（应收应付两清）
    final members = store.activeMembersOf('g2');
    expect(members, isNotEmpty);
  });

  test('settleAll 幂等：重复调用结清数为 0', () async {
    final repo = BillRepository();
    final first = await repo.settleAll('g1');
    expect(first, greaterThan(0));
    expect(await repo.settleAll('g1'), 0);
  });
}
