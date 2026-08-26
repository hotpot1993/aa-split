import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { createHash, randomBytes } from 'crypto';
import { PrismaService } from '../prisma/prisma.service';
import { JwtPayload } from '../common/types';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { UpdateProfileDto } from './dto/update-profile.dto';
import { DeviceInfoDto } from './dto/device-info.dto';

const BCRYPT_ROUNDS = 12;
const RESET_TOKEN_TTL_MS = 10 * 60 * 1000; // 10 分钟

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  private hash(plain: string): string {
    return bcrypt.hashSync(plain, BCRYPT_ROUNDS);
  }

  private sha256(input: string): string {
    return createHash('sha256').update(input).digest('hex');
  }

  private async signTokens(user: {
    id: string;
    accountName: string;
    nickname: string;
  }): Promise<TokenPair> {
    const payload: JwtPayload = {
      sub: user.id,
      accountName: user.accountName,
      nickname: user.nickname,
    };
    const accessToken = await this.jwtService.signAsync(payload, {
      secret: this.configService.get<string>('JWT_ACCESS_SECRET'),
      expiresIn: this.configService.get<string>('JWT_ACCESS_EXPIRES_IN') || '30d',
    });
    const refreshToken = await this.jwtService.signAsync(payload, {
      secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      expiresIn: this.configService.get<string>('JWT_REFRESH_EXPIRES_IN') || '7d',
    });
    return { accessToken, refreshToken };
  }

  private sanitizeUser(user: {
    id: string;
    accountName: string;
    nickname: string;
    avatarUrl: string | null;
    bio: string | null;
  }) {
    return {
      id: user.id,
      accountName: user.accountName,
      nickname: user.nickname,
      avatarUrl: user.avatarUrl,
      bio: user.bio,
    };
  }

  async register(dto: RegisterDto, ip?: string) {
    const existing = await this.prisma.user.findUnique({
      where: { accountName: dto.accountName },
    });
    if (existing) throw new ConflictException('账户名已被占用');

    const user = await this.prisma.user.create({
      data: {
        accountName: dto.accountName,
        nickname: dto.nickname || dto.accountName,
        passwordHash: this.hash(dto.password),
        securityQuestion: dto.securityQuestion,
        securityAnswerHash: this.hash(dto.securityAnswer),
      },
    });
    const tokens = await this.signTokens(user);
    await this.recordDevice(user.id, dto.deviceInfo, ip);
    return { ...tokens, user: this.sanitizeUser(user) };
  }

  async login(dto: LoginDto, ip?: string) {
    const user = await this.prisma.user.findUnique({
      where: { accountName: dto.accountName },
    });
    // 账户名不存在、已注销与密码错误统一提示，防探测
    if (
      !user ||
      user.deletedAt ||
      !(await bcrypt.compare(dto.password, user.passwordHash))
    ) {
      throw new UnauthorizedException('账户名或密码错误');
    }
    const tokens = await this.signTokens(user);
    await this.recordDevice(user.id, dto.deviceInfo, ip);
    return { ...tokens, user: this.sanitizeUser(user) };
  }

  // ---------- 登录设备（P52 账号安全） ----------

  /**
   * 记录/更新登录设备（按 userId+deviceId 幂等；不传 deviceId 则跳过）。
   * 登录、注册以及「设备列表页」打开时都会调用，保证当前设备始终真实在列。
   */
  async recordDevice(userId: string, dto?: DeviceInfoDto, ip?: string) {
    const deviceId = dto?.deviceId?.trim();
    if (!deviceId) return { success: false };
    const data = {
      deviceId,
      platform: (dto?.platform ?? '').slice(0, 16),
      deviceName: (dto?.deviceName ?? '').slice(0, 64),
      osVersion: (dto?.osVersion ?? '').slice(0, 32),
      ip: ip?.slice(0, 45) ?? null,
    };
    const existing = await this.prisma.userDevice.findUnique({
      where: { userId_deviceId: { userId, deviceId } },
    });
    if (existing) {
      await this.prisma.userDevice.update({
        where: { id: existing.id },
        data: {
          platform: data.platform,
          deviceName: data.deviceName,
          osVersion: data.osVersion,
          ip: data.ip,
          lastLoginAt: new Date(),
        },
      });
    } else {
      await this.prisma.userDevice.create({
        data: { userId, ...data, lastLoginAt: new Date() },
      });
    }
    // 必须返回非 undefined：TransformInterceptor 对 undefined 直接透传，
    // 会导致响应体为空、客户端无法解析 { code, message, data }
    return { success: true };
  }

  /** 当前账号的登录设备列表（最近登录在前） */
  async listDevices(userId: string) {
    const rows = await this.prisma.userDevice.findMany({
      where: { userId },
      orderBy: { lastLoginAt: 'desc' },
    });
    return rows.map((d) => ({
      id: d.id,
      deviceId: d.deviceId,
      platform: d.platform,
      deviceName: d.deviceName,
      osVersion: d.osVersion,
      ip: d.ip,
      lastLoginAt: d.lastLoginAt,
    }));
  }

  /** 移除（退出）某台设备记录；不存在也视为成功（幂等） */
  async removeDevice(userId: string, deviceId: string) {
    await this.prisma.userDevice.deleteMany({
      where: { userId, deviceId },
    });
    return { success: true };
  }

  /** 找回密码第一步：验证安全问题 → 返回 resetToken（DB 记录 hash + 过期时间） */
  async forgotVerify(dto: { accountName: string; securityAnswer: string }) {
    const user = await this.prisma.user.findUnique({
      where: { accountName: dto.accountName },
    });
    if (!user) throw new BadRequestException('账户不存在');
    const ok = await bcrypt.compare(dto.securityAnswer, user.securityAnswerHash);
    if (!ok) throw new UnauthorizedException('安全问题回答错误');

    const resetToken = randomBytes(32).toString('hex');
    await this.prisma.user.update({
      where: { id: user.id },
      data: {
        resetTokenHash: this.sha256(resetToken),
        resetTokenExpiresAt: new Date(Date.now() + RESET_TOKEN_TTL_MS),
      },
    });
    return { resetToken };
  }

  /** 找回密码第二步：用 resetToken 设置新密码 */
  async forgotReset(dto: { resetToken: string; newPassword: string }) {
    // 找持有未过期 reset token 的用户
    const users = await this.prisma.user.findMany({
      where: {
        resetTokenExpiresAt: { gt: new Date() },
        resetTokenHash: { not: null },
      },
    });
    const candidate = users.find(
      (u) => u.resetTokenHash === this.sha256(dto.resetToken),
    );
    if (!candidate) throw new UnauthorizedException('重置令牌无效或已过期');

    await this.prisma.user.update({
      where: { id: candidate.id },
      data: {
        passwordHash: this.hash(dto.newPassword),
        resetTokenHash: null,
        resetTokenExpiresAt: null,
      },
    });
    return { success: true };
  }

  /** 修改密码（需当前密码） */
  async changePassword(
    userId: string,
    dto: { currentPassword: string; newPassword: string },
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException('用户不存在');
    if (!(await bcrypt.compare(dto.currentPassword, user.passwordHash))) {
      throw new UnauthorizedException('当前密码错误');
    }
    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: this.hash(dto.newPassword) },
    });
    return { success: true };
  }

  /** 修改安全问题（需当前密码验证） */
  async changeSecurityQuestion(
    userId: string,
    dto: {
      currentPassword: string;
      securityQuestion: string;
      securityAnswer: string;
    },
  ) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException('用户不存在');
    if (!(await bcrypt.compare(dto.currentPassword, user.passwordHash))) {
      throw new UnauthorizedException('当前密码错误');
    }
    await this.prisma.user.update({
      where: { id: userId },
      data: {
        securityQuestion: dto.securityQuestion,
        securityAnswerHash: this.hash(dto.securityAnswer),
      },
    });
    return { success: true };
  }

  /** 获取当前用户资料 */
  async me(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException('用户不存在');
    return this.sanitizeUser(user);
  }

  /** P04：按账户名查询安全问题（仅返回问题文本，供忘记密码答题提示） */
  async getSecurityQuestion(accountName: string) {
    const user = await this.prisma.user.findUnique({
      where: { accountName },
      select: { securityQuestion: true },
    });
    // 与 forgotVerify 保持同一提示，避免账户是否存在被探测
    if (!user) throw new BadRequestException('账户不存在');
    return { question: user.securityQuestion };
  }

  /** P50：更新当前用户资料（昵称/头像/签名），只更新传入字段 */
  async updateProfile(userId: string, dto: UpdateProfileDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException('用户不存在');

    const data: Record<string, string | null> = {};
    if (dto.nickname !== undefined) {
      data.nickname = dto.nickname.trim();
    }
    if (dto.bio !== undefined) {
      data.bio = dto.bio.trim().length > 0 ? dto.bio.trim() : null;
    }
    if (dto.avatarUrl !== undefined) {
      data.avatarUrl = dto.avatarUrl;
    }

    const updated = await this.prisma.user.update({
      where: { id: userId },
      data,
    });
    return this.sanitizeUser(updated);
  }

  /**
   * 注销账号（应用商店合规要求：账号删除）。
   * 采用「软删除 + 匿名化」：用户行保留（群组/账单历史引用不悬空），
   * 但登录名/密码/安全问题全部失效、个人信息清空；成员关系保留历史（left）；
   * 群主身份转给群内最早加入的活跃成员，无成员则软删该群；个人通知删除。
   */
  async deleteAccount(userId: string) {
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.findUnique({ where: { id: userId } });
      if (!user) throw new NotFoundException('账号不存在');
      if (user.deletedAt) throw new BadRequestException('账号已注销');

      // 1. 群主身份转移（无其他成员则软删群）
      const ownedGroups = await tx.group.findMany({
        where: { ownerId: userId, deletedAt: null },
      });
      for (const g of ownedGroups) {
        const nextOwner = await tx.groupMember.findFirst({
          where: { groupId: g.id, status: 'active', userId: { not: userId } },
          orderBy: { joinedAt: 'asc' },
        });
        if (nextOwner) {
          await tx.group.update({
            where: { id: g.id },
            data: { ownerId: nextOwner.userId },
          });
        } else {
          await tx.group.update({
            where: { id: g.id },
            data: { deletedAt: new Date() },
          });
        }
      }

      // 2. 成员关系保留历史但退出（不再出现在活跃成员中）
      await tx.groupMember.updateMany({
        where: { userId },
        data: { status: 'left' },
      });

      // 3. 个人通知与登录设备记录删除（其余群组/账单数据属于群，保留）
      await tx.notification.deleteMany({ where: { userId } });
      await tx.userDevice.deleteMany({ where: { userId } });

      // 4. 匿名化 + 标记注销；旧 token 由 JwtAuthGuard 的 deletedAt 校验立即失效
      const suffix = randomBytes(6).toString('hex');
      await tx.user.update({
        where: { id: userId },
        data: {
          deletedAt: new Date(),
          accountName: `del_${suffix}`,
          nickname: '已注销',
          avatarUrl: null,
          bio: null,
          passwordHash: '!',
          securityQuestion: '账号已注销',
          securityAnswerHash: '!',
          resetTokenHash: null,
          resetTokenExpiresAt: null,
        },
      });
      return { success: true };
    });
  }
}
