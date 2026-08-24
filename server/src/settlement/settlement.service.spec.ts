import { Test } from '@nestjs/testing';
import { PrismaService } from '../prisma/prisma.service';
import { SettlementService } from './settlement.service';

describe('SettlementService', () => {
  let service: SettlementService;
  // 一张未结清账单：A 垫付 10000 分，A/B/C 分摊（A 3333/B 3333/C 3334）
  const bill = {
    id: 'bill-1',
    groupId: 'group-1',
    payerId: 'A',
    amountCents: 10000,
    settleStatus: 'pending',
    participants: [
      { userId: 'A', shareAmountCents: 3333, paid: false },
      { userId: 'B', shareAmountCents: 3333, paid: false },
      { userId: 'C', shareAmountCents: 3334, paid: false },
    ],
  };

  const mockTx = {
    settlement: {
      deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
      createMany: jest.fn().mockResolvedValue({ count: 2 }),
    },
  };

  const prismaMock = {
    groupMember: { findFirst: jest.fn().mockResolvedValue({ id: 'gm' }) },
    bill: { findMany: jest.fn() },
    settlement: {
      findMany: jest.fn().mockResolvedValue([{ id: 's1' }, { id: 's2' }]),
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    $transaction: jest.fn(async (fn: any) => fn(mockTx)),
  };

  beforeEach(async () => {
    prismaMock.bill.findMany.mockResolvedValue([bill]);
    const moduleRef = await Test.createTestingModule({
      providers: [
        SettlementService,
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();
    service = moduleRef.get(SettlementService);
  });

  it('汇总净额并生成最少转账方案（调用纯函数）', async () => {
    const result = await service.getSettlement('me', 'group-1');
    expect(result.transferCount).toBe(2);
    expect(result.transfers).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ fromUserId: 'B', toUserId: 'A', amountCents: 3333 }),
        expect.objectContaining({ fromUserId: 'C', toUserId: 'A', amountCents: 3334 }),
      ]),
    );
    // 落库：删除旧 pending + 重建
    expect(mockTx.settlement.deleteMany).toHaveBeenCalledWith({
      where: { groupId: 'group-1', status: 'pending' },
    });
    expect(mockTx.settlement.createMany).toHaveBeenCalled();
  });

  it('净值为 0 的成员不出现在方案中（全结清→空方案）', async () => {
    const billAllPaid = {
      ...bill,
      participants: [
        { userId: 'A', shareAmountCents: 3333, paid: true },
        { userId: 'B', shareAmountCents: 3333, paid: true },
        { userId: 'C', shareAmountCents: 3334, paid: true },
      ],
    };
    prismaMock.bill.findMany.mockResolvedValue([billAllPaid]);
    const result = await service.getSettlement('me', 'group-1');
    expect(result.transferCount).toBe(0);
    expect(result.transfers).toEqual([]);
  });

  it('markPaid 校验群成员并将状态置为 paid', async () => {
    prismaMock.settlement.findUnique.mockResolvedValue({
      id: 's1',
      groupId: 'group-1',
      status: 'pending',
    });
    prismaMock.settlement.update.mockResolvedValue({ id: 's1', status: 'paid' });
    const res = await service.markPaid('me', 's1');
    expect(prismaMock.settlement.update).toHaveBeenCalledWith({
      where: { id: 's1' },
      data: { status: 'paid' },
    });
    expect(res.status).toBe('paid');
  });
});
