/**
 * 核心链路端到端契约测试（无数据库）：
 *   注册 → 登录 → 建群 → 邀请加入 → 记账(均摊) → 最少转账结算 → 催款 → 标记已付 → 已结清
 * 通过 Test.createTestingModule 加载真实模块（控制器/服务/守卫/拦截器/管道），
 * 仅把 PrismaService 替换为内存 FakePrisma，HTTP 层走 supertest。
 */
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { APP_FILTER, APP_GUARD, APP_INTERCEPTOR } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { JwtModule } from '@nestjs/jwt';
import { Test } from '@nestjs/testing';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import request from 'supertest';
import * as os from 'os';
import * as path from 'path';

import { AuthModule } from '../src/auth/auth.module';
import { BillsModule } from '../src/bills/bills.module';
import { GroupsModule } from '../src/groups/groups.module';
import { NotificationsModule } from '../src/notifications/notifications.module';
import { PrismaModule } from '../src/prisma/prisma.module';
import { PrismaService } from '../src/prisma/prisma.service';
import { SettlementModule } from '../src/settlement/settlement.module';
import { StorageModule } from '../src/storage/storage.module';
import { UsersModule } from '../src/users/users.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { JwtAuthGuard } from '../src/common/guards/jwt-auth.guard';
import { TransformInterceptor } from '../src/common/interceptors/transform.interceptor';
import { FakePrisma } from './fake-prisma';

