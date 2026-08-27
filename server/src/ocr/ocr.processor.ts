import { Logger, OnModuleInit } from '@nestjs/common';
import { InjectQueue, OnWorkerEvent, Processor, WorkerHost } from '@nestjs/bullmq';
import { Job, Queue } from 'bullmq';
import { OcrService, OcrJobData } from './ocr.service';

/**
 * 小票 OCR 处理器：消费 receipt-ocr 队列。
 * - 失败重试 1 次（attempts=2 由入队方指定）；重试耗尽 → failed 事件标记 ocrStatus=failed（页面可重试）
 * - 每日 03:00 重复任务：回收超时未绑定的暂存凭证（沿用 regular-bills 的惰性降级写法）
 */
@Processor('receipt-ocr')
export class OcrProcessor extends WorkerHost implements OnModuleInit {
  private readonly logger = new Logger(OcrProcessor.name);

  constructor(
    private readonly ocrService: OcrService,
    @InjectQueue('receipt-ocr') private readonly queue: Queue,
  ) {
    super();
  }

  async onModuleInit() {
    try {
      const task = this.queue.add(
        'cleanup',
        {},
        { repeat: { pattern: '0 3 * * *' }, removeOnComplete: 100, removeOnFail: 100 },
      );
      const ok = await Promise.race([
        task.then(() => true).catch(() => false),
        new Promise<boolean>((resolve) => setTimeout(() => resolve(false), 3000)),
      ]);
      this.logger.log(
        ok ? '已注册暂存凭证每日回收任务（03:00）' : '注册回收任务超时（Redis 未运行？）：服务继续启动',
      );
    } catch (e: any) {
      this.logger.warn(`注册回收任务失败（Redis 可能未运行）：${e?.message}`);
    }
  }

  async process(job: Job<OcrJobData | { kind: 'cleanup' }>): Promise<any> {
    if (job.data.kind === 'cleanup') {
      const res = await this.ocrService.cleanupExpired();
      return res;
    }
    return this.ocrService.runOcr(job.data as OcrJobData);
  }

  /** 重试耗尽：标记识别失败 + 推送失败事件（页面结束「识别中」展示「识别失败/重试」；凭证本身不受影响） */
  @OnWorkerEvent('failed')
  async onFailed(job: Job<OcrJobData | { kind: 'cleanup' }>, err: Error) {
    const data = job.data;
    if (data.kind === 'cleanup') return;
    this.logger.warn(`OCR 任务失败（已重试 1 次）：${data.kind} ${data.receiptId ?? data.uploadId} ${err.message}`);
    try {
      if (data.kind === 'preupload') {
        await this.ocrService.markUploadFailed(data.uploadId!, err.message);
      } else {
        await this.ocrService.markReceiptFailed(data.receiptId!, err.message);
      }
      // 推送失败事件：页面结束「识别中」并展示「识别失败/重试」（与成功事件同一条 SSE 通道）
      this.ocrService.notifyFailed(data, err.message);
    } catch (e: any) {
      this.logger.warn(`标记 OCR 失败状态出错（忽略）：${e?.message}`);
    }
  }
}
