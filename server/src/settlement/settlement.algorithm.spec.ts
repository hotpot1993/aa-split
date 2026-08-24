import { computeSettlement, summarizeBalances, SettlementTransfer } from './settlement.algorithm';

describe('settlement.algorithm', () => {
  /** 校验零和：Σnet = 0 且转账后所有人清零、金额守恒
   *  net 约定：正=应收（别人欠我），负=应付。债务人转账后债务减少（+），
   *  债权人收到钱后应收减少（-）。 */
  const assertValid = (
    net: Map<string, number>,
    transfers: SettlementTransfer[],
  ) => {
    const balance = new Map<string, number>(net);
    for (const t of transfers) {
      expect(t.amountCents).toBeGreaterThan(0);
      balance.set(t.fromUserId, (balance.get(t.fromUserId) ?? 0) + t.amountCents);
      balance.set(t.toUserId, (balance.get(t.toUserId) ?? 0) - t.amountCents);
    }
    for (const [, v] of balance) {
      expect(v).toBe(0);
    }
  };

  describe('summarizeBalances', () => {
    it('三人都摊一笔由 A 垫付的账单', () => {
      const net = summarizeBalances([
        {
          payerId: 'A',
          amountCents: 10000,
          liabilities: [
            { userId: 'A', shareCents: 3333 },
            { userId: 'B', shareCents: 3333 },
            { userId: 'C', shareCents: 3334 },
          ],
        },
      ]);
      expect(net.get('A')).toBe(10000 - 3333); // 6667 应收
      expect(net.get('B')).toBe(-3333);
      expect(net.get('C')).toBe(-3334);
    });

    it('多笔账单累加，payer 自身份额互相抵消', () => {
      const net = summarizeBalances([
        {
          payerId: 'A',
          amountCents: 12000,
          liabilities: [
            { userId: 'A', shareCents: 6000 },
            { userId: 'B', shareCents: 6000 },
          ],
        },
        {
          payerId: 'B',
          amountCents: 8000,
          liabilities: [
            { userId: 'A', shareCents: 4000 },
            { userId: 'B', shareCents: 4000 },
          ],
        },
      ]);
      expect(net.get('A')).toBe(12000 - 6000 - 4000); // 2000
      expect(net.get('B')).toBe(8000 - 6000 - 4000); // -2000
    });

    it('免摊者不计份额', () => {
      const net = summarizeBalances([
        {
          payerId: 'A',
          amountCents: 10000,
          liabilities: [
            { userId: 'A', shareCents: 10000 }, // 请客，全部自担
          ],
        },
      ]);
      expect(net.get('A')).toBe(0);
      expect(net.get('B')).toBeUndefined();
    });

    it('部分已付：已付者不再产生转账（无幽灵转账）', () => {
      // A 垫付 10000，B、C 各摊 3333/3334；B 已付，C 未付
      const net = summarizeBalances([
        {
          payerId: 'A',
          amountCents: 10000,
          liabilities: [
            { userId: 'A', shareCents: 3333, paid: true },
            { userId: 'B', shareCents: 3333, paid: true },
            { userId: 'C', shareCents: 3334, paid: false },
          ],
        },
      ]);
      // A 应收 = 10000 - 3333(B已付) - 3333(自己) = 3334，只来自 C
      expect(net.get('A')).toBe(3334);
      // B 已付清：不出现（视为净额 0）
      expect(net.get('B')).toBeUndefined();
      expect(net.get('C')).toBe(-3334);
      const transfers = computeSettlement(net);
      expect(transfers).toEqual([
        { fromUserId: 'C', toUserId: 'A', amountCents: 3334 },
      ]);
      assertValid(net, transfers);
    });

    it('部分已付只影响垫付人应收（混合多账单零和）', () => {
      const net = summarizeBalances([
        {
          payerId: 'A',
          amountCents: 12000,
          liabilities: [
            { userId: 'A', shareCents: 6000, paid: true },
            { userId: 'B', shareCents: 6000, paid: false },
          ],
        },
        {
          payerId: 'B',
          amountCents: 8000,
          liabilities: [
            { userId: 'A', shareCents: 4000, paid: false },
            { userId: 'B', shareCents: 4000, paid: true },
          ],
        },
      ]);
      // 汇总：Σnet = (12000-6000-6000?) 兜底校验零和
      let sum = 0;
      for (const v of net.values()) sum += v;
      expect(sum).toBe(0);
      expect(net.get('A')).toBe(12000 - 6000 - 4000); // 2000
      expect(net.get('B')).toBe(8000 - 6000 - 4000); // -2000
      const transfers = computeSettlement(net);
      expect(transfers).toEqual([
        { fromUserId: 'B', toUserId: 'A', amountCents: 2000 },
      ]);
    });
  });

  describe('computeSettlement', () => {
    it('净值为空 → 空方案', () => {
      expect(computeSettlement(new Map())).toEqual([]);
      expect(
        computeSettlement(new Map([['A', 0], ['B', 0]])),
      ).toEqual([]);
    });

    it('一笔三方账单：两笔转账，B、C 向 A 付款', () => {
      const net = summarizeBalances([
        {
          payerId: 'A',
          amountCents: 10000,
          liabilities: [
            { userId: 'A', shareCents: 3333 },
            { userId: 'B', shareCents: 3333 },
            { userId: 'C', shareCents: 3334 },
          ],
        },
      ]);
      const transfers = computeSettlement(net);
      expect(transfers).toHaveLength(2);
      expect(transfers).toEqual(
        expect.arrayContaining([
          { fromUserId: 'B', toUserId: 'A', amountCents: 3333 },
          { fromUserId: 'C', toUserId: 'A', amountCents: 3334 },
        ]),
      );
      assertValid(net, transfers);
    });

    it('链式债务：B 单笔一千还 C，A 单笔一百还 C', () => {
      const net = new Map([
        ['A', -100],
        ['B', -200],
        ['C', 300],
      ]);
      const transfers = computeSettlement(net);
      expect(transfers).toHaveLength(2);
      expect(transfers).toEqual(
        expect.arrayContaining([
          { fromUserId: 'B', toUserId: 'C', amountCents: 200 },
          { fromUserId: 'A', toUserId: 'C', amountCents: 100 },
        ]),
      );
      assertValid(net, transfers);
    });

    it('多债户合并还一人的两笔转账', () => {
      const net = new Map([
        ['A', -500],
        ['B', -500],
        ['C', 1000],
      ]);
      const transfers = computeSettlement(net);
      expect(transfers).toHaveLength(2);
      expect(transfers[0].fromUserId).toBe('A');
      expect(transfers[1].fromUserId).toBe('B');
      expect(transfers[0].toUserId).toBe('C');
      assertValid(net, transfers);
    });

    it('两两抵消：一人应收等于多人应付之和时笔数 = 债户数', () => {
      const net = new Map([
        ['A', -60],
        ['B', -40],
        ['C', 100],
      ]);
      const transfers = computeSettlement(net);
      expect(transfers).toHaveLength(2);
      expect(
        transfers.reduce((s, t) => s + t.amountCents, 0),
      ).toBe(100);
      assertValid(net, transfers);
    });

    it('大额混合场景（账单级数据）：清偿且笔数合理', () => {
      const net = summarizeBalances([
        {
          payerId: 'u1',
          amountCents: 8650,
          liabilities: [
            { userId: 'u1', shareCents: 2163 },
            { userId: 'u2', shareCents: 2162 },
            { userId: 'u3', shareCents: 2162 },
            { userId: 'u4', shareCents: 2163 },
          ],
        },
        {
          payerId: 'u2',
          amountCents: 16500,
          liabilities: [
            { userId: 'u1', shareCents: 5500 },
            { userId: 'u2', shareCents: 5500 },
            { userId: 'u3', shareCents: 5500 },
          ],
        },
        {
          payerId: 'u3',
          amountCents: 24000,
          liabilities: [
            { userId: 'u1', shareCents: 6000 },
            { userId: 'u2', shareCents: 6000 },
            { userId: 'u3', shareCents: 6000 },
            { userId: 'u4', shareCents: 6000 },
          ],
        },
        {
          payerId: 'u4',
          amountCents: 12000,
          liabilities: [
            { userId: 'u2', shareCents: 4000 },
            { userId: 'u3', shareCents: 4000 },
            { userId: 'u4', shareCents: 4000 },
          ],
        },
      ]);
      const transfers = computeSettlement(net);
      // 清偿校验
      assertValid(net, transfers);
      // 净债务人数目下界（每笔至多清零一方）
      const debtorCount = [...net.values()].filter((v) => v < 0).length;
      const creditorCount = [...net.values()].filter((v) => v > 0).length;
      expect(transfers.length).toBeLessThanOrEqual(debtorCount + creditorCount - 1);
    });

    it('边缘：单成员自我结算不产生转账', () => {
      const net = new Map([['A', 0]]);
      expect(computeSettlement(net)).toEqual([]);
    });

    it('epsilon 阈值忽略微小余额', () => {
      const net = new Map([
        ['A', 1],
        ['B', -1],
      ]);
      // 默认 epsilon=0：1 分钱也照清
      expect(computeSettlement(net)).toHaveLength(1);
      // epsilon=1（1分）：忽略
      expect(computeSettlement(net, 1)).toHaveLength(0);
    });
  });
});
