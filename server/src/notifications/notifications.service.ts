import { Injectable, NotFoundException } from '@nestjs/common';
import { NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationSseService } from './notification-sse.service';
import { paginate } from '../common/dto/pagination.dto';

export interface CreateNotificationInput {
  type: NotificationType;
  title: string;
  body: string;
  refType?: string;
  refId?: string;
}

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly sse: NotificationSseService,
  ) {}

  /** 写库 + SSE 推送（单条） */
  async create(userId: string, input: CreateNotificationInput) {
    const n = await this.prisma.notification.create({
      data: {
        userId,
        type: input.type,
        title: input.title,
        body: input.body,
        refType: input.refType ?? null,
        refId: input.refId ?? null,
      },
    });
    this.sse.push(userId, {
      type: n.type,
      title: n.title,
      body: n.body,
      refType: n.refType,
      refId: n.refId,
      createdAt: n.createdAt.toISOString(),
    });
    return n;
  }

  /** 批量创建（可选并合理：给多个参与者写 new_bill） */
  async createMany(userIds: string[], input: CreateNotificationInput) {
    const created = [];
    for (const userId of userIds) {
      created.push(await this.create(userId, input));
    }
    return created;
  }

  async list(
    userId: string,
    filter: { type?: string; isRead?: boolean; page: number; pageSize: number },
  ) {
    const where: Prisma.NotificationWhereInput = { userId };
    if (filter.type) where.type = filter.type as NotificationType;
    if (filter.isRead !== undefined) where.isRead = filter.isRead;

    const [list, total] = await Promise.all([
      this.prisma.notification.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: (filter.page - 1) * filter.pageSize,
        take: filter.pageSize,
      }),
      this.prisma.notification.count({ where }),
    ]);
    return paginate(list, total, filter.page, filter.pageSize);
  }

  async unreadCount(userId: string) {
    const count = await this.prisma.notification.count({
      where: { userId, isRead: false },
    });
    return { count };
  }

  async readAll(userId: string) {
    const { count } = await this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });
    return { updated: count };
  }

  async readOne(userId: string, id: string) {
    const n = await this.prisma.notification.findFirst({
      where: { id, userId },
    });
    if (!n) throw new NotFoundException('通知不存在');
    return this.prisma.notification.update({
      where: { id },
      data: { isRead: true },
    });
  }
}
