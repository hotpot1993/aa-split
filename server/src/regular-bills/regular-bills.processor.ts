import { Logger, OnModuleInit } from '@nestjs/common';
import { InjectQueue, Processor } from '@nestjs/bullmq';
import { WorkerHost } from '@nestjs/bullmq';
import { Job, Queue } from 'bullmq';
import { RegularBillsService } from './regular-bills.service';

/**
 * 定期账单处理器：每日 03:00（Asia/Shanghai）扫描到期定期账单并生成账单副本。
 * Redis 不可用时惰性降级：注册重复任务失败仅告警，进程不崩溃。
 */
@Processor('regular-bills')
export class RegularBillsProcessor extends WorkerHost implements OnModuleInit {
  private readonly logger = new Logger(RegularBillsProcessor.name);

  constructor(
    private readonly regularBillsService: RegularBillsService,
    @InjectQueue('regular-bills') private readonly queue: Queue,
  ) {
    super();
  }

  async onModuleInit() {
    try {
      const task = this.queue.add(
        'process',
        {},
        { repeat: { pattern: '0 3 * * *' } }, // 每日 03:00
      );
      // Redis 未运行时 ioredis(maxRetriesPerRequest=null) 会永久排队，
      // 用 3s 超时兜底保证进程正常启动（惰性降级：Redis 就绪后重连并生效）。
      const ok = await Promise.race([
        task.then(() => true).catch(() => false),
        new Promise<boolean>((resolve) => setTimeout(() => resolve(false), 3000)),
      ]);
      if (ok) {
        this.logger.log('已注册定期账单每日扫描任务（03:00）');
      } else {
        this.logger.warn('注册定期扫描任务超时（Redis 未运行？）：服务继续启动，Redis 就绪后重启生效');
      }
    } catch (e: any) {
      this.logger.warn(`注册定期扫描任务失败（Redis 可能未运行）：${e?.message}`);
    }
  }

  async process(_job: Job): Promise<any> {
    this.logger.log('开始扫描定期账单');
    const result = await this.regularBillsService.processDueRegularBills();
    this.logger.log(`定期账单扫描完成，生成 ${result.generated} 笔`);
    return result;
  }
}