describe('核心链路 e2e（注册→建群→记账→结算→催款→已付）(e2e)', () => {
  let app: INestApplication;
  let fake: FakePrisma;

  beforeAll(async () => {
    process.env.UPLOAD_DIR = path.join(os.tmpdir(), 'aa-e2e-uploads');
    process.env.JWT_ACCESS_SECRET = 'e2e-access-secret';
    process.env.JWT_REFRESH_SECRET = 'e2e-refresh-secret';
    process.env.SWAGGER_ENABLED = 'false';

    fake = new FakePrisma();
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
        SettlementModule,
        NotificationsModule,
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

  it('注册双用户 + 重复注册 409', async () => {
    const alice = await request(server())
      .post('/api/v1/auth/register')
      .send({
        accountName: 'alice',
        password: 'abc123ABC',
        nickname: '爱丽丝',
        securityQuestion: '你最好的朋友？',
        securityAnswer: '小红',
      })
      .expect(201);
    expect(alice.body.code).toBe(0);
    expect(alice.body.data.user.accountName).toBe('alice');
    expect(alice.body.data.accessToken).toBeTruthy();

    const bob = await request(server())
      .post('/api/v1/auth/register')
      .send({
        accountName: 'bob',
        password: 'def456DEF',
        nickname: '鲍勃',
        securityQuestion: '你的小学？',
        securityAnswer: '实验',
      })
      .expect(201);
    expect(bob.body.code).toBe(0);

    const dup = await request(server())
      .post('/api/v1/auth/register')
      .send({
        accountName: 'alice',
        password: 'abc123ABC',
        securityQuestion: '你最好的朋友？',
        securityAnswer: '小红',
      })
      .expect(409);
    expect(dup.body.code).not.toBe(0);
  });

  it('登录并建群 + 邀请码加入', async () => {
    const aliceLogin = await request(server())
      .post('/api/v1/auth/login')
      .send({ accountName: 'alice', password: 'abc123ABC' })
      .expect(200);
    const aliceToken = aliceLogin.body.data.accessToken as string;
    const aliceId = aliceLogin.body.data.user.id as string;

    // 无 token 访问受保护接口 → 401 统一错误
    const noAuth = await request(server()).get('/api/v1/auth/me').expect(401);
    expect(noAuth.body.code).not.toBe(0);

    const groupRes = await request(server())
      .post('/api/v1/groups')
      .set('Authorization', `Bearer ${aliceToken}`)
      .send({ name: '饭友群', intro: '每周聚餐' })
      .expect(201);
    const group = groupRes.body.data;
    expect(group.code).toBeUndefined(); // 数据内无业务码
    expect(group.name).toBe('饭友群');
    expect(group.inviteCode).toMatch(/^[A-Z0-9]{12}$/);

    const bob = await request(server())
      .post('/api/v1/auth/login')
      .send({ accountName: 'bob', password: 'def456DEF' })
      .expect(200);
    const bobToken = bob.body.data.accessToken as string;

    const joinRes = await request(server())
      .post('/api/v1/groups/join')
      .set('Authorization', `Bearer ${bobToken}`)
      .send({ inviteCode: group.inviteCode })
      .expect(201);
    expect(joinRes.body.data.id).toBe(group.id);

    const groups = await request(server())
      .get('/api/v1/groups')
      .set('Authorization', `Bearer ${bobToken}`)
      .expect(200);
    expect(groups.body.data).toHaveLength(1);
    expect(groups.body.data[0].memberCount).toBe(2);

    // 回传凭证给后续用例
    (globalThis as any).__alice = { token: aliceToken, id: aliceId };
    (globalThis as any).__group = group;
    (globalThis as any).__bobToken = bobToken;
    (globalThis as any).__bobId = bob.body.data.user.id as string;
  });

  it('记账（均摊 220 元）→ 结算方案 1 笔（bob→alice 11000 分）', async () => {
    const alice = (globalThis as any).__alice as { token: string; id: string };
    const group = (globalThis as any).__group as { id: string };
    const bobId = (globalThis as any).__bobId as string;

    const billRes = await request(server())
      .post('/api/v1/bills')
      .set('Authorization', `Bearer ${alice.token}`)
      .send({
        groupId: group.id,
        title: '火锅聚餐',
        location: '老码头',
        amountCents: 22000,
        billDate: '2026-08-24',
        category: 'food',
        splitType: 'even',
        payerId: alice.id,
        participants: [{ userId: alice.id }, { userId: bobId }],
      })
      .expect(201);
    const bill = billRes.body.data;
    // 垫付人自付份额 → 创建后为 partial（待他人）
    expect(bill.settleStatus).toBe('partial');
    expect(bill.amountCents).toBe(22000);
    expect(bill.participants).toHaveLength(2);
    expect(bill.participants.map((p: any) => p.shareAmountCents).sort()).toEqual([
      11000, 11000,
    ]);
    expect(
      bill.participants.find((p: any) => p.userId === alice.id).paid,
    ).toBe(true);

    // 分摊合计不等于金额 → 400 业务错误
    const bad = await request(server())
      .post('/api/v1/bills')
      .set('Authorization', `Bearer ${alice.token}`)
      .send({
        groupId: group.id,
        title: '错误账单',
        amountCents: 10000,
        billDate: '2026-08-24',
        category: 'food',
        splitType: 'custom',
        payerId: alice.id,
        participants: [
          { userId: alice.id, shareAmountCents: 3000 },
          { userId: bobId, shareAmountCents: 3000 },
        ],
      })
      .expect(400);
    expect(bad.body.code).not.toBe(0);

    const settle = await request(server())
      .get(`/api/v1/groups/${group.id}/settlement`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(settle.body.data.transferCount).toBe(1);
    expect(settle.body.data.transfers[0]).toMatchObject({
      fromUserId: bobId,
      toUserId: alice.id,
      amountCents: 11000,
    });

    (globalThis as any).__bill = bill;
  });

  it('催款 → 通知；标记已付 → 账单结清、结算方案清空', async () => {
    const alice = (globalThis as any).__alice as { token: string; id: string };
    const group = (globalThis as any).__group as { id: string };
    const bill = (globalThis as any).__bill as { id: string };
    const bobToken = (globalThis as any).__bobToken as string;
    const bobId = (globalThis as any).__bobId as string;

    const remind = await request(server())
      .post(`/api/v1/bills/${bill.id}/remind`)
      .set('Authorization', `Bearer ${alice.token}`)
      .send({ userIds: [bobId], message: '快还钱呀～' })
      .expect(201);
    expect(remind.body.data.success).toBe(true);
    expect(remind.body.data.remindedCount).toBe(1);

    const unread = await request(server())
      .get('/api/v1/notifications/unread-count')
      .set('Authorization', `Bearer ${bobToken}`)
      .expect(200);
    // new_bill + remind 各一条
    expect(unread.body.data.count).toBe(2);

    const paid = await request(server())
      .post(`/api/v1/bills/${bill.id}/mark-paid`)
      .set('Authorization', `Bearer ${alice.token}`)
      .send({ userId: bobId, paid: true })
      .expect(201);
    expect(paid.body.data.paid).toBe(true);

    const detail = await request(server())
      .get(`/api/v1/bills/${bill.id}`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(detail.body.data.settleStatus).toBe('settled');

    const settle = await request(server())
      .get(`/api/v1/groups/${group.id}/settlement`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(settle.body.data.transferCount).toBe(0);
    expect(settle.body.data.transfers).toEqual([]);
  });

  it('找回密码链路（verify → reset → 新密码登录）', async () => {
    const verify = await request(server())
      .post('/api/v1/auth/forgot/verify')
      .send({ accountName: 'bob', securityAnswer: '实验' })
      .expect(200);
    const resetToken = verify.body.data.resetToken as string;
    expect(resetToken).toBeTruthy();

    const resetRes = await request(server())
      .post('/api/v1/auth/forgot/reset')
      .send({ resetToken, newPassword: 'newPass123' });
    expect(resetRes.status).toBe(200);

    const relogin = await request(server())
      .post('/api/v1/auth/login')
      .send({ accountName: 'bob', password: 'newPass123' })
      .expect(200);
    expect(relogin.body.data.user.accountName).toBe('bob');
  });
});
