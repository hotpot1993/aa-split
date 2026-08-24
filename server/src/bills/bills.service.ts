import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { StorageService } from '../storage/storage.service';
import { resolveShares, computeSettleStatus, ResolvedShare } from './bills.util';
import { parseDateDay, formatDateDay } from '../common/date.util';
import { CreateBillDto } from './dto/create-bill.dto';
import { UpdateBillDto } from './dto/update-bill.dto';
import { paginate } from '../common/dto/pagination.dto';

const billInclude = {
  creator: { select: { id: true, accountName: true, nickname: true, avatarUrl: true } },
  payer: { select: { id: true, accountName: true, nickname: true, avatarUrl: true } },
  participants: {
    include: { user: { select: { id: true, accountName: true, nickname: true, avatarUrl: true } } },
  },
  receipts: { orderBy: { sort: 'asc' } },
} satisfies Prisma.BillInclude;

type BillWithRelations = Prisma.BillGetPayload<{ include: typeof billInclude }>;

@Injectable()
export class BillsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
    private readonly storageService: StorageService,
  ) {}

  private async assertGroupMember(groupId: string, userId: string) {
    const membership = await this.prisma.groupMember.findFirst({
      where: { groupId, userId, status: 'active' },
    });
    if (!membership) throw new NotFoundException('群组不存在');
  }

  private async assertGroupMemberIds(groupId: string, userIds: string[]) {
    const members = await this.prisma.groupMember.findMany({
      where: { groupId, userId: { in: userIds }, status: 'active' },
      select: { userId: true },
    });
    const activeIds = new Set(members.map((m) => m.userId));
    for (const id of userIds) {
      if (!activeIds.has(id)) {
        throw new BadRequestException('参与人/垫付人必须是群组活跃成员');
      }
    }
  }

  private mapBill(bill: BillWithRelations) {
    return {
      id: bill.id,
      groupId: bill.groupId,
      title: bill.title,
      location: bill.location,
      amountCents: bill.amountCents,
      billDate: formatDateDay(bill.billDate),
      category: bill.category,
      splitType: bill.splitType,
      settleStatus: bill.settleStatus,
      isRegular: bill.isRegular,
      regularId: bill.regularId,
      creator: bill.creator,
      payer: bill.payer,
      participants: bill.participants.map((p) => ({
        userId: p.userId,
        shareAmountCents: p.shareAmountCents,
        exempt: p.exempt,
        paid: p.paid,
        paidAt: p.paidAt,
        remindCount: p.remindCount,
        user: p.user,
      })),
      receipts: bill.receipts.map((r) => ({
        id: r.id,
        billId: r.billId,
        url: this.storageService.publicUrl(r.objectKey),
      })),
      createdAt: bill.createdAt,
    };
  }

  /** 群账单流水（分页，按 bill_date desc + created_at desc，只返回未删除） */
  async listBills(userId: string, groupId: string, page: number, pageSize: number) {
    await this.assertGroupMember(groupId, userId);
    const where: Prisma.BillWhereInput = { groupId, deletedAt: null };
    const [list, total] = await Promise.all([
      this.prisma.bill.findMany({
        where,
        include: billInclude,
        orderBy: [{ billDate: 'desc' }, { createdAt: 'desc' }],
        skip: (page - 1) * pageSize,
        take: pageSize,
      }),
      this.prisma.bill.count({ where }),
    ]);
    return paginate(list.map((b) => this.mapBill(b)), total, page, pageSize);
  }

  /** 创建账单（服务端校验分摊合计 + 群成员校验） */
  async createBill(userId: string, dto: CreateBillDto) {
    const { groupId, payerId, participants, ...rest } = dto;
    await this.assertGroupMember(groupId, userId);
    await this.assertGroupMemberIds(groupId, [payerId, ...participants.map((p) => p.userId)]);

    const shares = resolveShares(dto.splitType, dto.amountCents, participants);
    // 垫付人已自付其份额（现款在后，份额视为已结清）
    const payerShare = shares.find((s) => s.userId === payerId);
    if (payerShare) payerShare.paid = true;
    const settleStatus = computeSettleStatus(shares);

    const bill = await this.prisma.$transaction(async (tx) => {
      const created = await tx.bill.create({
        data: {
          groupId,
          creatorId: userId,
          payerId,
          title: dto.title,
          location: dto.location ?? null,
          amountCents: dto.amountCents,
          billDate: parseDateDay(dto.billDate),
          category: dto.category,
          splitType: dto.splitType,
          settleStatus,
          participants: {
            create: shares.map((s) => ({
              userId: s.userId,
              shareAmountCents: s.shareAmountCents,
              exempt: s.exempt,
              paid: s.paid,
            })),
          },
        },
        include: billInclude,
      });
      return created;
    });

    // 为每个非创建者参与者写 new_bill 通知
    const notifyUserId = [...new Set(shares.map((s) => s.userId))].filter(
      (id) => id !== userId,
    );
    await Promise.all(
      notifyUserId.map((id) =>
        this.notificationsService.create(id, {
          type: 'new_bill',
          title: '新账单',
          body: `「${dto.title}」新增，需付 ¥${(dto.amountCents / 100).toFixed(2)}`,
          refType: 'bill',
          refId: bill.id,
        }),
      ),
    );

    return this.mapBill(bill);
  }

  /** 账单详情（参与者或群主可读） */
  async getBill(userId: string, billId: string) {
    const bill = await this.findBillOrThrow(billId);
    await this.assertCanRead(userId, bill);
    return this.mapBill(bill);
  }

  private async findBillOrThrow(billId: string) {
    const bill = await this.prisma.bill.findFirst({
      where: { id: billId, deletedAt: null },
      include: billInclude,
    });
    if (!bill) throw new NotFoundException('账单不存在');
    return bill;
  }

  private async assertCanRead(userId: string, bill: BillWithRelations) {
    const group = await this.prisma.group.findFirst({ where: { id: bill.groupId } });
    const isParticipant = bill.participants.some((p) => p.userId === userId);
    const isOwner = group?.ownerId === userId;
    if (!isParticipant && !isOwner) throw new NotFoundException('账单不存在');
  }

  private async assertCanEdit(userId: string, billId: string) {
    const bill = await this.findBillOrThrow(billId);
    const group = await this.prisma.group.findFirst({ where: { id: bill.groupId } });
    const isCreator = bill.creatorId === userId;
    const isOwner = group?.ownerId === userId;
    if (!isCreator && !isOwner) throw new ForbiddenException('仅创建者或群主可编辑该账单');
    return { bill, group };
  }

  /** 编辑账单（仅创建者或群主） */
  async updateBill(userId: string, billId: string, dto: UpdateBillDto) {
    const { bill, group } = await this.assertCanEdit(userId, billId);

    let amountCents = dto.amountCents ?? bill.amountCents;
    let splitType = dto.splitType ?? bill.splitType;
    let payerId = dto.payerId ?? bill.payerId;

    await this.assertGroupMemberIds(bill.groupId, [
      payerId,
      ...(dto.participants?.map((p) => p.userId) ?? bill.participants.map((p) => p.userId)),
    ]);

    let shares: ResolvedShare[] | undefined;
    if (dto.participants) {
      shares = resolveShares(splitType, amountCents, dto.participants);
    } else if (dto.amountCents !== undefined && splitType === 'even') {
      // 仅改金额且为均摊：按当前参与人数重算
      shares = resolveShares(splitType, amountCents, bill.participants.map((p) => ({
        userId: p.userId,
        exempt: p.exempt,
      })));
    }

    const settleStatus = shares ? computeSettleStatus(shares) : bill.settleStatus;

    const updated = await this.prisma.$transaction(async (tx) => {
      if (shares) {
        await tx.billParticipant.deleteMany({ where: { billId } });
      }
      const res = await tx.bill.update({
        where: { id: billId },
        data: {
          title: dto.title ?? bill.title,
          location: dto.location !== undefined ? dto.location : bill.location,
          amountCents,
          billDate: dto.billDate ? parseDateDay(dto.billDate) : bill.billDate,
          category: dto.category ?? bill.category,
          splitType,
          payerId,
          settleStatus,
          ...(shares
            ? {
                participants: {
                  create: shares.map((s) => ({
                    userId: s.userId,
                    shareAmountCents: s.shareAmountCents,
                    exempt: s.exempt,
                  })),
                },
              }
            : {}),
        },
        include: billInclude,
      });
      return res;
    });
    return this.mapBill(updated);
  }

  /** 删除账单（软删除，创建者或群主） */
  async deleteBill(userId: string, billId: string) {
    await this.assertCanEdit(userId, billId);
    return this.prisma.bill.update({
      where: { id: billId },
      data: { deletedAt: new Date() },
    });
  }

  /** 上传凭证（multipart file；创建者、垫付人或群主） */
  async uploadReceipt(userId: string, billId: string, file: Express.Multer.File) {
    if (!file) throw new BadRequestException('缺少凭证文件');
    const bill = await this.findBillOrThrow(billId);
    const group = await this.prisma.group.findFirst({ where: { id: bill.groupId } });
    const allowed =
      bill.creatorId === userId || bill.payerId === userId || group?.ownerId === userId;
    if (!allowed) throw new ForbiddenException('无权上传凭证');

    const stored = await this.storageService.upload(file);
    const receipt = await this.prisma.receipt.create({
      data: { billId, objectKey: stored.objectKey },
    });
    return { id: receipt.id, billId, objectKey: receipt.objectKey, url: stored.url };
  }

  /** 标记某参与人已付/未付；事务更新 + 重算 settle_status + 写通知 */
  async markPaid(userId: string, billId: string, targetUserId: string, paid: boolean) {
    const bill = await this.findBillOrThrow(billId);
    await this.assertGroupMember(bill.groupId, userId);

    const participant = bill.participants.find((p) => p.userId === targetUserId);
    if (!participant) throw new NotFoundException('该参与人不在账单中');

    const updated = await this.prisma.$transaction(async (tx) => {
      const res = await tx.billParticipant.update({
        where: { id: participant.id },
        data: { paid, paidAt: paid ? new Date() : null },
      });
      const all = await tx.billParticipant.findMany({
        where: { billId },
      });
      const status = computeSettleStatus(
        all.map((p) => ({ shareAmountCents: p.shareAmountCents, paid: p.paid }) as ResolvedShare),
      );
      await tx.bill.update({
        where: { id: billId },
        data: { settleStatus: status },
      });
      return res;
    });

    // 给账单创建者/垫付人写通知（若目标非本人）
    const notified = bill.payerId === userId ? null : bill.payerId;
    if (notified) {
      const targetUser = await this.prisma.user.findUnique({ where: { id: targetUserId } });
      await this.notificationsService.create(notified, {
        type: 'settled',
        title: paid ? '付款提醒' : '取消付款',
        body: paid
          ? `${targetUser?.nickname ?? '成员'} 已支付「${bill.title}」¥${(participant.shareAmountCents / 100).toFixed(2)}`
          : `${targetUser?.nickname ?? '成员'} 取消了「${bill.title}」的付款`,
        refType: 'bill',
        refId: billId,
      });
    }
    return { success: true, paid, paidAt: updated.paidAt };
  }

  /** 催款：写 notification + 触发 SSE */
  async remind(userId: string, billId: string, userIds: string[], message?: string) {
    const bill = await this.findBillOrThrow(billId);
    await this.assertGroupMember(bill.groupId, userId);

    for (const targetUserId of userIds) {
      const participant = bill.participants.find((p) => p.userId === targetUserId);
      if (participant) {
        await this.prisma.billParticipant.update({
          where: { id: participant.id },
          data: { remindCount: { increment: 1 } },
        });
        const receiver = await this.prisma.user.findUnique({ where: { id: targetUserId } });
        await this.notificationsService.create(targetUserId, {
          type: 'remind',
          title: '催款提醒',
          body:
            message ||
            `「${bill.title}」还未付款，请及时处理（¥${(participant.shareAmountCents / 100).toFixed(2)}）`,
          refType: 'bill',
          refId: billId,
        });
      }
    }
    return { success: true, remindedCount: userIds.length };
  }

  /** 供结算/导出：取某群组用于计算的账单（未删除，非定期快照的原始语义剔除由结算按参与人状态处理） */
  async findBillsForGroup(groupId: string) {
    return this.prisma.bill.findMany({
      where: { groupId, deletedAt: null },
      include: billInclude,
    });
  }
}
