import { ForbiddenException } from '@nestjs/common';
import { GroupsService } from './groups.service';

function makeSvc(
  members: Array<{ userId: string }> = [
    { userId: 'u_owner' },
    { userId: 'u_zhangsan' },
    { userId: 'u_lisi' },
  ],
) {
  const prisma = {
    group: {
      findFirst: jest.fn().mockResolvedValue({
        id: 'g1',
        name: '饭友群',
        ownerId: 'u_owner',
        deletedAt: null,
      }),
      update: jest.fn().mockResolvedValue({}),
    },
    groupMember: {
      findMany: jest.fn().mockResolvedValue(members),
    },
  };
  const notifications = {
    createMany: jest.fn().mockResolvedValue([]),
  };
  const svc = new GroupsService(prisma as any, notifications as any);
  return { svc, prisma, notifications };
}

describe('GroupsService.deleteGroup（群主解散 → 组员端同步移除）', () => {
  it('解散后给其它 active 成员写通知（SSE 推送触发组员端刷新），不含群主', async () => {
    const { svc, notifications } = makeSvc();
    await svc.deleteGroup('u_owner', 'g1');

    expect(notifications.createMany).toHaveBeenCalledWith(
      ['u_zhangsan', 'u_lisi'],
      expect.objectContaining({
        type: 'member',
        title: '群组已解散',
        body: '「饭友群」已被群主解散',
        refType: 'group',
        refId: 'g1',
      }),
    );
  });

  it('群内只有群主一人时，不产生通知也不报错', async () => {
    const { svc, notifications } = makeSvc([{ userId: 'u_owner' }]);
    await expect(svc.deleteGroup('u_owner', 'g1')).resolves.toEqual({
      success: true,
    });
    expect(notifications.createMany).not.toHaveBeenCalled();
  });

  it('非群主解散 → Forbidden', async () => {
    const { svc } = makeSvc();
    await expect(svc.deleteGroup('u_zhangsan', 'g1')).rejects.toThrow(
      ForbiddenException,
    );
  });
});

describe('GroupsService.updateGroup（默认免分摊人员）', () => {
  it('只保留群内 active 成员并去重', async () => {
    const { svc, prisma } = makeSvc([
      { userId: 'u_owner' },
      { userId: 'u_zhangsan' },
      { userId: 'u_lisi' },
    ]);
    await svc.updateGroup('u_owner', 'g1', {
      defaultExemptUserIds: ['u_zhangsan', 'u_ghost', 'u_zhangsan'],
    });
    expect(prisma.group.update).toHaveBeenCalledWith({
      where: { id: 'g1' },
      data: expect.objectContaining({
        defaultExemptUserIds: ['u_zhangsan'],
      }),
    });
  });

  it('非群主修改 → Forbidden', async () => {
    const { svc } = makeSvc();
    await expect(
      svc.updateGroup('u_lisi', 'g1', { defaultExemptUserIds: [] }),
    ).rejects.toThrow(ForbiddenException);
  });
});
