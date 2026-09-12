import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { GroupsService } from './groups.service';

/**
 * 非注册成员（占位账号）单测：
 * 覆盖 e2e 不便构造的分支 —— 单群 50 人上限、定期账单模板（JSON）合并、
 * 认领时的群成员关系合并、群列表 memberCount 口径。
 * 完整链路（添加→改名→记账→预览→认领）见 test/app.e2e-spec.ts。
 */
function makeSvc() {
  const prisma: any = {
    group: {
      findFirst: jest.fn().mockResolvedValue({
        id: 'g1',
        name: '饭友群',
        ownerId: 'u_owner',
        deletedAt: null,
        defaultExemptUserIds: [],
      }),
      update: jest.fn().mockResolvedValue({}),
    },
    groupMember: {
      // assertMember：调用者是 active 成员
      findFirst: jest.fn().mockResolvedValue({
        id: 'gm_owner',
        groupId: 'g1',
        userId: 'u_owner',
        status: 'active',
      }),
      findMany: jest.fn().mockResolvedValue([]),
      findUnique: jest.fn().mockResolvedValue(null),
      create: jest.fn().mockResolvedValue({ id: 'gm_new' }),
      update: jest.fn().mockResolvedValue({}),
      delete: jest.fn().mockResolvedValue({}),
    },
    user: {
      findUnique: jest.fn().mockResolvedValue(null),
      findFirst: jest.fn().mockResolvedValue(null),
      create: jest.fn(),
      update: jest.fn().mockResolvedValue({}),
    },
    bill: {
      findMany: jest.fn().mockResolvedValue([]),
      updateMany: jest.fn().mockResolvedValue({ count: 0 }),
    },
    billParticipant: {
      findMany: jest.fn().mockResolvedValue([]),
      findUnique: jest.fn().mockResolvedValue(null),
      update: jest.fn().mockResolvedValue({}),
      delete: jest.fn().mockResolvedValue({}),
    },
    settlement: {
      count: jest.fn().mockResolvedValue(0),
      updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
    },
    regularBill: {
      findMany: jest.fn().mockResolvedValue([]),
      update: jest.fn().mockResolvedValue({}),
    },
  };
  prisma.$transaction = (fn: (tx: unknown) => Promise<unknown>) => fn(prisma);
  const notifications = {
    createMany: jest.fn().mockResolvedValue([]),
    create: jest.fn().mockResolvedValue(null),
  };
  const svc = new GroupsService(prisma as any, notifications as any);
  return { svc, prisma, notifications };
}

/** active 成员行 / 重名校验用的成员行（含 user） */
function mockMembers(
  prisma: any,
  activeIds: string[],
  nameRows: Array<{ userId: string; nickname: string; accountName: string; isPlaceholder?: boolean }>,
) {
  prisma.groupMember.findMany.mockImplementation(async (args: any) => {
    if (args?.where?.status === 'active') {
      return activeIds.map((userId) => ({ userId }));
    }
    return nameRows.map((r) => ({
      userId: r.userId,
      status: 'active',
      user: {
        id: r.userId,
        nickname: r.nickname,
        accountName: r.accountName,
        isPlaceholder: r.isPlaceholder ?? false,
      },
    }));
  });
}

