/**
 * 小票 OCR 契约测试（无数据库）：注册 → 建群 → 预上传（排队识别）→ 记账绑定暂存 →
 * P33 上传（排队识别）→ 重试识别权限（404 越权 / 创建者成功）。
 *
 * 与 app.e2e-spec.ts 同一套惯例：Test.createTestingModule 加载真实模块，
 * 仅 PrismaService 替换为内存 FakePrisma、BullMQ 队列替换为假队列，
 * 存储（StorageService local 模式）、SSE（内存订阅器）、鉴权/限流全部真实。
 */
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { getQueueToken } from '@nestjs/bullmq';
import request from 'supertest';
import * as os from 'os';
import * as path from 'path';

import { AuthModule } from '../src/auth/auth.module';
import { BillsModule } from '../src/bills/bills.module';
import { GroupsModule } from '../src/groups/groups.module';
import { NotificationsModule } from '../src/notifications/notifications.module';
import { OcrModule } from '../src/ocr/ocr.module';
import { PrismaModule } from '../src/prisma/prisma.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { StorageModule } from '../src/storage/storage.module';
import { UsersModule } from '../src/users/users.module';
import { AppVersionModule } from '../src/app-version/app-version.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { JwtAuthGuard } from '../src/common/guards/jwt-auth.guard';
import { TransformInterceptor } from '../src/common/interceptors/transform.interceptor';
import { OcrProcessor } from '../src/ocr/ocr.processor';
import { FakePrisma } from './fake-prisma';

