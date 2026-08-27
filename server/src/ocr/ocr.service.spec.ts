import { Test } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { getQueueToken } from '@nestjs/bullmq';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { NotificationSseService } from '../notifications/notification-sse.service';
import { OcrService } from './ocr.service';

describe('OcrService', () => {
  let service: OcrService;
  let queueMock: { add: jest.Mock };
  let prismaMock: any;
  let storageMock: {
    read: jest.Mock;
    upload: jest.Mock;
    remove: jest.Mock;
  };
  let sseMock: { push: jest.Mock };
  let originalFetch: any;
  const originalUrl = process.env.OCR_WORKER_URL;

  const workerResult = {
    amount_cents: 8800,
    currency: 'CNY',
    confidence: 0.97,
    method: 'keyword',
    matched_text: '合计 ￥88.00',
    warning: null,
  };

  beforeEach(async () => {
    queueMock = { add: jest.fn().mockResolvedValue({ id: 'j1' }) };
    prismaMock = {
      receiptUpload: {
        findUnique: jest.fn(),
        create: jest.fn(),
        update: jest.fn(),
        updateMany: jest.fn(),
        findMany: jest.fn(),
      },
      receipt: {
        findUnique: jest.fn(),
        findFirst: jest.fn(),
        update: jest.fn(),
      },
    };
    storageMock = {
      read: jest.fn(),
      upload: jest.fn(),
      remove: jest.fn().mockResolvedValue(undefined),
    };
    sseMock = { push: jest.fn() };

    process.env.OCR_WORKER_URL = 'http://ocr-test:8000';
    originalFetch = (global as any).fetch;

    const moduleRef = await Test.createTestingModule({
      providers: [
        OcrService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: StorageService, useValue: storageMock },
        { provide: NotificationSseService, useValue: sseMock },
        { provide: getQueueToken('receipt-ocr'), useValue: queueMock },
      ],
    }).compile();
    service = moduleRef.get(OcrService);
  });

  afterEach(() => {
    (global as any).fetch = originalFetch;
  });

  afterAll(() => {
    if (originalUrl === undefined) {
      delete process.env.OCR_WORKER_URL;
    } else {
      process.env.OCR_WORKER_URL = originalUrl;
    }
  });

  describe('preUpload（D4 预上传）', () => {
    it('暂存对象 → 建行 → 入队识别 → 返回 uploadId', async () => {
      storageMock.upload.mockResolvedValue({
        objectKey: 'a.jpg',
        url: '/uploads/a.jpg',
      });
      prismaMock.receiptUpload.create.mockResolvedValue({ id: 'u1' });

      const res = await service.preUpload('user-1', {
        originalname: 'x.jpg',
      } as any);
      expect(res).toEqual({ uploadId: 'u1', url: '/uploads/a.jpg' });
      expect(prismaMock.receiptUpload.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            userId: 'user-1',
            objectKey: 'a.jpg',
            // 24h 过期回收
            expiresAt: expect.any(Date),
          }),
        }),
      );
      expect(queueMock.add).toHaveBeenCalledWith(
        'ocr',
        {
          kind: 'preupload',
          userId: 'user-1',
          uploadId: 'u1',
          objectKey: 'a.jpg',
        },
        expect.objectContaining({ attempts: 2 }),
      );
    });
  });

  describe('runOcr（识别执行 → 写回 → SSE）', () => {
    it('p33 成功：processing → success + SSE 推送', async () => {
      prismaMock.receipt.findUnique.mockResolvedValue({
        id: 'r1',
        billId: 'b1',
        objectKey: 'a.jpg',
      });
      prismaMock.receipt.update.mockResolvedValue({});
      storageMock.read.mockResolvedValue(Buffer.from('img'));
      (global as any).fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => workerResult,
      });

      await service.runOcr({
        kind: 'p33',
        userId: 'user-1',
        billId: 'b1',
        receiptId: 'r1',
        objectKey: 'a.jpg',
      });

      // 第一次置 processing，最后一次写 success + 金额
      expect(prismaMock.receipt.update).toHaveBeenNthCalledWith(
        1,
        expect.objectContaining({ data: { ocrStatus: 'processing' } }),
      );
      expect(prismaMock.receipt.update).toHaveBeenLastCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            ocrStatus: 'success',
            amountCents: 8800,
            confidence: 0.97,
            currency: 'CNY',
          }),
        }),
      );
      expect(sseMock.push).toHaveBeenCalledWith(
        'user-1',
        expect.objectContaining({
          type: 'receipt-ocr',
          refType: 'bill',
          refId: 'b1',
          data: expect.objectContaining({
            kind: 'p33',
            receiptId: 'r1',
            amountCents: 8800,
          }),
        }),
      );
      // 字节转发给 worker（D19）
      expect(storageMock.read).toHaveBeenCalledWith('a.jpg');
    });

    it('预上传成功走 upload 写回与 push', async () => {
      prismaMock.receiptUpload.findUnique.mockResolvedValue({
        id: 'u1',
        objectKey: 'a.jpg',
      });
      prismaMock.receiptUpload.update.mockResolvedValue({});
      storageMock.read.mockResolvedValue(Buffer.from('img'));
      (global as any).fetch = jest.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          ...workerResult,
          amount_cents: null,
          confidence: null,
        }),
      });

      const res = await service.runOcr({
        kind: 'preupload',
        userId: 'user-1',
        uploadId: 'u1',
        objectKey: 'a.jpg',
      });
      expect(res).toBeDefined();
      expect(sseMock.push).toHaveBeenCalledWith(
        'user-1',
        expect.objectContaining({
          data: expect.objectContaining({
            kind: 'preupload',
            uploadId: 'u1',
            amountCents: null,
          }),
        }),
      );
    });

    it('worker 失败：抛错（交 BullMQ 重试），不推 SSE', async () => {
      prismaMock.receipt.findUnique.mockResolvedValue({
        id: 'r1',
        billId: 'b1',
        objectKey: 'a.jpg',
      });
      prismaMock.receipt.update.mockResolvedValue({});
      storageMock.read.mockResolvedValue(Buffer.from('img'));
      (global as any).fetch = jest.fn().mockResolvedValue({
        ok: false,
        status: 502,
        json: async () => ({}),
      });

      await expect(
        service.runOcr({
          kind: 'p33',
          userId: 'user-1',
          billId: 'b1',
          receiptId: 'r1',
          objectKey: 'a.jpg',
        }),
      ).rejects.toThrow();
      expect(sseMock.push).not.toHaveBeenCalled();
    });
  });

  describe('retryOcr（页面重试按钮）', () => {
    const receiptRow = {
      id: 'r1',
      billId: 'b1',
      objectKey: 'a.jpg',
      creatorId: 'user-1',
      payerId: 'user-2',
      bill: { creatorId: 'user-1', payerId: 'user-2', group: { ownerId: 'user-9' } },
    };

    it('创建者可重试：重置状态并重新入队', async () => {
      prismaMock.receipt.findFirst.mockResolvedValue(receiptRow);
      prismaMock.receipt.update.mockResolvedValue({});

      const res = await service.retryOcr('user-1', 'b1', 'r1');
      expect(res).toEqual({ success: true });
      expect(prismaMock.receipt.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            ocrStatus: 'pending',
            ocrError: null,
            ocrAttempts: 0,
          }),
        }),
      );
      expect(queueMock.add).toHaveBeenCalledWith(
        'ocr',
        expect.objectContaining({ kind: 'p33', receiptId: 'r1' }),
        expect.anything(),
      );
    });

    it('非创建者/垫付人/群主 → 404（不暴露存在性）', async () => {
      prismaMock.receipt.findFirst.mockResolvedValue(receiptRow);
      await expect(service.retryOcr('outsider', 'b1', 'r1')).rejects.toThrow(
        NotFoundException,
      );
      expect(queueMock.add).not.toHaveBeenCalled();
    });
  });

  describe('cleanupExpired（每日回收）', () => {
    it('无过期暂存：不动对象', async () => {
      prismaMock.receiptUpload.updateMany.mockResolvedValue({ count: 0 });
      const res = await service.cleanupExpired();
      expect(res).toEqual({ cleaned: 0 });
      expect(prismaMock.receiptUpload.findMany).not.toHaveBeenCalled();
    });

    it('有过期暂存：标记 expired 并删除对象', async () => {
      prismaMock.receiptUpload.updateMany.mockResolvedValue({ count: 2 });
      prismaMock.receiptUpload.findMany.mockResolvedValue([
        { objectKey: 'a.jpg' },
        { objectKey: 'b.jpg' },
      ]);
      const res = await service.cleanupExpired();
      expect(res).toEqual({ cleaned: 2 });
      expect(storageMock.remove).toHaveBeenCalledTimes(2);
      expect(storageMock.remove).toHaveBeenCalledWith('a.jpg');
      expect(storageMock.remove).toHaveBeenCalledWith('b.jpg');
    });
  });

  describe('失败标记（重试耗尽）', () => {
    it('markReceiptFailed 写 failed + error', async () => {
      prismaMock.receipt.update.mockResolvedValue({});
      await service.markReceiptFailed('r1', 'boom');
      expect(prismaMock.receipt.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ ocrStatus: 'failed', ocrError: 'boom' }),
        }),
      );
    });

    it('markUploadFailed 写 failed（截断 200 字符）', async () => {
      prismaMock.receiptUpload.update.mockResolvedValue({});
      await service.markUploadFailed('u1', 'x'.repeat(500));
      expect(prismaMock.receiptUpload.update).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({ ocrStatus: 'failed', ocrError: 'x'.repeat(200) }),
        }),
      );
    });
  });
});
