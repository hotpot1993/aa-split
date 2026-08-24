import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import { Workbook } from 'exceljs';
import { PrismaService } from '../prisma/prisma.service';
import { formatDateDay } from '../common/date.util';

export interface ExportFile {
  buffer: Buffer;
  filename: string;
  contentType: string;
}

const CSV_HEADERS = ['日期', '标题', '群组', '分类', '金额(元)', '垫付人', '我的分摊(元)', '状态'];

@Injectable()
export class ExportService {
  private readonly logger = new Logger(ExportService.name);

  constructor(private readonly prisma: PrismaService) {}

  async exportUserData(userId: string, format: 'xlsx' | 'csv'): Promise<ExportFile> {
    const bills = await this.prisma.bill.findMany({
      where: {
        deletedAt: null,
        OR: [{ payerId: userId }, { participants: { some: { userId } } }],
      },
      include: {
        group: { select: { name: true } },
        participants: { where: { userId } },
      },
      orderBy: { billDate: 'desc' },
    });

    const rows = bills.map((b: any) => {
      const myShare = b.participants?.[0]?.shareAmountCents ?? 0;
      return [
        formatDateDay(b.billDate),
        b.title,
        b.group?.name ?? '',
        b.category,
        (b.amountCents / 100).toFixed(2),
        b.payerId === userId ? '我' : b.payerId,
        (myShare / 100).toFixed(2),
        b.settleStatus,
      ];
    });

    if (format === 'csv') {
      return this.buildCsv(rows);
    }
    if (format === 'xlsx') {
      return this.buildXlsx(rows);
    }
    throw new BadRequestException('不支持的导出格式');
  }

  private buildCsv(rows: string[][]): ExportFile {
    const esc = (v: string) => (/[",\n]/.test(v) ? `"${v.replace(/"/g, '""')}"` : v);
    const lines = [CSV_HEADERS.map(esc).join(','), ...rows.map((r) => r.map(esc).join(','))];
    return {
      buffer: Buffer.from('\ufeff' + lines.join('\r\n'), 'utf-8'), // BOM 便于 Excel 识别 UTF-8
      filename: 'my-bills.csv',
      contentType: 'text/csv; charset=utf-8',
    };
  }

  private async buildXlsx(rows: string[][]): Promise<ExportFile> {
    const workbook = new Workbook();
    const sheet = workbook.addWorksheet('我的账单');
    sheet.addRow(CSV_HEADERS);
    for (const r of rows) sheet.addRow(r);
    sheet.columns.forEach((col) => {
      col.width = 18;
    });
    const buffer = await workbook.xlsx.writeBuffer();
    return {
      buffer: Buffer.from(buffer),
      filename: 'my-bills.xlsx',
      contentType:
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    };
  }
}
