import { BadRequestException } from '@nestjs/common';
import { SplitType } from '@prisma/client';
import { BillParticipantDto } from './dto/create-bill.dto';

export interface ResolvedShare {
  userId: string;
  shareAmountCents: number;
  exempt: boolean;
  paid: boolean;
  paidAt: Date | null;
}

/**
 * 依据 splitType 解析并校验分摊金额。
 * - even：自动均摊（余数给第一位非免摊参与者；免摊者=0）
 * - custom / ratio：必须提供 shareAmountCents，且 Σ = amountCents；免摊者必须为 0
 * 违反则抛出 BadRequestException（400）。
 */
export function resolveShares(
  splitType: SplitType,
  amountCents: number,
  participants: BillParticipantDto[],
): ResolvedShare[] {
  if (amountCents <= 0) {
    throw new BadRequestException('账单金额必须大于 0');
  }
  if (!participants || participants.length === 0) {
    throw new BadRequestException('至少需要一个参与人');
  }

  if (splitType === SplitType.even) {
    const payers = participants.filter((p) => !p.exempt);
    if (payers.length === 0) {
      throw new BadRequestException('至少需要一位非免摊参与人');
    }
    const base = Math.floor(amountCents / payers.length);
    const remainder = amountCents - base * payers.length;
    return participants.map((p, i) => {
      if (p.exempt) {
        return { userId: p.userId, shareAmountCents: 0, exempt: true, paid: false, paidAt: null };
      }
      const idx = payers.indexOf(p);
      const share = idx === 0 ? base + remainder : base;
      return { userId: p.userId, shareAmountCents: share, exempt: false, paid: false, paidAt: null };
    });
  }

  // custom / ratio
  let sum = 0;
  const resolved = participants.map((p) => {
    if (p.exempt && (p.shareAmountCents ?? 0) !== 0) {
      throw new BadRequestException('免摊参与人的分摊金额必须为 0');
    }
    if (!p.exempt) {
      if (p.shareAmountCents === undefined || p.shareAmountCents === null) {
        throw new BadRequestException('自定义/比例分摊必须提供每个非免摊参与人的分摊金额');
      }
      if (p.shareAmountCents < 0) {
        throw new BadRequestException('分摊金额不能为负数');
      }
      sum += p.shareAmountCents;
    }
    return {
      userId: p.userId,
      shareAmountCents: p.shareAmountCents ?? 0,
      exempt: p.exempt ?? false,
      paid: false,
      paidAt: null,
    };
  });
  if (sum !== amountCents) {
    throw new BadRequestException(`分摊合计(${sum}) 必须等于账单金额(${amountCents})`);
  }
  return resolved;
}

export type SettleStatusValue = 'settled' | 'partial' | 'pending';

/** 由参与人已付情况重算 settle_status（仅统计应摊 >0 的参与人） */
export function computeSettleStatus(participants: ResolvedShare[]): SettleStatusValue {
  const owing = participants.filter((p) => p.shareAmountCents > 0);
  if (owing.length === 0) return 'settled';
  const paidCount = owing.filter((p) => p.paid).length;
  if (paidCount === owing.length) return 'settled';
  if (paidCount > 0) return 'partial';
  return 'pending';
}
