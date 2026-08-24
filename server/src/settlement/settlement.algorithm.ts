/**
 * 最少转账笔数结算算法（纯函数，无任何框架依赖）
 *
 * 背景：群组内所有未结清账单的参与者应摊金额已知，
 * 求一组转账 (from, to, amount)，使所有成员账户清零且转账笔数最少。
 *
 * 方法：按成员净值（net = 垫付额 - 应摊额）贪心配对（双指针）：
 *   债主（net > 0）按净值降序，债户（net < 0）按债务额降序，
 *   两指针逐一配对，每笔转账金额 = min(|债户|, 债主)，金额取分（int），
 *   每笔至少清零一方 → 在"逐步清零"的贪心框架下笔数最少。
 *
 * 复杂度 O(n log n)，n = 群成员数（常见 ≤ 20）。
 * 全链路使用整数分，无浮点误差。
 */

/** 一笔转账 */
export interface SettlementTransfer {
  fromUserId: string;
  toUserId: string;
  amountCents: number;
}

/**
 * 由账单责任汇总出成员净值。
 *
 * @param bills 每笔账单：payerId（垫付人）+ amountCents（金额，分）+ liabilities[]
 *   liabilities：参与人 userId + shareCents（应摊，分；免摊者 shareCents=0 或不出现在列表）
 *   liabilities[i].paid（可选）：该参与人已向垫付人结清自己的份额 → 不再计入净额，
 *   同时垫付人的应收也相应扣减（避免"幽灵转账"：已付的人又被算成欠款）。
 * @returns map: userId -> net["分"]（正=应收，负=应付）
 *
 * net[u] = Σ(payerId == u ? (amount - 已付份额合计) : 0) - Σ(未付 shareCents)
 */
export function summarizeBalances(
  bills: Array<{
    payerId: string;
    amountCents: number;
    liabilities: Array<{ userId: string; shareCents: number; paid?: boolean }>;
  }>,
): Map<string, number> {
  const net = new Map<string, number>();
  const add = (userId: string, delta: number) => {
    net.set(userId, (net.get(userId) ?? 0) + delta);
  };
  for (const bill of bills) {
    // 已付份额合计：垫付人实际已收回的钱，从应收中扣减
    const paidShareSum = bill.liabilities.reduce(
      (sum, l) => sum + (l.paid ? l.shareCents : 0),
      0,
    );
    add(bill.payerId, bill.amountCents - paidShareSum);
    for (const l of bill.liabilities) {
      if (l.paid) continue; // 已付份额不再参与结算
      if (l.shareCents === 0) continue; // 免摊
      add(l.userId, -l.shareCents);
    }
  }
  return net;
}

/**
 * 由净值求最少转账方案。
 *
 * @param net userId -> 净值（分），正=应收，负=应付
 * @param epsilon 忽略阈值（分），默认 0（金额为整数分时无浮点误差）
 * @returns 转账列表；该组输入应满足 Σnet = 0（服务端在事务内保证）
 */
export function computeSettlement(
  net: Map<string, number>,
  epsilon = 0,
): SettlementTransfer[] {
  // 1. 取净值显著者，分别归入债主（降序）与债户（债务额降序）
  const creditors = new Map<string, number>();
  const debtors = new Map<string, number>();
  for (const [userId, value] of net) {
    if (Math.abs(value) <= epsilon) continue;
    if (value > 0) creditors.set(userId, value);
    else debtors.set(userId, -value);
  }
  const sortedCreditors = [...creditors.entries()].sort((a, b) => b[1] - a[1]);
  const sortedDebtors = [...debtors.entries()].sort((a, b) => b[1] - a[1]);

  // 2. 双指针贪心配对
  const transfers: SettlementTransfer[] = [];
  let i = 0; // 债户指针
  let j = 0; // 债主指针
  while (i < sortedDebtors.length && j < sortedCreditors.length) {
    const [debtorId, debt] = sortedDebtors[i];
    const [creditorId, credit] = sortedCreditors[j];
    const amount = Math.min(debt, credit);
    if (amount > 0) {
      transfers.push({
        fromUserId: debtorId,
        toUserId: creditorId,
        amountCents: amount,
      });
    }
    // 更新双方剩余（同一用户不可能同时是债主与债户，净值取唯一符号）
    sortedDebtors[i] = [debtorId, debt - amount];
    sortedCreditors[j] = [creditorId, credit - amount];
    if (sortedDebtors[i][1] <= 0) i++;
    if (sortedCreditors[j][1] <= 0) j++;
  }
  return transfers;
}
