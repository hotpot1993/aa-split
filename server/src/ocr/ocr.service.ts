import {
  BadGatewayException,
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { InjectQueue } from '@nestjs/bullmq';
import { Queue } from 'bullmq';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { NotificationSseService } from '../notifications/notification-sse.service';

export interface OcrJobData {
  kind: 'preupload' | 'p33';
  userId: string; // 上传者（SSE 推送对象）
  billId?: string;
  receiptId?: string;
  uploadId?: string;
  objectKey: string;
}

interface OcrWorkerResult {
  amount_cents: number | null;
  currency: string;
  confidence: number | null;
  method: string;
  matched_text: string | null;
  warning: string | null;
}

/**
 * 小票 OCR：上传 → 队列 → 调 ocr-worker → 写回金额 → SSE 通知上传者。
 * 识别失败不阻塞上传链路（D10 静默 + 页面可重试）。
 */
@Injectable()
export class OcrService {
  private readonly logger = new Logger(OcrService.name);
  private readonly workerUrl: string;

  constructor(
    private readonly prisma: PrismaService,
    private readonly storageService: StorageService,
    private readonly sse: NotificationSseService,
    @InjectQueue('receipt-ocr') private readonly queue: Queue,
  ) {
    this.workerUrl =
      process.env.OCR_WORKER_URL || 'http://127.0.0.1:8000';
  }

  // ---------------- 入队 ----------------

  /** 草稿预上传：记账页拍/选后立刻上传暂存并识别（D4） */
  async enqueuePreUpload(uploadId: string, userId: string, objectKey: string) {
    this.queue.add(
      'ocr',
      { kind: 'preupload', userId, uploadId, objectKey },
      { attempts: 2, backoff: { type: 'exponential', delay: 1000 }, removeOnComplete: 100, removeOnFail: 500 },
    );
  }

  /** 草稿预上传：暂存对象 → 入队识别 → 返回 uploadId（账单创建时绑定） */
  async preUpload(userId: string, file: Express.Multer.File) {
    if (!file) throw new BadRequestException('缺少凭证文件');
    const stored = await this.storageService.upload(file);
    const upload = await this.prisma.receiptUpload.create({
      data: {
        userId,
        objectKey: stored.objectKey,
        expiresAt: new Date(Date.now() + 24 * 3600 * 1000),
      },
    });
    await this.enqueuePreUpload(upload.id, userId, stored.objectKey);
    return { uploadId: upload.id, url: stored.url };
  }

  /** P33 凭证上传/替换成功后即时识别（D5） */
  async enqueueReceipt(receiptId: string, billId: string, userId: string, objectKey: string) {
    this.queue.add(
      'ocr',
      { kind: 'p33', userId, billId, receiptId, objectKey },
      { attempts: 2, backoff: { type: 'exponential', delay: 1000 }, removeOnComplete: 100, removeOnFail: 500 },
    );
  }

  // ---------------- 执行 ----------------

  /** 处理一个 OCR 任务：读对象 → 调 worker → 写回 → SSE 推送 */
  async runOcr(data: OcrJobData) {
    const row =
      data.kind === 'preupload'
        ? await this.prisma.receiptUpload.findUnique({ where: { id: data.uploadId! } })
        : await this.prisma.receipt.findUnique({ where: { id: data.receiptId! } });

    if (!row) {
      this.logger.warn(`OCR 任务对象不存在: ${data.kind} ${data.receiptId ?? data.uploadId}`);
      return;
    }

    if (data.kind === 'preupload') {
      await this.prisma.receiptUpload.update({
        where: { id: data.uploadId! },
        data: { ocrStatus: 'processing' },
      });
    } else {
      await this.prisma.receipt.update({
        where: { id: data.receiptId! },
        data: { ocrStatus: 'processing' },
      });
    }

    let result: OcrWorkerResult;
    try {
      result = await this.callWorker(data.objectKey);
    } catch (e: any) {
      // 供 BullMQ 重试（attempts=2）；重试耗尽后由 failed 事件标 failed
      throw e;
    }

    const amountCents = result.amount_cents;
    const confidence = result.confidence;
    const currency = result.currency;

    if (data.kind === 'preupload') {
      const updated = await this.prisma.receiptUpload.update({
        where: { id: data.uploadId! },
        data: {
          ocrStatus: 'success',
          amountCents,
          confidence,
          currency,
        },
      });
      this.logger.log(`预上传识别完成 upload=${updated.id} amount=${amountCents}`);
      this.sse.push(data.userId, {
        type: 'receipt-ocr',
        title: '',
        body: '',
        refType: null,
        refId: null,
        data: {
          kind: 'preupload',
          uploadId: data.uploadId,
          amountCents,
          currency,
          confidence,
          method: result.method,
          matchedText: result.matched_text,
          warning: result.warning,
        },
      });
      return updated;
    }

    const updated = await this.prisma.receipt.update({
      where: { id: data.receiptId! },
      data: {
        ocrStatus: 'success',
        amountCents,
        confidence,
        currency,
      },
    });
    this.logger.log(`凭证识别完成 receipt=${updated.id} amount=${amountCents}`);
    this.sse.push(data.userId, {
      type: 'receipt-ocr',
      title: '',
      body: '',
      refType: data.billId ? 'bill' : null,
      refId: data.billId ?? null,
      data: {
        kind: 'p33',
        receiptId: data.receiptId,
        billId: data.billId,
        amountCents,
        currency,
        confidence,
        method: result.method,
        matchedText: result.matched_text,
        warning: result.warning,
      },
    });
    return updated;
  }

  /** 调 Python ocr-worker（15s 超时；multipart 传图片字节，D19） */
  private async callWorker(objectKey: string): Promise<OcrWorkerResult> {
    const bytes = await this.storageService.read(objectKey);
    const form = new FormData();
    form.append('file', new Blob([new Uint8Array(bytes)]), objectKey);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 15000);
    try {
      const resp = await fetch(`${this.workerUrl}/v1/ocr`, {
        method: 'POST',
        body: form,
        signal: controller.signal,
      });
      if (!resp.ok) {
        throw new BadGatewayException(`ocr-worker ${resp.status}`);
      }
      return (await resp.json()) as OcrWorkerResult;
    } finally {
      clearTimeout(timer);
    }
  }

  /** 重试接口的权限校验并重新入队（P33 上传者/创建者/垫付人/群主） */
  async retryOcr(userId: string, billId: string, receiptId: string) {
    const receipt = await this.prisma.receipt.findFirst({
      where: { id: receiptId, billId },
      include: { bill: { include: { group: { select: { ownerId: true } } } } },
    });
    if (!receipt) throw new NotFoundException('凭证不存在');
    const bill = receipt.bill;
    const allowed =
      bill.creatorId === userId || bill.payerId === userId || bill.group.ownerId === userId;
    if (!allowed) {
      throw new NotFoundException('凭证不存在');
    }
    await this.prisma.receipt.update({
      where: { id: receiptId },
      data: { ocrStatus: 'pending', ocrError: null, ocrAttempts: 0 },
    });
    await this.enqueueReceipt(receiptId, billId, userId, receipt.objectKey);
    return { success: true };
  }

  /** 识别失败标记（重试耗尽后由 failed 事件调用） */
  async markUploadFailed(uploadId: string, error: string) {
    await this.prisma.receiptUpload.update({
      where: { id: uploadId },
      data: { ocrStatus: 'failed', ocrError: error.slice(0, 200) },
    });
  }

  async markReceiptFailed(receiptId: string, error: string) {
    await this.prisma.receipt.update({
      where: { id: receiptId },
      data: { ocrStatus: 'failed', ocrError: error.slice(0, 200), ocrAttempts: { increment: 0 } },
    });
  }

  /** 识别失败（重试耗尽）：SSE 推送失败标记，页面据此结束「识别中」并展示「识别失败/重试」 */
  notifyFailed(data: OcrJobData, error: string) {
    this.sse.push(data.userId, {
      type: 'receipt-ocr',
      title: '',
      body: '',
      refType: data.billId ? 'bill' : null,
      refId: data.billId ?? null,
      data: {
        kind: data.kind,
        ...(data.kind === 'preupload'
          ? { uploadId: data.uploadId }
          : { receiptId: data.receiptId, billId: data.billId }),
        amountCents: null,
        currency: null,
        confidence: null,
        ocrStatus: 'failed',
        error: error.slice(0, 200),
      },
    });
  }

  // ---------------- 清理（每日 03:00） ----------------

  /** 回收超时未绑定的暂存凭证（object 删除 + status=expired） */
  async cleanupExpired() {
    const expired = await this.prisma.receiptUpload.updateMany({
      where: { status: 'pending', expiresAt: { lt: new Date() } },
      data: { status: 'expired' },
    });
    if (expired.count === 0) return { cleaned: 0 };

    const rows = await this.prisma.receiptUpload.findMany({
      where: { status: 'expired', objectKey: { not: '' } },
      select: { objectKey: true },
      take: 500,
    });
    for (const r of rows) {
      void this.storageService.remove(r.objectKey);
    }
    this.logger.log(`暂存凭证回收：${expired.count} 条`);
    return { cleaned: expired.count };
  }
}
