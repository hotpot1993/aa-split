import { Test } from '@nestjs/testing';
import { BadRequestException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  let service: AuthService;
  const passwordHash = bcrypt.hashSync('abc123ABC', 12);
  const answerHash = bcrypt.hashSync('小虎', 12);

  const configMock = {
    get: jest.fn((k: string) =>
      ({
        JWT_ACCESS_SECRET: 'access-secret',
        JWT_REFRESH_SECRET: 'refresh-secret',
        JWT_ACCESS_EXPIRES_IN: '30d',
        JWT_REFRESH_EXPIRES_IN: '7d',
      }[k] as string | undefined),
    ),
  };

  const jwtMock = {
    signAsync: jest.fn().mockResolvedValue('signed-token'),
  };

  const prismaMock = {
    user: {
      findUnique: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      findMany: jest.fn(),
    },
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const moduleRef = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: JwtService, useValue: jwtMock },
        { provide: ConfigService, useValue: configMock },
      ],
    }).compile();
    service = moduleRef.get(AuthService);
  });

  it('注册：账户名唯一校验 + 密码哈希 + 返回 token', async () => {
    prismaMock.user.findUnique.mockResolvedValue(null);
    prismaMock.user.create.mockResolvedValue({
      id: 'u1',
      accountName: 'tuanzi_t',
      nickname: '团子酱',
      avatarUrl: null,
      bio: null,
    });

    const res = await service.register({
      accountName: 'tuanzi_t',
      password: 'abc123ABC',
      securityQuestion: '你第一个朋友的名字？',
      securityAnswer: '小虎',
    });

    expect(prismaMock.user.create).toHaveBeenCalled();
    expect(prismaMock.user.create.mock.calls[0][0].data.passwordHash).toMatch(/^\$2/);
    expect(res.accessToken).toBe('signed-token');
    expect(res.user.accountName).toBe('tuanzi_t');
    expect(jwtMock.signAsync).toHaveBeenCalledTimes(2);
  });

  it('登录：密码错误抛 UnauthorizedException', async () => {
    prismaMock.user.findUnique.mockResolvedValue({
      id: 'u1',
      accountName: 'tuanzi_t',
      nickname: '团子酱',
      passwordHash,
    });
    await expect(
      service.login({ accountName: 'tuanzi_t', password: 'wrongpass1' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('登录：密码正确返回 token', async () => {
    prismaMock.user.findUnique.mockResolvedValue({
      id: 'u1',
      accountName: 'tuanzi_t',
      nickname: '团子酱',
      passwordHash,
      avatarUrl: null,
      bio: null,
    });
    const res = await service.login({
      accountName: 'tuanzi_t',
      password: 'abc123ABC',
    });
    expect(res.accessToken).toBe('signed-token');
    expect(res.user.id).toBe('u1');
  });

  it('找回密码：校验安全问题后返回 resetToken 并落库', async () => {
    prismaMock.user.findUnique.mockResolvedValue({
      id: 'u1',
      accountName: 'tuanzi_t',
      securityAnswerHash: answerHash,
    });
    prismaMock.user.update.mockResolvedValue({ id: 'u1' });
    const res = await service.forgotVerify({
      accountName: 'tuanzi_t',
      securityAnswer: '小虎',
    });
    expect(res.resetToken).toBeTruthy();
    expect(prismaMock.user.update).toHaveBeenCalled();
    const updateData = prismaMock.user.update.mock.calls[0][0].data;
    expect(updateData.resetTokenHash).toBeTruthy();
    expect(updateData.resetTokenExpiresAt).toBeInstanceOf(Date);
  });

  it('找回密码：安全问题回答错误抛 UnauthorizedException', async () => {
    prismaMock.user.findUnique.mockResolvedValue({
      id: 'u1',
      accountName: 'tuanzi_t',
      securityAnswerHash: answerHash,
    });
    await expect(
      service.forgotVerify({ accountName: 'tuanzi_t', securityAnswer: 'wrong' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('找回密码：查询安全问题返回问题文本', async () => {
    prismaMock.user.findUnique.mockResolvedValue({
      securityQuestion: '你第一个朋友的名字？',
    });
    const res = await service.getSecurityQuestion('tuanzi_t');
    expect(res.question).toBe('你第一个朋友的名字？');
    // 只 select 问题列，不返回任何敏感字段
    expect(prismaMock.user.findUnique).toHaveBeenCalledWith(
      expect.objectContaining({ select: expect.objectContaining({ securityQuestion: true }) }),
    );
  });

  it('找回密码：查询不存在账户抛 BadRequestException（防探测）', async () => {
    prismaMock.user.findUnique.mockResolvedValue(null);
    await expect(service.getSecurityQuestion('nobody_1')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('编辑资料：只更新传入字段，bio 空白清空为 null', async () => {
    prismaMock.user.findUnique.mockResolvedValue({
      id: 'u1',
      accountName: 'tuanzi_t',
      nickname: '团子酱',
      avatarUrl: null,
      bio: '旧签名',
    });
    prismaMock.user.update.mockResolvedValue({
      id: 'u1',
      accountName: 'tuanzi_t',
      nickname: '新昵称',
      avatarUrl: null,
      bio: null,
    });
    const res = await service.updateProfile('u1', {
      nickname: '新昵称',
      bio: '   ',
    });
    expect(res.nickname).toBe('新昵称');
    expect(res.bio).toBeNull();
    const updateCalls = prismaMock.user.update.mock.calls;
    expect(updateCalls.length).toBe(1);
    const data = updateCalls[0][0].data;
    expect(data).toEqual({ nickname: '新昵称', bio: null });
  });

  it('编辑资料：用户不存在抛 UnauthorizedException', async () => {
    prismaMock.user.findUnique.mockResolvedValue(null);
    await expect(
      service.updateProfile('ghost', { nickname: 'x' }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });
});
