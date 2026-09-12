import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  /** 模糊搜索账户名，用于添加群成员，最多 20 条（排除自己）。
   *  ⚠️ 必须排除占位账号（非注册成员）：搜索用的是 contains 子串匹配，
   *  字符前缀防得住撞名、防不住搜 `guest` 命中 `~guest_xxx`（ADR-0001）。 */
  async search(accountName: string, excludeUserId?: string) {
    const term = accountName?.trim();
    if (!term) return [];
    const users = await this.prisma.user.findMany({
      where: {
        deletedAt: null,
        isPlaceholder: false,
        accountName: { contains: term, mode: 'insensitive' },
        ...(excludeUserId ? { id: { not: excludeUserId } } : {}),
      },
      take: 20,
      orderBy: { createdAt: 'asc' },
      select: { id: true, accountName: true, nickname: true, avatarUrl: true },
    });
    return users;
  }

  /** 账户名是否已被占用（注册实时校验）。
   *  精确匹配——模糊搜索会把「已有 zhangsan」误报成「zhang 已被占用」；
   *  同时排除占位账号，避免 ~guest_ 前缀污染真实账户名空间。 */
  async isAccountNameTaken(accountName: string): Promise<boolean> {
    const name = accountName?.trim();
    if (!name) return false;
    const existing = await this.prisma.user.findFirst({
      where: { accountName: name, isPlaceholder: false },
      select: { id: true },
    });
    return !!existing;
  }

  /** 公开资料 */
  async getPublicProfile(userId: string) {
    const user = await this.prisma.user.findFirst({
      where: { id: userId, deletedAt: null },
      select: {
        id: true,
        accountName: true,
        nickname: true,
        avatarUrl: true,
        bio: true,
        isPlaceholder: true,
      },
    });
    if (!user) throw new NotFoundException('用户不存在');
    // 占位账号没有可用的账户名（老客户端会直接渲染 @账户名，见 ADR-0001）
    return {
      id: user.id,
      accountName: user.isPlaceholder ? '' : user.accountName,
      nickname: user.nickname,
      avatarUrl: user.avatarUrl,
      bio: user.bio,
      isPlaceholder: user.isPlaceholder,
    };
  }
}
