import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

export interface StatisticsResult {
  totalAmountCents: number;
  billCount: number;
  byMonth: Array<{ month: number; amountCents: number }>;
  byCategory: Array<{ category: string; amountCents: number; count: number }>;
}

@Injectable()
export class StatisticsService {
  constructor(private readonly prisma: PrismaService) {}

  async statistics(userId: string, year: number): Promise<StatisticsResult> {
    const start = new Date(year, 0, 1);
    const end = new Date(year + 1, 0, 1);

    const bills = await this.prisma.bill.findMany({
      where: {
        deletedAt: null,
        billDate: { gte: start, lt: end },
        OR: [{ payerId: userId }, { participants: { some: { userId } } }],
      },
      select: { amountCents: true, category: true, billDate: true },
    });

    const totalAmountCents = bills.reduce((s, b) => s + b.amountCents, 0);

    const byMonthMap = new Map<number, number>();
    const byCategoryMap = new Map<string, { amountCents: number; count: number }>();
    for (const b of bills) {
      const month = b.billDate.getMonth() + 1;
      byMonthMap.set(month, (byMonthMap.get(month) ?? 0) + b.amountCents);
      const cat = byCategoryMap.get(b.category) ?? { amountCents: 0, count: 0 };
      cat.amountCents += b.amountCents;
      cat.count += 1;
      byCategoryMap.set(b.category, cat);
    }

    const byMonth = Array.from({ length: 12 }, (_, i) => ({
      month: i + 1,
      amountCents: byMonthMap.get(i + 1) ?? 0,
    }));
    const byCategory = [...byCategoryMap.entries()].map(([category, v]) => ({
      category,
      amountCents: v.amountCents,
      count: v.count,
    }));

    return { totalAmountCents, billCount: bills.length, byMonth, byCategory };
  }
}