describe('小票 OCR 链路 e2e（预上传→绑定→P33 识别→重试权限）(e2e)', () => {
  let app: INestApplication;
  let fake: FakePrisma;
  let queueAdd: jest.Mock;

  let alice: { token: string; id: string };
  let bobId: string;
  let groupId: string;

  beforeAll(async () => {
    process.env.UPLOAD_DIR = path.join(os.tmpdir(), 'aa-e2e-ocr-uploads');
    process.env.JWT_ACCESS_SECRET = 'e2e-access-secret';
    process.env.JWT_REFRESH_SECRET = 'e2e-refresh-secret';
    process.env.SWAGGER_ENABLED = 'false';

    fake = new FakePrisma();
    queueAdd = jest.fn().mockResolvedValue({ id: 'job-1' });

    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({ isGlobal: true, envFilePath: '.env' }),
        JwtModule.registerAsync({
          global: true,
          inject: [ConfigService],
          useFactory: (cfg: ConfigService) => ({
            secret: cfg.get<string>('JWT_ACCESS_SECRET') || 'e2e-access-secret',
          }),
        }),
        ThrottlerModule.forRoot([{ name: 'default', ttl: 60000, limit: 1000 }]),
        PrismaModule,
        StorageModule,
        UsersModule,
        AuthModule,
        GroupsModule,
        BillsModule,
        NotificationsModule,
        OcrModule,
        AppVersionModule,
      ],
      providers: [
        { provide: APP_GUARD, useClass: ThrottlerGuard },
        { provide: APP_GUARD, useClass: JwtAuthGuard },
        { provide: APP_INTERCEPTOR, useClass: TransformInterceptor },
        { provide: APP_FILTER, useClass: AllExceptionsFilter },
      ],
    })
      .overrideProvider(PrismaService)
      .useValue(fake)
      .overrideProvider(getQueueToken('receipt-ocr'))
      .useValue({ add: queueAdd })
      // 处理器启动会创建 BullMQ Worker → 连接 Redis；e2e 无 Redis，替换为空壳
      .overrideProvider(OcrProcessor)
      .useValue({
        onModuleInit: () => Promise.resolve(),
        process: async () => undefined,
      })
      .compile();

    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        transform: true,
        transformOptions: { enableImplicitConversion: true },
      }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  const server = () => app.getHttpServer();

  async function register(accountName: string, password: string, nickname: string) {
    const res = await request(server())
      .post('/api/v1/auth/register')
      .send({
        accountName,
        password,
        nickname,
        securityQuestion: '你最好的朋友？',
        securityAnswer: '小红',
      })
      .expect(201);
    return {
      token: res.body.data.accessToken as string,
      id: res.body.data.user.id as string,
    };
  }

  it('准备：注册双用户 + 建群 + 邀请', async () => {
    alice = await register('ocr_alice', 'abc123ABC', '爱丽丝');
    const bob = await register('ocr_bob', 'def456DEF', '鲍勃');
    bobId = bob.id;

    const groupRes = await request(server())
      .post('/api/v1/groups')
      .set('Authorization', `Bearer ${alice.token}`)
      .send({ name: 'OCR测试群' })
      .expect(201);
    groupId = groupRes.body.data.id as string;

    await request(server())
      .post('/api/v1/groups/join')
      .set('Authorization', `Bearer ${bob.token}`)
      .send({ inviteCode: groupRes.body.data.inviteCode })
      .expect(201);
  });

  it('D4 预上传：POST /receipts/pre-upload → 暂存行 + 入队识别', async () => {
    const res = await request(server())
      .post('/api/v1/receipts/pre-upload')
      .set('Authorization', `Bearer ${alice.token}`)
      .attach('file', Buffer.from('fake-image-bytes'), 'receipt.jpg')
      .expect(201);
    const { uploadId, url } = res.body.data as { uploadId: string; url: string };
    expect(uploadId).toBeTruthy();
    expect(url).toMatch(/^\/uploads\//);

    // 暂存行落库（身份/状态/24h 过期）
    const rows = fake.rowsOf('receiptUpload');
    const row = rows.find((r) => r.id === uploadId);
    expect(row).toBeDefined();
    expect(row!.userId).toBe(alice.id);
    expect(row!.status).toBe('pending');
    expect(row!.expiresAt.getTime()).toBeGreaterThan(Date.now() + 23 * 3600 * 1000);

    // 入队（attempts=2 一次重试）
    expect(queueAdd).toHaveBeenCalledWith(
      'ocr',
      expect.objectContaining({ kind: 'preupload', uploadId, userId: alice.id }),
      expect.objectContaining({ attempts: 2 }),
    );
  });

  it('D4 绑定：创建账单带 receiptUploadIds → 凭证转正 + 暂存标记 bound', async () => {
    const uploadRow = fake.rowsOf('receiptUpload').find(
      (r) => r.userId === alice.id && r.status === 'pending',
    );
    expect(uploadRow).toBeDefined();

    const billRes = await request(server())
      .post('/api/v1/bills')
      .set('Authorization', `Bearer ${alice.token}`)
      .send({
        groupId,
        title: '小票记账',
        location: '楼下',
        amountCents: 8800,
        billDate: '2026-08-24',
        category: 'food',
        splitType: 'even',
        payerId: alice.id,
        participants: [{ userId: alice.id }, { userId: bobId }],
        receiptUploadIds: [uploadRow!.id],
      })
      .expect(201);

    const bill = billRes.body.data;
    expect(bill.receipts).toHaveLength(1);
    const bound = bill.receipts[0];
    expect(bound.billId).toBe(bill.id);
    expect(bound.url).toMatch(/^\/uploads\//);
    expect(bound.ocrStatus).toBe('pending');

    // 暂存已绑定；凭证行的 objectKey 与暂存一致（图片未重新上传）
    expect(fake.rowsOf('receiptUpload').find((r) => r.id === uploadRow!.id)!.status).toBe('bound');
    const receiptRow = fake.rowsOf('receipt').find((r) => r.billId === bill.id);
    expect(receiptRow!.objectKey).toBe(uploadRow!.objectKey);

    // 未绑定成功（过期/他人）的 uploadId 不阻塞记账
    const bill2 = await request(server())
      .post('/api/v1/bills')
      .set('Authorization', `Bearer ${alice.token}`)
      .send({
        groupId,
        title: '无凭证账单',
        amountCents: 100,
        billDate: '2026-08-24',
        category: 'other',
        splitType: 'even',
        payerId: alice.id,
        participants: [{ userId: alice.id }, { userId: bobId }],
        receiptUploadIds: ['00000000-0000-0000-0000-000000000000'],
      })
      .expect(201);
    expect(bill2.body.data.receipts).toHaveLength(0);
  });

  it('D5 P33 上传：POST /bills/:id/receipts → 凭证落库 + 入队 p33 识别', async () => {
    const bill = fake
      .rowsOf('bill')
      .find((b) => b.title === '小票记账');
    expect(bill).toBeDefined();

    const res = await request(server())
      .post(`/api/v1/bills/${bill!.id}/receipts`)
      .set('Authorization', `Bearer ${alice.token}`)
      .attach('file', Buffer.from('fake-image-2'), 'receipt2.jpg')
      .expect(201);
    expect(res.body.data.id).toBeTruthy();
    expect(res.body.data.ocrStatus).toBe('pending');

    expect(queueAdd).toHaveBeenCalledWith(
      'ocr',
      expect.objectContaining({ kind: 'p33', billId: bill!.id }),
      expect.anything(),
    );
  });

  it('重试识别：越权 404（不暴露存在性）/ 创建者成功', async () => {
    const bill = fake.rowsOf('bill').find((b) => b.title === '小票记账')!;
    const receipt = fake.rowsOf('receipt').find((r) => r.billId === bill.id)!;

    // 无关用户（非创建者/垫付人/群主）→ 404 且不暴露存在性
    const outsider = await register('ocr_eve', 'jkl012JKL', '伊芙');
    await request(server())
      .post(`/api/v1/bills/${bill.id}/receipts/${receipt.id}/ocr/retry`)
      .set('Authorization', `Bearer ${outsider.token}`)
      .expect(404);

    // 创建者重试：重置状态 pending 并重新入队
    const retry = await request(server())
      .post(`/api/v1/bills/${bill.id}/receipts/${receipt.id}/ocr/retry`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(201);
    expect(retry.body.data).toEqual({ success: true });
    expect(fake.rowsOf('receipt').find((r) => r.id === receipt.id)!.ocrStatus).toBe('pending');
    expect(queueAdd).toHaveBeenLastCalledWith(
      'ocr',
      expect.objectContaining({ kind: 'p33', receiptId: receipt.id }),
      expect.anything(),
    );
  });
});
