import { SplitType } from '@prisma/client';
import { resolveShares, computeSettleStatus } from './bills.util';

describe('bills.util', () => {
  describe('resolveShares — even 均摊', () => {
    it('自动均摊且余数给第一位', () => {
      const shares = resolveShares(SplitType.even, 10000, [
        { userId: 'A' },
        { userId: 'B' },
        { userId: 'C' },
      ]);
      const sum = shares.reduce((s, x) => s + x.shareAmountCents, 0);
      expect(sum).toBe(10000);
      expect(shares[0].shareAmountCents).toBe(3334);
      expect(shares[1].shareAmountCents).toBe(3333);
      expect(shares[2].shareAmountCents).toBe(3333);
    });

    it('免摊者金额为 0，其余人分摊', () => {
      const shares = resolveShares(SplitType.even, 10000, [
        { userId: 'A' },
        { userId: 'B', exempt: true },
        { userId: 'C' },
      ]);
      expect(shares.find((s) => s.userId === 'B')!.shareAmountCents).toBe(0);
      expect(shares[0].shareAmountCents).toBe(5000);
      expect(shares[2].shareAmountCents).toBe(5000);
    });

    it('全部免摊 → 抛 400', () => {
      expect(() =>
        resolveShares(SplitType.even, 10000, [
          { userId: 'A', exempt: true },
        ]),
      ).toThrow();
    });
  });

  describe('resolveShares — custom/ratio', () => {
    it('自定义金额合计等于账单金额', () => {
      const shares = resolveShares(SplitType.custom, 10000, [
        { userId: 'A', shareAmountCents: 4000 },
        { userId: 'B', shareAmountCents: 6000 },
      ]);
      expect(shares.reduce((s, x) => s + x.shareAmountCents, 0)).toBe(10000);
    });

    it('合计不等于金额 → 抛 400', () => {
      expect(() =>
        resolveShares(SplitType.custom, 10000, [
          { userId: 'A', shareAmountCents: 4000 },
          { userId: 'B', shareAmountCents: 5000 },
        ]),
      ).toThrow('分摊合计');
    });

    it('免摊者金额必须为 0，否则抛错', () => {
      expect(() =>
        resolveShares(SplitType.custom, 10000, [
          { userId: 'A', shareAmountCents: 10000 },
          { userId: 'B', shareAmountCents: 500, exempt: true },
        ]),
      ).toThrow('免摊参与人的分摊金额必须为 0');
    });

    it('自定义模式缺少分摊金额 → 抛 400', () => {
      expect(() =>
        resolveShares(SplitType.custom, 10000, [{ userId: 'A' }]),
      ).toThrow('必须提供每个非免摊参与人的分摊金额');
    });
  });

  describe('computeSettleStatus', () => {
    it('全部已付 → settled', () => {
      expect(
        computeSettleStatus([
          { shareAmountCents: 100, paid: true, exempt: false, userId: 'A', paidAt: null },
          { shareAmountCents: 200, paid: true, exempt: false, userId: 'B', paidAt: null },
        ]),
      ).toBe('settled');
    });
    it('部分已付 → partial', () => {
      expect(
        computeSettleStatus([
          { shareAmountCents: 100, paid: true, exempt: false, userId: 'A', paidAt: null },
          { shareAmountCents: 200, paid: false, exempt: false, userId: 'B', paidAt: null },
        ]),
      ).toBe('partial');
    });
    it('全部未付 → pending；免摊(0)不影响', () => {
      expect(
        computeSettleStatus([
          { shareAmountCents: 100, paid: false, exempt: false, userId: 'A', paidAt: null },
          { shareAmountCents: 0, paid: false, exempt: true, userId: 'B', paidAt: null },
        ]),
      ).toBe('pending');
    });
  });
});
