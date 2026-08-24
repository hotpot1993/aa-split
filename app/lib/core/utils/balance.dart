import '../../models/bill.dart';

/// 某用户在所有账单中的个人收支汇总（P11 净额卡）
class PersonalBalance {
  const PersonalBalance({this.receivableCents = 0, this.payableCents = 0});

  final int receivableCents;
  final int payableCents;

  int get netCents => receivableCents - payableCents;
}

/// 计算某用户（myId）的个人应收/应付
PersonalBalance personalBalance(List<Bill> bills, String myId) {
  var receivable = 0;
  var payable = 0;
  for (final b in bills) {
    if (b.fullySettled) continue;
    if (b.payerId == myId) {
      for (final p in b.participants) {
        if (p.exempt || p.userId == myId || p.paid) continue;
        receivable += p.shareAmountCents;
      }
    }
    if (b.payerId != myId) {
      for (final p in b.participants) {
        if (p.userId == myId && !p.exempt && !p.paid) {
          payable += p.shareAmountCents;
        }
      }
    }
  }
  return PersonalBalance(receivableCents: receivable, payableCents: payable);
}
