import { NotFoundException } from '@nestjs/common';
import { NotificationsService } from './notifications.service';

describe('NotificationsService.pushDataEvent', () => {
  it('静默数据事件：仅推 SSE，不写通知库、不触极光推送', () => {
    const sse = { push: jest.fn() } as any;
    const jpush = { notify: jest.fn() } as any;
    const svc = new NotificationsService({} as any, sse, jpush);

    svc.pushDataEvent('u1', { refType: 'bill', refId: 'b1' });

    expect(sse.push).toHaveBeenCalledWith(
      'u1',
      expect.objectContaining({
        type: 'data',
        title: '',
        body: '',
        refType: 'bill',
        refId: 'b1',
      }),
    );
    expect(jpush.notify).not.toHaveBeenCalled();
  });
});

describe('NotificationsService.remove / removeAll（消息中心删除）', () => {
  const makeSvc = (prisma: any) =>
    new NotificationsService(prisma, { push: jest.fn() } as any, {
      notify: jest.fn(),
    } as any);

  it('删除单条：先按 id+userId 校验归属，再按 id 删除', async () => {
    const prisma = {
      notification: {
        findFirst: jest.fn().mockResolvedValue({ id: 'n1', userId: 'u1' }),
        delete: jest.fn().mockResolvedValue({ id: 'n1' }),
      },
    };
    const svc = makeSvc(prisma);

    const out = await svc.remove('u1', 'n1');

    expect(prisma.notification.findFirst).toHaveBeenCalledWith({
      where: { id: 'n1', userId: 'u1' },
    });
    expect(prisma.notification.delete).toHaveBeenCalledWith({
      where: { id: 'n1' },
    });
    expect(out).toEqual({ success: true });
  });

  it('删除不存在或他人的通知 → 404', async () => {
    const prisma = {
      notification: {
        findFirst: jest.fn().mockResolvedValue(null),
        delete: jest.fn(),
      },
    };
    const svc = makeSvc(prisma);

    await expect(svc.remove('u1', 'nope')).rejects.toThrow(NotFoundException);
    expect(prisma.notification.delete).not.toHaveBeenCalled();
  });

  it('清空全部：deleteMany({ userId }) 返回删除条数', async () => {
    const prisma = {
      notification: {
        deleteMany: jest.fn().mockResolvedValue({ count: 3 }),
      },
    };
    const svc = makeSvc(prisma);

    const out = await svc.removeAll('u1');

    expect(prisma.notification.deleteMany).toHaveBeenCalledWith({
      where: { userId: 'u1' },
    });
    expect(out).toEqual({ deleted: 3 });
  });
});
