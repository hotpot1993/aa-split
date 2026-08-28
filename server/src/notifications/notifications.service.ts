import { Injectable, NotFoundException } from '@nestjs/common';
import { NotificationType, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationSseService } from './notification-sse.service';
import { JpushService } from './jpush.service';
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
    private readonly jpush: JpushService,
  ) {}

  /** 写库 + SSE 推送 + 极光离线推送（fire-and-forget，不阻塞） */
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
    // 离线推送（alias=userId）：失败仅告警
    void this.jpush.notify(userId, {
      title: n.title,
      alert: n.body,
      refType: n.refType,
      refId: n.refId,
    });
    return n;
  }

  /** 数据变更信号（静默）：只推 SSE，不写通知库、不触极光。
   *  客户端收到后仅用于刷新数据（如对方添加/修改账单后列表实时更新）。 */
  pushDataEvent(userId: string, input: { refType?: string; refId?: string }) {
    this.sse.push(userId, {
      type: 'data',
      title: '',
      body: '',
      refType: input.refType ?? null,
      refId: input.refId ?? null,
    });
  }

  /** 批量创建（给多个接收者写同一条通知） */
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

  /** 删除单条通知（仅本人）。
   *  幂等语义（v1.0.14）：通知已不存在 / 非本人通知 → 一律返回 { success: true }。
   *  真机网络偶发丢响应会导致客户端对同一条消息重复 DELETE，此前 404 会让
   *  客户端误判"删除失败"并把已删除的消息重新显示回来（复活），故按 RFC
   *  对 DELETE 的幂等要求处理：目标已不在即为成功。 */
  async remove(userId: string, id: string) {
    const n = await this.prisma.notification.findFirst({
      where: { id, userId },
    });
    if (!n) return { success: true, alreadyGone: true };
    await this.prisma.notification.delete({ where: { id } });
    return { success: true };
  }

  /** 清空本人全部通知，返回删除条数 */
  async removeAll(userId: string) {
    const { count } = await this.prisma.notification.deleteMany({
      where: { userId },
    });
    return { deleted: count };
  }
}