describe('GroupsService.addPlaceholderMember（非注册成员）', () => {
  it('仅群主可添加：非群主 → Forbidden，且不创建任何账号', async () => {
    const { svc, prisma } = makeSvc();
    mockMembers(prisma, ['u_owner'], []);
    await expect(
      svc.addPlaceholderMember('u_member', 'g1', '老王'),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.user.create).not.toHaveBeenCalled();
  });

  it('创建占位账号：账户名前缀 ~guest_、isPlaceholder=true、密码为不可用哈希、通知不含占位账号', async () => {
    const { svc, prisma, notifications } = makeSvc();
    mockMembers(prisma, ['u_owner', 'u_member', 'u_guest'], [
      { userId: 'u_owner', nickname: '老大', accountName: 'ph_owner' },
    ]);
    prisma.user.create.mockResolvedValue({
      id: 'u_guest',
      createdAt: new Date('2026-09-12T00:00:00Z'),
    });

    const res = await svc.addPlaceholderMember('u_owner', 'g1', '  老王\n');

    expect(res).toMatchObject({
      userId: 'u_guest',
      nickname: '老王',
      accountName: '',
      isPlaceholder: true,
      status: 'active',
    });
    const created = prisma.user.create.mock.calls[0][0].data;
    expect(created.accountName).toMatch(/^~guest_/);
    expect(created.nickname).toBe('老王');
    expect(created.isPlaceholder).toBe(true);
    expect(created.passwordHash).toMatch(/^\$2a\$12\$/);
    expect(prisma.groupMember.create).toHaveBeenCalledWith({
      data: { groupId: 'g1', userId: 'u_guest', status: 'active' },
    });
    // 「新成员加入」播报：排除调用者与占位账号本人
    expect(notifications.createMany).toHaveBeenCalledWith(
      ['u_member'],
      expect.objectContaining({ type: 'member', title: '新成员加入', refId: 'g1' }),
    );
  });

  it('单群上限 50 人：active 成员已满 → Conflict，不创建账号', async () => {
    const { svc, prisma } = makeSvc();
    mockMembers(
      prisma,
      Array.from({ length: 50 }, (_, i) => `u${i}`),
      [],
    );
    await expect(
      svc.addPlaceholderMember('u_owner', 'g1', '老王'),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(prisma.user.create).not.toHaveBeenCalled();
  });

  it('群内重名（含已退出成员的显示名）→ Conflict', async () => {
    const { svc, prisma } = makeSvc();
    mockMembers(prisma, ['u_owner'], [
      { userId: 'u_left', nickname: '老王', accountName: 'laowang' },
    ]);
    await expect(
      svc.addPlaceholderMember('u_owner', 'g1', '老王'),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(prisma.user.create).not.toHaveBeenCalled();
  });
});

describe('GroupsService.renamePlaceholderMember', () => {
  it('非占位账号不可改名 → NotFound', async () => {
    const { svc, prisma } = makeSvc();
    mockMembers(prisma, ['u_owner'], []);
    prisma.user.findFirst.mockResolvedValue(null);
    await expect(
      svc.renamePlaceholderMember('u_owner', 'g1', 'u_real', '新名字'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('已被认领的占位账号不可再操作 → Conflict（群成员行已删除也能识别）', async () => {
    const { svc, prisma } = makeSvc();
    mockMembers(prisma, ['u_owner'], []);
    prisma.user.findFirst.mockResolvedValue({
      id: 'u_guest',
      nickname: '老王',
      accountName: '~guest_x',
      isPlaceholder: true,
      mergedIntoUserId: 'u_real',
      deletedAt: new Date(),
    });
    await expect(
      svc.renamePlaceholderMember('u_owner', 'g1', 'u_guest', '新名字'),
    ).rejects.toBeInstanceOf(ConflictException);
  });
});

describe('GroupsService.claimPlaceholderMember（认领合并）', () => {
  const PLACEHOLDER = {
    id: 'u_guest',
    nickname: '老王',
    accountName: '~guest_x',
    isPlaceholder: true,
    mergedIntoUserId: null,
    deletedAt: null,
  };
  const TARGET = { id: 'u_real', accountName: 'laowang', nickname: '王大爷' };

  function setupClaim() {
    const ctx = makeSvc();
    const { prisma } = ctx;
    mockMembers(prisma, ['u_owner', 'u_guest'], []);
    prisma.user.findFirst.mockImplementation(async (args: any) =>
      args?.where?.isPlaceholder === true ? PLACEHOLDER : TARGET,
    );
    // 目标已在群（加入更晚）、占位账号加入更早
    prisma.groupMember.findUnique.mockImplementation(async (args: any) => {
      const uid = args?.where?.groupId_userId?.userId;
      if (uid === 'u_guest') {
        return {
          id: 'gm_p',
          groupId: 'g1',
          userId: 'u_guest',
          status: 'active',
          joinedAt: new Date('2026-01-01T00:00:00Z'),
        };
      }
      if (uid === 'u_real') {
        return {
          id: 'gm_t',
          groupId: 'g1',
          userId: 'u_real',
          status: 'active',
          joinedAt: new Date('2026-05-01T00:00:00Z'),
        };
      }
      return null;
    });
    prisma.group.findFirst.mockResolvedValue({
      id: 'g1',
      name: '饭友群',
      ownerId: 'u_owner',
      deletedAt: null,
      defaultExemptUserIds: ['u_guest', 'u_other'],
    });
    return ctx;
  }

  it('群成员关系合并：加入时间取更早、删除占位成员行；免分摊名单替换（TEXT[]）', async () => {
    const { svc, prisma } = setupClaim();

    const res = await svc.claimPlaceholderMember('u_owner', 'g1', 'u_guest', 'u_real');

    expect(res).toMatchObject({ success: true, targetUserId: 'u_real', targetName: '王大爷' });
    expect(prisma.groupMember.update).toHaveBeenCalledWith({
      where: { id: 'gm_t' },
      data: { joinedAt: new Date('2026-01-01T00:00:00Z') },
    });
    expect(prisma.groupMember.delete).toHaveBeenCalledWith({ where: { id: 'gm_p' } });
    expect(prisma.group.update).toHaveBeenCalledWith({
      where: { id: 'g1' },
      data: { defaultExemptUserIds: ['u_real', 'u_other'] },
    });
  });

  it('定期账单模板（JSON）：userId 替换 + 重复行金额相加、免摊取 AND', async () => {
    const { svc, prisma } = setupClaim();
    prisma.regularBill.findMany.mockResolvedValue([
      {
        id: 'rb1',
        participants: [
          { userId: 'u_guest', shareAmountCents: 1000, exempt: true },
          { userId: 'u_guest', shareAmountCents: 2000 },
          { userId: 'u_other', shareAmountCents: 3000, exempt: true },
        ],
      },
    ]);

    await svc.claimPlaceholderMember('u_owner', 'g1', 'u_guest', 'u_real');

    expect(prisma.regularBill.update).toHaveBeenCalledWith({
      where: { id: 'rb1' },
      data: {
        participants: [
          { userId: 'u_real', shareAmountCents: 3000, exempt: false },
          { userId: 'u_other', shareAmountCents: 3000, exempt: true },
        ],
      },
    });
  });

  it('账单参与人冲突：份额相加、paid/exempt 取 AND，冲突行删除；垫付人改挂；pending 方案清空', async () => {
    const { svc, prisma } = setupClaim();
    prisma.billParticipant.findMany.mockResolvedValue([
      { id: 'bp_p', billId: 'b1', userId: 'u_guest', shareAmountCents: 5000, paid: true, exempt: true, paidAt: null },
      { id: 'bp_p2', billId: 'b2', userId: 'u_guest', shareAmountCents: 1000, paid: false, exempt: false, paidAt: null },
    ]);
    prisma.billParticipant.findUnique.mockImplementation(async (args: any) =>
      args?.where?.billId_userId?.billId === 'b1'
        ? { id: 'bp_t', billId: 'b1', userId: 'u_real', shareAmountCents: 7000, paid: false, exempt: true, paidAt: null }
        : null,
    );

    await svc.claimPlaceholderMember('u_owner', 'g1', 'u_guest', 'u_real');

    expect(prisma.billParticipant.update).toHaveBeenCalledWith({
      where: { id: 'bp_t' },
      data: {
        shareAmountCents: 12000,
        paid: false,
        exempt: true,
        paidAt: null,
      },
    });
    expect(prisma.billParticipant.delete).toHaveBeenCalledWith({ where: { id: 'bp_p' } });
    // 无冲突行直接改挂
    expect(prisma.billParticipant.update).toHaveBeenCalledWith({
      where: { id: 'bp_p2' },
      data: { userId: 'u_real' },
    });
    expect(prisma.bill.updateMany).toHaveBeenCalledWith({
      where: { payerId: 'u_guest' },
      data: { payerId: 'u_real' },
    });
    expect(prisma.settlement.updateMany).toHaveBeenCalledWith({
      where: { groupId: 'g1', fromUserId: 'u_guest' },
      data: { fromUserId: 'u_real' },
    });
    expect(prisma.settlement.deleteMany).toHaveBeenCalledWith({
      where: { groupId: 'g1', status: 'pending' },
    });
  });

  it('占位账号行保留 + 记录合并去向；重复认领 → Conflict', async () => {
    const { svc, prisma } = setupClaim();

    await svc.claimPlaceholderMember('u_owner', 'g1', 'u_guest', 'u_real');

    expect(prisma.user.update).toHaveBeenCalledWith({
      where: { id: 'u_guest' },
      data: { deletedAt: expect.any(Date), mergedIntoUserId: 'u_real' },
    });

    // 已认领：mergedIntoUserId 非空 → 拒绝（不是「不存在」）
    const ctx2 = setupClaim();
    ctx2.prisma.user.findFirst.mockResolvedValue({
      ...PLACEHOLDER,
      mergedIntoUserId: 'u_real',
      deletedAt: new Date(),
    });
    await expect(
      ctx2.svc.claimPlaceholderMember('u_owner', 'g1', 'u_guest', 'u_real'),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('非群主认领 → Forbidden', async () => {
    const { svc, prisma } = setupClaim();
    prisma.group.findFirst.mockResolvedValue({
      id: 'g1',
      name: '饭友群',
      ownerId: 'u_owner',
      deletedAt: null,
      defaultExemptUserIds: [],
    });
    await expect(
      svc.claimPlaceholderMember('u_other', 'g1', 'u_guest', 'u_real'),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.$transaction).toBeDefined();
  });
});

describe('GroupsService.transferOwner（非注册成员不能接手群主）', () => {
  it('目标是占位账号 → BadRequest，且不落库', async () => {
    const { svc, prisma } = makeSvc();
    prisma.groupMember.findFirst.mockResolvedValue({
      id: 'gm_guest',
      groupId: 'g1',
      userId: 'u_guest',
      status: 'active',
      user: { id: 'u_guest', isPlaceholder: true },
    });
    await expect(
      svc.transferOwner('u_owner', 'g1', 'u_guest'),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.group.update).not.toHaveBeenCalled();
  });

  it('目标是注册成员 → 正常转让', async () => {
    const { svc, prisma } = makeSvc();
    prisma.groupMember.findFirst.mockResolvedValue({
      id: 'gm_real',
      groupId: 'g1',
      userId: 'u_real',
      status: 'active',
      user: { id: 'u_real', isPlaceholder: false },
    });
    await svc.transferOwner('u_owner', 'g1', 'u_real');
    expect(prisma.group.update).toHaveBeenCalledWith({
      where: { id: 'g1' },
      data: { ownerId: 'u_real' },
    });
  });
});

describe('GroupsService.listMyGroups（memberCount 口径）', () => {
  it('memberCount 只计 active 成员：已退出成员不计入', async () => {
    const { svc, prisma } = makeSvc();
    prisma.groupMember.findMany.mockImplementation(async (args: any) => {
      if (args?.where?.userId) {
        return [
          {
            groupId: 'g1',
            joinedAt: new Date('2026-01-01T00:00:00Z'),
            group: {
              id: 'g1',
              name: '饭友群',
              ownerId: 'u_owner',
              deletedAt: null,
              defaultSplitType: 'even',
              defaultExemptUserIds: [],
              owner: { id: 'u_owner', accountName: 'ph_owner', nickname: '老大', avatarUrl: null },
            },
          },
        ];
      }
      // active 计数：只有 2 个（另有 1 个已退出）
      return [{ groupId: 'g1' }, { groupId: 'g1' }];
    });

    const list = await svc.listMyGroups('u_owner');

    expect(list).toHaveLength(1);
    expect(list[0].memberCount).toBe(2);
  });
});
