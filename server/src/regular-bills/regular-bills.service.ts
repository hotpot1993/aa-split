import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { BillCycle, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { resolveShares, computeSettleStatus } from '../bills/bills.util';
import { parseDateDay, formatDateDay } from '../common/date.util';
import { computeNextRunAt } from './regular-bills.util';
import { CreateRegularBillDto } from './dto/create-regular-bill.dto';
import { UpdateRegularBillDto } from './dto/update-regular-bill.dto';

interface TemplateParticipant {
  userId: string;
  shareAmountCents?: number;
  exempt?: boolean;
}

const regularInclude = {
  creator: { select: { id: true, accountName: true, nickname: true, avatarUrl: true } },
  group: { select: { id: true, name: true } },
} satisfies Prisma.RegularBillInclude;

@Injectable()
export class RegularBillsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  private async assertMember(groupId: string, userId: string) {
    const m = await this.prisma.groupMember.findFirst({
      where: { groupId, userId, status: 'active' },
    });
    if (!m) throw new NotFoundException('群组不存在');
  }

  private async assertMemberIds(groupId: string, userIds: string[]) {
    const members = await this.prisma.groupMember.findMany({
      where: { groupId, userId: { in: userIds }, status: 'active' },
      select: { userId: true },
    });
    const active = new Set(members.map((m) => m.userId));
    for (const id of userIds) {
      if (!active.has(id)) throw new BadRequestException('参与人必须是群组活跃成员');
    }
  }

  async listMy(userId: string) {
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId, status: 'active' },
      select: { groupId: true },
    });
    const groupIds = memberships.map((m) => m.groupId);
    if (groupIds.length === 0) return [];
    return this.prisma.regularBill.findMany({
      where: { groupId: { in: groupIds }, deletedAt: null },
      include: regularInclude,
      orderBy: { nextRunAt: 'asc' },
    });
  }

  async create(userId: string, dto: CreateRegularBillDto) {
    await this.assertMember(dto.groupId, userId);
    await this.assertMemberIds(dto.groupId, dto.participants.map((p) => p.userId));

    this.validateScheduleFields(dto.cycle, dto.dayOfWeek, dto.dayOfMonth);

    const nextRunAt = computeNextRunAt(
      dto.cycle,
      dto.dayOfWeek ?? null,
      dto.dayOfMonth ?? null,
      new Date(),
    );

    return this.prisma.regularBill.create({
      data: {
        groupId: dto.groupId,
        creatorId: userId,
        title: dto.title,
        amountCents: dto.amountCents,
        category: dto.category,
        splitType: dto.splitType,
        cycle: dto.cycle,
        dayOfWeek: dto.dayOfWeek ?? null,
        dayOfMonth: dto.dayOfMonth ?? null,
        participants: dto.participants as unknown as Prisma.InputJsonValue,
        nextRunAt,
        active: true,
      },
      include: regularInclude,
    });
  }

  async get(userId: string, id: string) {
    const rb = await this.findOrThrow(id);
    await this.assertMember(rb.groupId, userId);
    return rb;
  }

  async update(userId: string, id: string, dto: UpdateRegularBillDto) {
    const rb = await this.findOrThrow(id);
    await this.assertMember(rb.groupId, userId);

    const patch: Prisma.RegularBillUpdateInput = {};
    if (dto.title !== undefined) patch.title = dto.title;
    if (dto.amountCents !== undefined) patch.amountCents = dto.amountCents;
    if (dto.category !== undefined) patch.category = dto.category;
    if (dto.splitType !== undefined) patch.splitType = dto.splitType;
    if (dto.cycle !== undefined) patch.cycle = dto.cycle;
    if (dto.dayOfWeek !== undefined) patch.dayOfWeek = dto.dayOfWeek;
    if (dto.dayOfMonth !== undefined) patch.dayOfMonth = dto.dayOfMonth;
    if (dto.active !== undefined) patch.active = dto.active;
    if (dto.participants) {
      patch.participants = dto.participants as unknown as Prisma.InputJsonValue;
    }

    // 重新计算下次运行时间
    const nextCycle = dto.cycle ?? rb.cycle;
    const nextDow = dto.dayOfWeek !== undefined ? dto.dayOfWeek : rb.dayOfWeek;
    const nextDom = dto.dayOfMonth !== undefined ? dto.dayOfMonth : rb.dayOfMonth;
    this.validateScheduleFields(nextCycle, nextDow, nextDom);
    patch.nextRunAt = computeNextRunAt(nextCycle, nextDow ?? null, nextDom ?? null, new Date());

    return this.prisma.regularBill.update({
      where: { id },
      data: patch,
      include: regularInclude,
    });
  }

  async remove(userId: string, id: string) {
    const rb = await this.findOrThrow(id);
    await this.assertMember(rb.groupId, userId);
    await this.prisma.regularBill.update({
      where: { id },
      data: { active: false, deletedAt: new Date() },
    });
    return { success: true };
  }

  private async findOrThrow(id: string) {
    const rb = await this.prisma.regularBill.findFirst({
      where: { id, deletedAt: null },
      include: regularInclude,
    });
    if (!rb) throw new NotFoundException('定期账单不存在');
    return rb;
  }

  private validateScheduleFields(
    cycle: BillCycle,
    dayOfWeek: number | null | undefined,
    dayOfMonth: number | null | undefined,
  ) {
    if (cycle === BillCycle.weekly || cycle === BillCycle.biweekly) {
      if (dayOfWeek === null || dayOfWeek === undefined) {
        throw new BadRequestException('每周/每两周周期需提供 dayOfWeek(0-6)');
      }
    } else if (cycle === BillCycle.monthly) {
      if (dayOfMonth === null || dayOfMonth === undefined) {
        throw new BadRequestException('每月周期需提供 dayOfMonth(1-31)');
      }
    }
  }

  private mapTemplate(template: TemplateParticipant[]) {
    return template.map((p) => ({
      userId: p.userId,
      shareAmountCents: p.shareAmountCents,
      exempt: p.exempt ?? false,
    }));
  }

  /** 扫描到期定期账单 → 生成账单副本（供 BullMQ 处理器调用） */
  async processDueRegularBills() {
    const due = await this.prisma.regularBill.findMany({
      where: { active: true, deletedAt: null, nextRunAt: { lte: new Date() } },
      include: { group: true },
    });
    let generated = 0;
    for (const rb of due) {
      try {
        const template = (rb.participants as unknown as TemplateParticipant[]) ?? [];
        // 仅保留当前活跃成员
        const members = await this.prisma.groupMember.findMany({
          where: { groupId: rb.groupId, status: 'active' },
          select: { userId: true },
        });
        const activeIds = new Set(members.map((m) => m.userId));
        const templateActive = template.filter((p) => activeIds.has(p.userId));
        if (templateActive.length === 0) continue;

        const shares = resolveShares(
          rb.splitType,
          rb.amountCents,
          this.mapTemplate(templateActive),
        );
        const settleStatus = computeSettleStatus(shares);
        const runDate = formatDateDay(rb.nextRunAt);

        await this.prisma.$transaction(async (tx) => {
          const bill = await tx.bill.create({
            data: {
              groupId: rb.groupId,
              creatorId: rb.creatorId,
              payerId: rb.creatorId, // 简化：定期账单垫付人=模板创建者
              title: rb.title,
              amountCents: rb.amountCents,
              billDate: parseDateDay(runDate),
              category: rb.category,
              splitType: rb.splitType,
              settleStatus,
              isRegular: true,
              regularId: rb.id,
              participants: {
                create: shares.map((s) => ({
                  userId: s.userId,
                  shareAmountCents: s.shareAmountCents,
                  exempt: s.exempt,
                })),
              },
            },
            include: { participants: true },
          });

          await tx.regularBill.update({
            where: { id: rb.id },
            data: {
              nextRunAt: computeNextRunAt(
                rb.cycle,
                rb.dayOfWeek,
                rb.dayOfMonth,
                rb.nextRunAt,
              ),
            },
          });

          // 通知参与者（跳过创建者）
          const notifyIds = shares
            .map((s) => s.userId)
            .filter((uid) => uid !== rb.creatorId);
          for (const uid of notifyIds) {
            await tx.notification.create({
              data: {
                userId: uid,
                type: 'regular',
                title: '定期账单已生成',
                body: `「${rb.title}」¥${(rb.amountCents / 100).toFixed(2)} 已生成，请及时处理`,
                refType: 'bill',
                refId: bill.id,
              },
            });
          }
        });
        generated++;
      } catch (e: any) {
        // 单条失败不影响本轮扫描
        console.warn(`生成定期账单失败(${rb.title}): ${e?.message}`);
      }
    }
    return { generated };
  }
}
