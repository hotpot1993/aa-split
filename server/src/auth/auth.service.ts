import {
  BadRequestException,
  ConflictException,
  Injectable,
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

  async register(dto: RegisterDto) {
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
    return { ...tokens, user: this.sanitizeUser(user) };
  }

  async login(dto: LoginDto) {
    const user = await this.prisma.user.findUnique({
      where: { accountName: dto.accountName },
    });
    // 账户名不存在与密码错误统一提示，防探测
    if (!user || !(await bcrypt.compare(dto.password, user.passwordHash))) {
      throw new UnauthorizedException('账户名或密码错误');
    }
    const tokens = await this.signTokens(user);
    return { ...tokens, user: this.sanitizeUser(user) };
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

  /** 获取当前用户资料 */
  async me(userId: string) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new UnauthorizedException('用户不存在');
    return this.sanitizeUser(user);
  }
}
