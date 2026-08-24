import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { summarizeBalances, computeSettlement, SettlementTransfer } from './settlement.algorithm';

export interface BillForSettlement {
  id: string;
  payerId: string;
  amountCents: number;
  participants: Array<{
    userId: string;
    shareAmountCents: number;
    paid: boolean;
  }>;
}

@Injectable()
export class SettlementService {
  constructor(private readonly prisma: PrismaService) {}

  private async assertGroupMember(groupId: string, userId: string) {
    const membership = await this.prisma.groupMember.findFirst({
      where: { groupId, userId, status: 'active' },
    });
    if (!membership) throw new NotFoundException('群组不存在');
  }

  /** 计算群结算方案并把本次方案落库（group_id 维度最新 pending 记录） */
  async getSettlement(userId: string, groupId: string) {
    await this.assertGroupMember(groupId, userId);

    const bills = await this.prisma.bill.findMany({
      where: { groupId, deletedAt: null },
      include: { participants: true },
    });

    // 只取未结清账单：存在 unpaid 参与人（share>0 且未付）
    const unsettled: BillForSettlement[] = bills
      .filter((b) =>
        b.participants.some((p) => p.shareAmountCents > 0 && !p.paid),
      )
      .map((b) => ({
        id: b.id,
        payerId: b.payerId,
        amountCents: b.amountCents,
        participants: b.participants.map((p) => ({
          userId: p.userId,
          shareAmountCents: p.shareAmountCents,
          paid: p.paid,
        })),
      }));

    const net = summarizeBalances(
      unsettled.map((b) => ({
        payerId: b.payerId,
        amountCents: b.amountCents,
        liabilities: b.participants.map((p) => ({
          userId: p.userId,
          shareCents: p.shareAmountCents,
          paid: p.paid,
        })),
      })),
    );

    const transfers = computeSettlement(net);

    // 近似归属：把每个转账金额贪心归属到未结清账单
    const transfersWithBills = transfers.map((t) => ({
      ...t,
      billIds: this.attributeBillIds(unsettled, t),
    }));

    // 落库：删除该群旧的 pending 方案，重建为最新 pending 记录
    await this.prisma.$transaction(async (tx) => {
      await tx.settlement.deleteMany({
        where: { groupId, status: 'pending' },
      });
      if (transfersWithBills.length === 0) return;
      await tx.settlement.createMany({
        data: transfersWithBills.map((t) => ({
          groupId,
          fromUserId: t.fromUserId,
          toUserId: t.toUserId,
          amountCents: t.amountCents,
          status: 'pending',
          billIds: t.billIds,
        })),
      });
    });

    // 读取刚创建的记录 id（按同一顺序取）
    const created = await this.prisma.settlement.findMany({
      where: { groupId, status: 'pending' },
      orderBy: { createdAt: 'asc' },
    });

    return {
      transferCount: transfersWithBills.length,
      transfers: transfersWithBills,
      settlementIds: created.map((c) => c.id),
    };
  }

  /** 标记结算记录已收款（仅群成员可操作） */
  async markPaid(userId: string, settlementId: string) {
    const settlement = await this.prisma.settlement.findUnique({
      where: { id: settlementId },
    });
    if (!settlement) throw new NotFoundException('结算记录不存在');
    await this.assertGroupMember(settlement.groupId, userId);
    return this.prisma.settlement.update({
      where: { id: settlementId },
      data: { status: 'paid' },
    });
  }

  /**
   * 近似归属：把一笔转账金额（fromUser 应付给 toUser 的合计）贪心归属到未结清账单。
   * 优先归属金额更大的账单（from 在该账单的未付应摊越大越先归属）。
   */
  private attributeBillIds(
    bills: BillForSettlement[],
    transfer: SettlementTransfer,
  ): string[] {
    let remaining = transfer.amountCents;
    const billIds: string[] = [];

    const candidates = bills
      .filter((b) =>
        b.participants.some(
          (p) => p.userId === transfer.fromUserId && p.shareAmountCents > 0 && !p.paid,
        ),
      )
      .map((b) => {
        const share = b.participants.find(
          (p) => p.userId === transfer.fromUserId,
        )!.shareAmountCents;
        return { id: b.id, share };
      })
      .sort((a, b) => b.share - a.share);

    for (const c of candidates) {
      if (remaining <= 0) break;
      billIds.push(c.id);
      remaining -= c.share;
    }
    return billIds;
  }
}
