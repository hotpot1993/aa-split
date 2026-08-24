import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class UsersService {
  constructor(private readonly prisma: PrismaService) {}

  /** 模糊搜索账户名，用于添加群成员，最多 20 条（排除自己） */
  async search(accountName: string, excludeUserId?: string) {
    const term = accountName?.trim();
    if (!term) return [];
    const users = await this.prisma.user.findMany({
      where: {
        deletedAt: null,
        accountName: { contains: term, mode: 'insensitive' },
        ...(excludeUserId ? { id: { not: excludeUserId } } : {}),
      },
      take: 20,
      orderBy: { createdAt: 'asc' },
      select: { id: true, accountName: true, nickname: true, avatarUrl: true },
    });
    return users;
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
      },
    });
    if (!user) throw new NotFoundException('用户不存在');
    return user;
  }
}
