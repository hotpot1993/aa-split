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
import { getQueueToken } from '@nestjs/bullmq';
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
import { AppVersionModule } from '../src/app-version/app-version.module';
import { AllExceptionsFilter } from '../src/common/filters/all-exceptions.filter';
import { JwtAuthGuard } from '../src/common/guards/jwt-auth.guard';
import { TransformInterceptor } from '../src/common/interceptors/transform.interceptor';
import { OcrProcessor } from '../src/ocr/ocr.processor';
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
      // BillsModule → OcrModule：队列与 Worker 会连接 Redis（e2e 无 Redis），替换为空壳
      .overrideProvider(getQueueToken('receipt-ocr'))
      .useValue({ add: jest.fn().mockResolvedValue({ id: 'job-1' }) })
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

    // 新成员加入 → 群内其它成员收到「新成员加入」动态（SSE 推送驱动客户端刷新成员列表）
    const aliceNotifs = await request(server())
      .get('/api/v1/notifications')
      .set('Authorization', `Bearer ${aliceToken}`)
      .expect(200);
    const memberNotif = (aliceNotifs.body.data.list as any[]).find(
      (n: any) => n.type === 'member' && n.refId === group.id,
    );
    expect(memberNotif).toBeDefined();
    expect(memberNotif.body).toContain('鲍勃');

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
    // 顶层 payerId 必须返回（客户端 personalBalance 依赖它区分垫付人）
    expect(bill.payerId).toBe(alice.id);
    expect(bill.participants).toHaveLength(2);
    expect(bill.participants.map((p: any) => p.shareAmountCents).sort()).toEqual([
      11000, 11000,
    ]);
    expect(
      bill.participants.find((p: any) => p.userId === alice.id).paid,
    ).toBe(true);

    // 群账单流水（客户端首页净额数据源）必须同样带顶层 payerId
    const listRes = await request(server())
      .get(`/api/v1/groups/${group.id}/bills?page=1&pageSize=10`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(listRes.body.data.list[0].payerId).toBe(alice.id);

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
    // 新账单通知已取消：仅 remind 一条
    expect(unread.body.data.count).toBe(1);

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

  it('消息删除：单条 DELETE 幂等（他人/重复删除均成功不误伤）+ 清空全部 DELETE', async () => {
    const alice = (globalThis as any).__alice as { token: string };
    const bobToken = (globalThis as any).__bobToken as string;

    // bob 此时有 1 条催款通知
    const list1 = await request(server())
      .get('/api/v1/notifications')
      .set('Authorization', `Bearer ${bobToken}`)
      .expect(200);
    const remindNotif = list1.body.data.list[0];
    expect(remindNotif).toBeDefined();

    // 他人（alice）删 bob 的通知 → 幂等成功但已存在标记，且不误伤 bob 的消息
    const foreign = await request(server())
      .delete(`/api/v1/notifications/${remindNotif.id}`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(foreign.body.data.success).toBe(true);
    expect(foreign.body.data.alreadyGone).toBe(true);
    const stillThere = await request(server())
      .get('/api/v1/notifications')
      .set('Authorization', `Bearer ${bobToken}`)
      .expect(200);
    expect(
      (stillThere.body.data.list as any[]).some((n) => n.id === remindNotif.id),
    ).toBe(true);

    // bob 删除自己的通知 → success:true
    const del = await request(server())
      .delete(`/api/v1/notifications/${remindNotif.id}`)
      .set('Authorization', `Bearer ${bobToken}`)
      .expect(200);
    expect(del.body.data.success).toBe(true);

    // 重复删除同一条 → 仍 success:true（幂等；真机丢包重试场景）
    const again = await request(server())
      .delete(`/api/v1/notifications/${remindNotif.id}`)
      .set('Authorization', `Bearer ${bobToken}`)
      .expect(200);
    expect(again.body.data.success).toBe(true);
    expect(again.body.data.alreadyGone).toBe(true);

    // 清空全部：alice 有成员动态通知 → 返回删除条数，且列表变空
    const aliceList = await request(server())
      .get('/api/v1/notifications')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    const aliceCount = (aliceList.body.data.list as any[]).length;
    expect(aliceCount).toBeGreaterThan(0);
    const clear = await request(server())
      .delete('/api/v1/notifications')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(clear.body.data.deleted).toBe(aliceCount);
    const emptyList = await request(server())
      .get('/api/v1/notifications')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(emptyList.body.data.list).toHaveLength(0);
  });

  it('一键结清：群内全部账单统一标记为已付', async () => {
    const alice = (globalThis as any).__alice as { token: string; id: string };
    const group = (globalThis as any).__group as { id: string };
    const bobId = (globalThis as any).__bobId as string;

    // 新建一笔未结清账单（alice 垫付 30 元，bob 未付）
    const billRes = await request(server())
      .post('/api/v1/bills')
      .set('Authorization', `Bearer ${alice.token}`)
      .send({
        groupId: group.id,
        title: '结清测试',
        amountCents: 3000,
        billDate: '2026-08-25',
        category: 'food',
        splitType: 'even',
        payerId: alice.id,
        participants: [{ userId: alice.id }, { userId: bobId }],
      })
      .expect(201);
    const bill = billRes.body.data;
    expect(bill.settleStatus).toBe('partial');

    const res = await request(server())
      .post(`/api/v1/groups/${group.id}/bills/settle-all`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(201);
    expect(res.body.data.updatedBills).toBe(1);
    expect(res.body.data.updatedShares).toBe(1);

    const detail = await request(server())
      .get(`/api/v1/bills/${bill.id}`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(detail.body.data.settleStatus).toBe('settled');
    expect(
      detail.body.data.participants.every((p: any) => p.paid),
    ).toBe(true);

    // 结算方案已清空
    const settle = await request(server())
      .get(`/api/v1/groups/${group.id}/settlement`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(settle.body.data.transferCount).toBe(0);

    (globalThis as any).__settleBill = bill;
  });

  it('凭证替换：上传 → 替换（同 id 换图，旧对象清理）', async () => {
    const alice = (globalThis as any).__alice as { token: string; id: string };
    const bill = (globalThis as any).__settleBill as { id: string };

    const up = await request(server())
      .post(`/api/v1/bills/${bill.id}/receipts`)
      .set('Authorization', `Bearer ${alice.token}`)
      .attach('file', Buffer.from('fake-receipt-1'), 'receipt1.jpg')
      .expect(201);
    expect(up.body.data.id).toBeTruthy();
    expect(up.body.data.url).toContain('/uploads/');

    // 上限 1 张：已有凭证时再上传 → 400
    await request(server())
      .post(`/api/v1/bills/${bill.id}/receipts`)
      .set('Authorization', `Bearer ${alice.token}`)
      .attach('file', Buffer.from('fake-receipt-3'), 'receipt3.jpg')
      .expect(400);

    const rep = await request(server())
      .post(`/api/v1/bills/${bill.id}/receipts/${up.body.data.id}/replace`)
      .set('Authorization', `Bearer ${alice.token}`)
      .attach('file', Buffer.from('fake-receipt-2'), 'receipt2.jpg')
      .expect(201);
    expect(rep.body.data.id).toBe(up.body.data.id);
    expect(rep.body.data.objectKey).not.toBe(up.body.data.objectKey);

    // 详情中的凭证已换图（同一 id）
    const detail = await request(server())
      .get(`/api/v1/bills/${bill.id}`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(detail.body.data.receipts).toHaveLength(1);
    expect(detail.body.data.receipts[0].id).toBe(up.body.data.id);
    expect(detail.body.data.receipts[0].url).toContain('/uploads/');
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

  it('P04 安全问题查询 + P50 编辑资料（PATCH /auth/me）', async () => {
    // 未登录访问 PATCH /auth/me → 401
    await request(server()).patch('/api/v1/auth/me').send({ nickname: 'x' }).expect(401);

    // 查询安全问题
    const q = await request(server())
      .get('/api/v1/auth/security-question?accountName=alice')
      .expect(200);
    expect(q.body.data.question).toBe('你最好的朋友？');

    // 查询不存在的账户 → 400（与 forgot/verify 同文案，防探测）
    await request(server())
      .get('/api/v1/auth/security-question?accountName=ghost_1')
      .expect(400);

    // 编辑昵称 + 清空签名
    const alice = (globalThis as any).__alice as { token: string };
    const upd = await request(server())
      .patch('/api/v1/auth/me')
      .set('Authorization', `Bearer ${alice.token}`)
      .send({ nickname: '爱丽丝2', bio: '' })
      .expect(200);
    expect(upd.body.data.nickname).toBe('爱丽丝2');
    expect(upd.body.data.bio).toBeNull();

    // 重新获取资料已生效
    const me = await request(server())
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(me.body.data.nickname).toBe('爱丽丝2');
  });

  it('P50 上传头像：multipart → /uploads URL 落库 → 群成员列表同步', async () => {
    const alice = (globalThis as any).__alice as { token: string; id: string };

    // 未登录上传 → 401
    await request(server())
      .post('/api/v1/auth/avatar')
      .attach('file', Buffer.from('fake-avatar'), {
        filename: 'avatar.png',
        contentType: 'image/png',
      })
      .expect(401);

    // 上传头像成功 → 可访问 URL
    const up = await request(server())
      .post('/api/v1/auth/avatar')
      .set('Authorization', `Bearer ${alice.token}`)
      .attach('file', Buffer.from('fake-avatar-png'), {
        filename: 'avatar.png',
        contentType: 'image/png',
      })
      .expect(200);
    expect(up.body.data.avatarUrl).toMatch(/^\/uploads\/.+\.png$/);

    // /auth/me 立即生效
    const me = await request(server())
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(me.body.data.avatarUrl).toBe(up.body.data.avatarUrl);

    // 群成员列表（bob 视角）同步拿到同一头像地址（bob 密码在「找回密码链路」测试中被重置）
    const bob = await request(server())
      .post('/api/v1/auth/login')
      .send({ accountName: 'bob', password: 'newPass123' })
      .expect(200);
    const group = (globalThis as any).__group as { id: string };
    const detail = await request(server())
      .get(`/api/v1/groups/${group.id}`)
      .set('Authorization', `Bearer ${bob.body.data.accessToken}`)
      .expect(200);
    const aliceMember = (detail.body.data.members as any[]).find(
      (m: any) => m.userId === alice.id,
    );
    expect(aliceMember.avatarUrl).toBe(up.body.data.avatarUrl);

    // 替换头像：旧上传文件被清理（新 URL 不同）
    const up2 = await request(server())
      .post('/api/v1/auth/avatar')
      .set('Authorization', `Bearer ${alice.token}`)
      .attach('file', Buffer.from('fake-avatar-2'), {
        filename: 'avatar2.jpg',
        contentType: 'image/jpeg',
      })
      .expect(200);
    expect(up2.body.data.avatarUrl).not.toBe(up.body.data.avatarUrl);

    // 非图片文件 → 400
    await request(server())
      .post('/api/v1/auth/avatar')
      .set('Authorization', `Bearer ${alice.token}`)
      .attach('file', Buffer.from('not-an-image'), {
        filename: 'note.pdf',
        contentType: 'application/pdf',
      })
      .expect(400);
  });

  it('注销账号链路（DELETE /auth/me → 旧 token 失效 + 登录拒绝）', async () => {
    // 新用户 charlie：注册 → 加入群 → 注销
    const reg = await request(server())
      .post('/api/v1/auth/register')
      .send({
        accountName: 'charlie',
        password: 'ghi789GHI',
        nickname: '查理',
        securityQuestion: '你喜欢的颜色？',
        securityAnswer: '蓝',
      })
      .expect(201);
    const token = reg.body.data.accessToken as string;

    const group = (globalThis as any).__group as { id: string; inviteCode: string };
    await request(server())
      .post('/api/v1/groups/join')
      .set('Authorization', `Bearer ${token}`)
      .send({ inviteCode: group.inviteCode })
      .expect(201);

    // 注销成功
    const del = await request(server())
      .delete('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(del.body.data.success).toBe(true);

    // 旧 token 立即失效（guard 校验 deletedAt）
    await request(server())
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(401);

    // 原账户名不可再登录
    await request(server())
      .post('/api/v1/auth/login')
      .send({ accountName: 'charlie', password: 'ghi789GHI' })
      .expect(401);
  });

  it('解散群组（软删除）：列表不再返回 + 详情 404', async () => {
    const alice = (globalThis as any).__alice as { token: string };

    // 新建一个群 → 出现在列表中
    const created = await request(server())
      .post('/api/v1/groups')
      .set('Authorization', `Bearer ${alice.token}`)
      .send({ name: '临时测试群', intro: '解散回归' })
      .expect(201);
    const gid = created.body.data.id as string;

    const listBefore = await request(server())
      .get('/api/v1/groups')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect((listBefore.body.data as any[]).map((g) => g.id)).toContain(gid);

    // 解散（软删除）→ 列表不再返回该群
    await request(server())
      .delete(`/api/v1/groups/${gid}`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);

    const listAfter = await request(server())
      .get('/api/v1/groups')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect((listAfter.body.data as any[]).map((g) => g.id)).not.toContain(gid);
    expect((listAfter.body.data as any[]).some((g) => g.name === '饭友群')).toBe(true);

    // 详情对已解散群 404（getGroupOrThrow / assertMember 兜底）
    await request(server())
      .get(`/api/v1/groups/${gid}`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(404);
  });

  it('登录设备：上报 → 列表 → 幂等 → 移除（P52 真实数据链路）', async () => {
    const alice = (globalThis as any).__alice as { token: string };

    // 打开「账号安全」页时上报当前设备（响应必须为 { code, message, data } 包装，
    // 修复 recordDevice 返回 undefined → 空响应体导致客户端解析失败）
    const ensureRes = await request(server())
      .post('/api/v1/auth/devices')
      .set('Authorization', `Bearer ${alice.token}`)
      .send({
        deviceId: 'dev-alice-xiaomi',
        platform: 'android',
        deviceName: 'Xiaomi 2509FPN0BC',
        osVersion: '17',
      })
      .expect(200);
    expect(ensureRes.body.data).toEqual({ success: true });

    const list = await request(server())
      .get('/api/v1/auth/devices')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(list.body.data).toHaveLength(1);
    expect(list.body.data[0].deviceName).toBe('Xiaomi 2509FPN0BC');
    expect(list.body.data[0].platform).toBe('android');
    expect(list.body.data[0].ip).toBeTruthy();

    // 同设备再次上报 → 仍只有 1 条（userId+deviceId 幂等更新）
    await request(server())
      .post('/api/v1/auth/devices')
      .set('Authorization', `Bearer ${alice.token}`)
      .send({ deviceId: 'dev-alice-xiaomi', deviceName: 'Xiaomi 2509FPN0BC' })
      .expect(200);
    const list2 = await request(server())
      .get('/api/v1/auth/devices')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(list2.body.data).toHaveLength(1);

    // 退出该设备 → 列表清空；再删一次也幂等成功
    await request(server())
      .delete('/api/v1/auth/devices/dev-alice-xiaomi')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    await request(server())
      .delete('/api/v1/auth/devices/dev-alice-xiaomi')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    const list3 = await request(server())
      .get('/api/v1/auth/devices')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(list3.body.data).toHaveLength(0);
  });

  // ---------- 非注册成员（占位账号）----------
  // 见 CONTEXT.md「非注册成员」/「占位账号」/「认领」、docs/adr/0001、技术方案 §3.4 §4.2
  describe('非注册成员（占位账号）(e2e)', () => {
    const PH_PASSWORD = 'abc123ABC';
    let owner: { token: string; id: string };
    let member: { token: string; id: string };
    let released: { token: string; id: string };
    let groupId = '';
    /** 占位账号在 users 表里的真实账户名（服务端从不把它下发给客户端） */
    let placeholderAccountName = '';
    let placeholderId = '';

    async function registerUser(accountName: string, nickname: string) {
      const res = await request(server())
        .post('/api/v1/auth/register')
        .send({
          accountName,
          password: PH_PASSWORD,
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

    function userRow(id: string) {
      return fake.rowsOf('user').find((u) => u.id === id)!;
    }

    it('群主添加：名称净化 + 占位标记 + 群内重名（含已退出成员）+ 权限/长度校验', async () => {
      owner = await registerUser('ph_owner', '老大');
      member = await registerUser('ph_member', '鲍勃');
      released = await registerUser('ph_old', '老四');

      const created = await request(server())
        .post('/api/v1/groups')
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ name: '占位测试群' })
        .expect(201);
      groupId = created.body.data.id as string;

      for (const u of [member, released]) {
        await request(server())
          .post('/api/v1/groups/join')
          .set('Authorization', `Bearer ${u.token}`)
          .send({ inviteCode: created.body.data.inviteCode })
          .expect(201);
      }

      // 名称首尾空格与换行被净化；返回体不含可用账户名
      const added = await request(server())
        .post(`/api/v1/groups/${groupId}/placeholder-members`)
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ displayName: '  老王\n' })
        .expect(201);
      expect(added.body.data.nickname).toBe('老王');
      expect(added.body.data.isPlaceholder).toBe(true);
      expect(added.body.data.accountName).toBe('');
      placeholderId = added.body.data.userId as string;
      placeholderAccountName = userRow(placeholderId).accountName as string;
      expect(placeholderAccountName).toMatch(/^~guest_/);
      expect(userRow(placeholderId).isPlaceholder).toBe(true);

      // 群详情：占位账号带 isPlaceholder、accountName 为空；memberCount 计 active
      const detail = await request(server())
        .get(`/api/v1/groups/${groupId}`)
        .set('Authorization', `Bearer ${owner.token}`)
        .expect(200);
      expect(detail.body.data.memberCount).toBe(4);
      const guestRow = (detail.body.data.members as any[]).find(
        (m) => m.userId === placeholderId,
      );
      expect(guestRow).toMatchObject({
        nickname: '老王',
        accountName: '',
        isPlaceholder: true,
        status: 'active',
      });

      // 其他成员收到「新成员加入」播报；占位账号自己不产生任何通知
      const memberNotifs = await request(server())
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${member.token}`)
        .expect(200);
      expect(
        (memberNotifs.body.data.list as any[]).some(
          (n) => n.type === 'member' && n.body.includes('老王'),
        ),
      ).toBe(true);
      expect(
        fake.rowsOf('notification').filter((n) => n.userId === placeholderId),
      ).toHaveLength(0);

      // 非群主添加 → 403
      await request(server())
        .post(`/api/v1/groups/${groupId}/placeholder-members`)
        .set('Authorization', `Bearer ${member.token}`)
        .send({ displayName: '小李' })
        .expect(403);

      // 与其他占位账号重名 → 409
      await request(server())
        .post(`/api/v1/groups/${groupId}/placeholder-members`)
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ displayName: '老王' })
        .expect(409);

      // 与注册成员昵称重名 → 409
      await request(server())
        .post(`/api/v1/groups/${groupId}/placeholder-members`)
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ displayName: '鲍勃' })
        .expect(409);

      // 已退出成员的显示名同样占用：老四退群后仍不可重名
      await request(server())
        .delete(`/api/v1/groups/${groupId}/members/${released.id}`)
        .set('Authorization', `Bearer ${owner.token}`)
        .expect(200);
      const afterLeave = await request(server())
        .get(`/api/v1/groups/${groupId}`)
        .set('Authorization', `Bearer ${owner.token}`)
        .expect(200);
      expect(afterLeave.body.data.memberCount).toBe(3); // left 不计入
      await request(server())
        .post(`/api/v1/groups/${groupId}/placeholder-members`)
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ displayName: '老四' })
        .expect(409);

      // 名称长度 1–32：空 / 超长 → 400
      await request(server())
        .post(`/api/v1/groups/${groupId}/placeholder-members`)
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ displayName: '   ' })
        .expect(400);
      await request(server())
        .post(`/api/v1/groups/${groupId}/placeholder-members`)
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ displayName: '名'.repeat(33) })
        .expect(400);
    });

    it('改名：仅群主，群内不可重名；占位账号对搜索/账户名可用性/登录/找回密码不可见', async () => {
      // 改名
      await request(server())
        .patch(`/api/v1/groups/${groupId}/placeholder-members/${placeholderId}`)
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ displayName: ' 王大爷 ' })
        .expect(200);
      const detail = await request(server())
        .get(`/api/v1/groups/${groupId}`)
        .set('Authorization', `Bearer ${owner.token}`)
        .expect(200);
      expect(
        (detail.body.data.members as any[]).find((m) => m.userId === placeholderId)
          .nickname,
      ).toBe('王大爷');

      // 非群主改名 → 403
      await request(server())
        .patch(`/api/v1/groups/${groupId}/placeholder-members/${placeholderId}`)
        .set('Authorization', `Bearer ${member.token}`)
        .send({ displayName: '乱改' })
        .expect(403);

      // 改成与注册成员同名 → 409
      await request(server())
        .patch(`/api/v1/groups/${groupId}/placeholder-members/${placeholderId}`)
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ displayName: '鲍勃' })
        .expect(409);

      // 对真实账号不能走改名接口 → 404（不是占位账号）
      await request(server())
        .patch(`/api/v1/groups/${groupId}/placeholder-members/${member.id}`)
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ displayName: '鲍勃' })
        .expect(404);

      // 搜索真实账号仍可用，但搜不到占位账号（含子串 guest）
      const found = await request(server())
        .get('/api/v1/users/search?accountName=ph_member')
        .set('Authorization', `Bearer ${owner.token}`)
        .expect(200);
      expect((found.body.data as any[]).some((u) => u.id === member.id)).toBe(true);
      const guestSearch = await request(server())
        .get('/api/v1/users/search?accountName=guest')
        .set('Authorization', `Bearer ${owner.token}`)
        .expect(200);
      expect(guestSearch.body.data).toEqual([]);

      // 账户名可用性：公开接口 + 精确匹配（不再把「已有 zhangsan」误报成「zhang 被占用」）
      const taken = await request(server())
        .get('/api/v1/users/account-available?accountName=ph_owner')
        .expect(200);
      expect(taken.body.data.available).toBe(false);
      const partial = await request(server())
        .get('/api/v1/users/account-available?accountName=ph_ow')
        .expect(200);
      expect(partial.body.data.available).toBe(true);
      // 占位账号的 ~guest_ 账户名不占用真实账户名空间
      const guestName = await request(server())
        .get(
          `/api/v1/users/account-available?accountName=${encodeURIComponent(
            placeholderAccountName,
          )}`,
        )
        .expect(200);
      expect(guestName.body.data.available).toBe(true);

      // 占位账号不进入找回密码链路（登录接口被 5 次/10 分钟限流，其隔离由
      // auth.service.spec 的单测覆盖：登录查询显式带 isPlaceholder: false）
      await request(server())
        .get(
          `/api/v1/auth/security-question?accountName=${encodeURIComponent(
            placeholderAccountName,
          )}`,
        )
        .expect(400);
    });

    it('认领：预览合并范围 → 合并账单/垫付/免分摊/结算 → 不可重复', async () => {
      // 4 笔账单：3 笔与占位账号有关（含 1 笔冲突、1 笔由其垫付）
      const makeBill = async (body: Record<string, unknown>) => {
        const res = await request(server())
          .post('/api/v1/bills')
          .set('Authorization', `Bearer ${owner.token}`)
          .send({
            groupId,
            billDate: '2026-09-01',
            category: 'food',
            splitType: 'even',
            ...body,
          })
          .expect(201);
        return res.body.data;
      };
      const billA = await makeBill({
        title: 'A 两人',
        amountCents: 10000,
        payerId: owner.id,
        participants: [{ userId: owner.id }, { userId: placeholderId }],
      });
      const billB = await makeBill({
        title: 'B 与占位账号无关',
        amountCents: 20000,
        payerId: owner.id,
        participants: [{ userId: owner.id }, { userId: member.id }],
      });
      const billC = await makeBill({
        title: 'C 三人冲突',
        amountCents: 30000,
        payerId: owner.id,
        participants: [
          { userId: owner.id },
          { userId: placeholderId },
          { userId: member.id },
        ],
      });
      const billD = await makeBill({
        title: 'D 占位账号垫付',
        amountCents: 10000,
        payerId: placeholderId,
        participants: [{ userId: placeholderId }, { userId: owner.id }],
      });
      expect(billA.participants).toHaveLength(2);

      // 占位账号参与人：账户名不下发（服务端拼 @账户名 的老客户端不会露馅）
      const guestPart = (billA.participants as any[]).find(
        (p) => p.userId === placeholderId,
      );
      expect(guestPart.user).toMatchObject({
        nickname: '王大爷',
        accountName: '',
        isPlaceholder: true,
      });

      // 占位账号可参与结算（垫付人身份生效）
      const settle = await request(server())
        .get(`/api/v1/groups/${groupId}/settlement`)
        .set('Authorization', `Bearer ${owner.token}`)
        .expect(200);
      expect(settle.body.data.transferCount).toBeGreaterThan(0);

      // 免分摊名单含占位账号（认领后必须替换为真实账号）
      await request(server())
        .patch(`/api/v1/groups/${groupId}`)
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ defaultExemptUserIds: [placeholderId] })
        .expect(200);

      // 预览：账单数 = 3（A/C/D），结算数 = 库中涉及该占位账号的行数
      const preview = await request(server())
        .get(
          `/api/v1/groups/${groupId}/placeholder-members/${placeholderId}/claim-preview?targetUserId=${member.id}`,
        )
        .set('Authorization', `Bearer ${owner.token}`)
        .expect(200);
      const expectedSettlements = fake
        .rowsOf('settlement')
        .filter(
          (s) =>
            s.groupId === groupId &&
            (s.fromUserId === placeholderId || s.toUserId === placeholderId),
        ).length;
      expect(preview.body.data).toMatchObject({
        billCount: 3,
        settlementCount: expectedSettlements,
        placeholderName: '王大爷',
        targetName: '鲍勃',
        targetInGroup: true,
      });

      // 非群主认领 → 403
      await request(server())
        .post(
          `/api/v1/groups/${groupId}/placeholder-members/${placeholderId}/claim`,
        )
        .set('Authorization', `Bearer ${member.token}`)
        .send({ targetUserId: owner.id })
        .expect(403);
      // 目标必须是真实账号：目标是占位账号 → 404
      await request(server())
        .post(
          `/api/v1/groups/${groupId}/placeholder-members/${placeholderId}/claim`,
        )
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ targetUserId: placeholderId })
        .expect(404);

      const claimed = await request(server())
        .post(
          `/api/v1/groups/${groupId}/placeholder-members/${placeholderId}/claim`,
        )
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ targetUserId: member.id })
        .expect(200);
      expect(claimed.body.data).toMatchObject({
        success: true,
        placeholderUserId: placeholderId,
        targetUserId: member.id,
        billCount: 3,
        settlementCount: expectedSettlements,
      });

      // ① 成员关系：占位行删除、真人成员工龄取更早、无重复成员
      const detail = await request(server())
        .get(`/api/v1/groups/${groupId}`)
        .set('Authorization', `Bearer ${owner.token}`)
        .expect(200);
      const memberRows = (detail.body.data.members as any[]).filter(
        (m) => m.userId === member.id,
      );
      expect(memberRows).toHaveLength(1);
      expect(
        (detail.body.data.members as any[]).some((m) => m.userId === placeholderId),
      ).toBe(false);
      expect(detail.body.data.memberCount).toBe(2);

      // ② 账单参与人：冲突行金额相加（总额不变），无冲突行改挂
      const getBill = async (id: string) => {
        const res = await request(server())
          .get(`/api/v1/bills/${id}`)
          .set('Authorization', `Bearer ${owner.token}`)
          .expect(200);
        return res.body.data;
      };
      const a = await getBill(billA.id);
      expect(a.participants).toHaveLength(2);
      expect(
        (a.participants as any[]).find((p) => p.userId === member.id)
          .shareAmountCents,
      ).toBe(5000);
      const b = await getBill(billB.id);
      expect(b.participants).toHaveLength(2);
      const c = await getBill(billC.id);
      expect(c.participants).toHaveLength(2);
      expect(
        (c.participants as any[]).find((p) => p.userId === member.id)
          .shareAmountCents,
      ).toBe(20000);
      expect(
        (c.participants as any[]).reduce(
          (s: number, p: any) => s + p.shareAmountCents,
          0,
        ),
      ).toBe(30000); // 分摊合计仍等于账单金额
      const d = await getBill(billD.id);
      expect(d.payerId).toBe(member.id); // ③ 垫付人改挂
      expect(d.participants).toHaveLength(2);

      // ⑤ 免分摊名单替换（TEXT[]，无外键保护）
      expect(detail.body.data.defaultExemptUserIds).toEqual([member.id]);

      // ④ 结算记录：不再引用占位账号，且该群 pending 方案已清空
      const settlementRows = fake.rowsOf('settlement').filter(
        (s) => s.groupId === groupId,
      );
      expect(
        settlementRows.some(
          (s) => s.fromUserId === placeholderId || s.toUserId === placeholderId,
        ),
      ).toBe(false);
      expect(settlementRows.some((s) => s.status === 'pending')).toBe(false);

      // ⑦ 占位账号行保留并记录合并去向（不删除，避免遗漏引用导致外键悬空）
      expect(userRow(placeholderId).mergedIntoUserId).toBe(member.id);
      expect(userRow(placeholderId).deletedAt).toBeInstanceOf(Date);

      // 重复认领 → 409
      await request(server())
        .post(
          `/api/v1/groups/${groupId}/placeholder-members/${placeholderId}/claim`,
        )
        .set('Authorization', `Bearer ${owner.token}`)
        .send({ targetUserId: owner.id })
        .expect(409);
    });

    it('非注册成员不能接手群主：显式转让被拒；群主注销时群软删除而非交给占位账号', async () => {
      const solo = await registerUser('ph_solo', '独苗');
      const created = await request(server())
        .post('/api/v1/groups')
        .set('Authorization', `Bearer ${solo.token}`)
        .send({ name: '占位专属群' })
        .expect(201);
      const soloGroupId = created.body.data.id as string;

      const guest = await request(server())
        .post(`/api/v1/groups/${soloGroupId}/placeholder-members`)
        .set('Authorization', `Bearer ${solo.token}`)
        .send({ displayName: '阿飘' })
        .expect(201);
      const guestId = guest.body.data.userId as string;

      // 显式转让给非注册成员 → 400（它无法登录，群将无人可管理）
      await request(server())
        .post(`/api/v1/groups/${soloGroupId}/transfer`)
        .set('Authorization', `Bearer ${solo.token}`)
        .send({ newOwnerId: guestId })
        .expect(400);

      // 群主注销：群里只剩不能登录的占位账号 → 群落到软删除，不会交给占位账号
      await request(server())
        .delete('/api/v1/auth/me')
        .set('Authorization', `Bearer ${solo.token}`)
        .expect(200);
      const row = fake.rowsOf('group').find((g) => g.id === soloGroupId)!;
      expect(row.deletedAt).toBeInstanceOf(Date);
      expect(row.ownerId).toBe(solo.id);
    });
  });

  describe('App 版本信息（检查更新）(e2e)', () => {
    it('公开访问 GET /api/v1/app/version 返回最新版本信息', async () => {
      const res = await request(server()).get('/api/v1/app/version').expect(200);
      expect(res.body.code).toBe(0);
      expect(res.body.data.latestVersion).toBeTruthy();
      expect(res.body.data.latestBuild).toBeGreaterThan(0);
      expect(res.body.data.downloadUrl).toMatch(/^https:\/\//);
      expect(typeof res.body.data.notes).toBe('string');
    });
  });
});
