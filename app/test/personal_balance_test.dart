// 回归：个人净额（P11 我的净额）/ 垫付人识别 ——
// 复现线上数据：一边 36 元 A 垫付、一边 58 元 B 垫付（均分 2 人）。
// 期望 A 应收 18 / 应付 29 → 净额 -11；B 应收 29 / 应付 18 → 净额 +11。
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/core/api/codec.dart';
import 'package:aa_split_app/core/utils/balance.dart';
import 'package:aa_split_app/models/bill.dart';
import 'package:aa_split_app/models/bill_participant.dart';

void main() {
  const a = 'u_hotpot';
  const b = 'u_mi13';

  Bill bill({
    required String id,
    required int amountCents,
    required String payerId,
    required BillParticipant pa,
    required BillParticipant pb,
  }) =>
      Bill(
        id: id,
        groupId: 'g1',
        groupName: '测试组',
        title: id,
        amountCents: amountCents,
        billDate: DateTime(2026, 8, 25),
        category: BillCategory.food,
        payerId: payerId,
        payerName: payerId == a ? 'HotPot' : '小米13',
        participants: [pa, pb],
        splitType: SplitType.even,
        settleStatus: BillSettleStatus.partial,
      );

  final bill1 = bill(
    id: 'b1',
    amountCents: 3600,
    payerId: a,
    pa: const BillParticipant(
        userId: a, nickname: 'HotPot', shareAmountCents: 1800, paid: true),
    pb: const BillParticipant(
        userId: b, nickname: '小米13', shareAmountCents: 1800, paid: false),
  );
  final bill2 = bill(
    id: 'b2',
    amountCents: 5800,
    payerId: b,
    pa: const BillParticipant(
        userId: a, nickname: 'HotPot', shareAmountCents: 2900, paid: false),
    pb: const BillParticipant(
        userId: b, nickname: '小米13', shareAmountCents: 2900, paid: true),
  );

  test('personalBalance：A 应收 18 / 应付 29 → 净额 -11', () {
    final r = personalBalance([bill1, bill2], a);
    expect(r.receivableCents, 1800);
    expect(r.payableCents, 2900);
    expect(r.netCents, -1100);
  });

  test('personalBalance：B 应收 29 / 应付 18 → 净额 +11', () {
    final r = personalBalance([bill1, bill2], b);
    expect(r.receivableCents, 2900);
    expect(r.payableCents, 1800);
    expect(r.netCents, 1100);
  });

  test('已结清账单不参与净额（结清后两不相欠）', () {
    final settled = Bill(
      id: 'b3',
      groupId: 'g1',
      groupName: '测试组',
      title: '已结清的那笔',
      amountCents: 3600,
      billDate: DateTime(2026, 8, 25),
      category: BillCategory.food,
      payerId: a,
      payerName: 'HotPot',
      participants: const [
        BillParticipant(
            userId: a, nickname: 'HotPot', shareAmountCents: 1800, paid: true),
        BillParticipant(
            userId: b, nickname: '小米13', shareAmountCents: 1800, paid: true),
      ],
      splitType: SplitType.even,
      settleStatus: BillSettleStatus.settled,
    );
    final r = personalBalance([settled, bill2], b);
    expect(r.receivableCents, 2900);
    expect(r.payableCents, 0);
  });

  test('parseBill：老服务端缺顶层 payerId 时从嵌套 payer.id 兜底', () {
    final bill = parseBill({
      'id': 'b1',
      'groupId': 'g1',
      'title': '36元那笔',
      'amountCents': 3600,
      'billDate': '2026-08-25',
      'category': 'food',
      'splitType': 'even',
      'settleStatus': 'partial',
      // 老版本 mapBill 只有 payer 对象，没有顶层 payerId
      'payer': {'id': a, 'nickname': 'HotPot'},
      'participants': [
        {'userId': a, 'shareAmountCents': 1800, 'paid': true},
        {'userId': b, 'shareAmountCents': 1800, 'paid': false},
      ],
    });
    expect(bill.payerId, a);
  });

  test('parseBill：新服务端带顶层 payerId 时优先使用', () {
    final bill = parseBill({
      'id': 'b2',
      'groupId': 'g1',
      'title': '58元那笔',
      'amountCents': 5800,
      'billDate': '2026-08-25',
      'category': 'food',
      'splitType': 'even',
      'settleStatus': 'partial',
      'payer': {'id': b, 'nickname': '小米13'},
      'payerId': b,
      'participants': [
        {'userId': a, 'shareAmountCents': 2900, 'paid': false},
        {'userId': b, 'shareAmountCents': 2900, 'paid': true},
      ],
    });
    expect(bill.payerId, b);
  });
}
