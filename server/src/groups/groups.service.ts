import {
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MemberStatus, Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateGroupDto } from './dto/create-group.dto';
import { UpdateGroupDto } from './dto/update-group.dto';

const INVITE_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const INVITE_LENGTH = 12;

@Injectable()
export class GroupsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly notificationsService: NotificationsService,
  ) {}

  private generateInviteCode(): string {
    let code = '';
    for (let i = 0; i < INVITE_LENGTH; i++) {
      code += INVITE_CHARS[Math.floor(Math.random() * INVITE_CHARS.length)];
    }
    return code;
  }

  private async createUniqueInviteCode(): Promise<string> {
    for (let attempt = 0; attempt < 5; attempt++) {
      const code = this.generateInviteCode();
      const exists = await this.prisma.group.findUnique({
        where: { inviteCode: code },
      });
      if (!exists) return code;
    }
    throw new ConflictException('邀请码生成失败，请重试');
  }

  /** 校验当前用户是群 active 成员；否则 404 伪装（防探测） */
  private async assertMember(groupId: string, userId: string) {
    const membership = await this.prisma.groupMember.findFirst({
      where: { groupId, userId, status: MemberStatus.active },
    });
    if (!membership) throw new NotFoundException('群组不存在');
  }

  private async getGroupOrThrow(groupId: string) {
    const group = await this.prisma.group.findFirst({
      where: { id: groupId, deletedAt: null },
    });
    if (!group) throw new NotFoundException('群组不存在');
    return group;
  }

  /** 我加入的所有群（软删除/已解散的群不返回） */
  async listMyGroups(userId: string) {
    const memberships = await this.prisma.groupMember.findMany({
      where: { userId, status: MemberStatus.active },
      include: {
        group: {
          include: {
            owner: { select: { id: true, accountName: true, nickname: true, avatarUrl: true } },
            _count: { select: { members: true } },
          },
        },
      },
      orderBy: { joinedAt: 'desc' },
    });
    return memberships
      // 解散 = 软删除（deletedAt 非 null）：成员关系仍存在，但要过滤掉
      .filter((m) => m.group !== null && m.group.deletedAt == null)
      .map((m) => ({
        id: m.group.id,
        name: m.group.name,
        avatarUrl: m.group.avatarUrl,
        intro: m.group.intro,
        ownerId: m.group.ownerId,
        owner: m.group.owner,
        defaultSplitType: m.group.defaultSplitType,
        memberCount: m.group._count.members,
        joinedAt: m.joinedAt,
      }));
  }

  /** 创建群，创建者自动成为 owner + 成员 */
  async createGroup(userId: string, dto: CreateGroupDto) {
    const inviteCode = await this.createUniqueInviteCode();
    const group = await this.prisma.group.create({
      data: {
        name: dto.name,
        avatarUrl: dto.avatarUrl,
        intro: dto.intro,
        ownerId: userId,
        defaultSplitType: dto.defaultSplitType ?? 'even',
        inviteCode,
        members: { create: { userId, status: MemberStatus.active } },
      },
      include: { owner: true },
    });
    return {
      id: group.id,
      name: group.name,
      avatarUrl: group.avatarUrl,
      intro: group.intro,
      ownerId: group.ownerId,
      defaultSplitType: group.defaultSplitType,
      inviteCode: group.inviteCode,
    };
  }

  /** 群详情（含成员列表） */
  async getGroup(userId: string, groupId: string) {
    await this.assertMember(groupId, userId);
    const group = await this.getGroupOrThrow(groupId);
    const members = await this.prisma.groupMember.findMany({
      where: { groupId },
      include: {
        user: { select: { id: true, accountName: true, nickname: true, avatarUrl: true } },
      },
      orderBy: { joinedAt: 'asc' },
    });
    return {
      id: group.id,
      name: group.name,
      avatarUrl: group.avatarUrl,
      intro: group.intro,
      ownerId: group.ownerId,
      defaultSplitType: group.defaultSplitType,
      inviteCode: group.inviteCode,
      memberCount: members.length,
      members: members.map((m) => ({
        userId: m.userId,
        accountName: m.user.accountName,
        nickname: m.user.nickname,
        avatarUrl: m.user.avatarUrl,
        status: m.status,
        joinedAt: m.joinedAt,
      })),
    };
  }

  /** 修改群信息（仅 owner） */
  async updateGroup(userId: string, groupId: string, dto: UpdateGroupDto) {
    const group = await this.getGroupOrThrow(groupId);
    if (group.ownerId !== userId) throw new ForbiddenException('仅群主可修改群信息');
    return this.prisma.group.update({
      where: { id: groupId },
      data: dto,
    });
  }

  /** 解散群（软删除，仅 owner） */
  async deleteGroup(userId: string, groupId: string) {
    const group = await this.getGroupOrThrow(groupId);
    if (group.ownerId !== userId) throw new ForbiddenException('仅群主可解散群组');
    return this.prisma.group.update({
      where: { id: groupId },
      data: { deletedAt: new Date() },
    });
  }

  /** 新成员入群/被添加后，给群内其它 active 成员发「动态」通知。
   *  通知会推送 SSE → 客户端 bump 刷新数据，其它成员端的成员列表随之实时更新。 */
  private async notifyMembersJoined(
    groupId: string,
    groupName: string,
    joinedNickname: string,
    exceptUserIds: string[],
  ) {
    const members = await this.prisma.groupMember.findMany({
      where: { groupId, status: MemberStatus.active },
      select: { userId: true },
    });
    const targets = members
      .map((m) => m.userId)
      .filter((uid) => !exceptUserIds.includes(uid));
    if (targets.length === 0) return;
    await this.notificationsService.createMany(targets, {
      type: 'member',
      title: '新成员加入',
      body: `${joinedNickname} 加入了「${groupName}」`,
      refType: 'group',
      refId: groupId,
    });
  }

  /** 按账户名添加成员（任一 active 成员可添加） */
  async addMember(userId: string, groupId: string, accountName: string) {
    await this.assertMember(groupId, userId);
    const group = await this.getGroupOrThrow(groupId);
    const target = await this.prisma.user.findFirst({
      where: { accountName, deletedAt: null },
    });
    if (!target) throw new NotFoundException('用户不存在');

    const existing = await this.prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId, userId: target.id } },
    });
    if (existing && existing.status === MemberStatus.active) {
      throw new ConflictException('该用户已是群成员');
    }
    const joinedNickname = target.nickname || target.accountName;
    if (existing && existing.status === MemberStatus.left) {
      const updated = await this.prisma.groupMember.update({
        where: { id: existing.id },
        data: { status: MemberStatus.active },
      });
      await this.notificationsService.create(target.id, {
        type: 'invite',
        title: '群组邀请',
        body: `${group.name} 邀请你加入`,
        refType: 'group',
        refId: groupId,
      });
      await this.notifyMembersJoined(
        groupId,
        group.name,
        joinedNickname,
        [userId, target.id],
      );
      return { success: true, membershipId: updated.id };
    }
    const created = await this.prisma.groupMember.create({
      data: { groupId, userId: target.id, status: MemberStatus.active },
    });
    await this.notificationsService.create(target.id, {
      type: 'invite',
      title: '群组邀请',
      body: `${group.name} 邀请你加入`,
      refType: 'group',
      refId: groupId,
    });
    await this.notifyMembersJoined(
      groupId,
      group.name,
      joinedNickname,
      [userId, target.id],
    );
    return { success: true, membershipId: created.id };
  }

  /** 移除成员 / 退群（owner 或本人；status=left） */
  async removeMember(userId: string, groupId: string, targetUserId: string) {
    await this.assertMember(groupId, userId);
    const group = await this.getGroupOrThrow(groupId);
    const membership = await this.prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId, userId: targetUserId } },
    });
    if (!membership) throw new NotFoundException('成员不存在');

    if (targetUserId !== userId && group.ownerId !== userId) {
      throw new ForbiddenException('仅群主或本人可移除成员');
    }
    const updated = await this.prisma.groupMember.update({
      where: { id: membership.id },
      data: { status: MemberStatus.left },
    });
    return { success: true, membershipId: updated.id };
  }

  /** 转让群主（仅 owner） */
  async transferOwner(userId: string, groupId: string, newOwnerId: string) {
    const group = await this.getGroupOrThrow(groupId);
    if (group.ownerId !== userId) throw new ForbiddenException('仅群主可转让群主');
    const membership = await this.prisma.groupMember.findFirst({
      where: { groupId, userId: newOwnerId, status: MemberStatus.active },
    });
    if (!membership) throw new NotFoundException('新群主必须是群成员');
    return this.prisma.group.update({
      where: { id: groupId },
      data: { ownerId: newOwnerId },
    });
  }

  /** 通过邀请码加入群（未知/已退群成员恢复 active） */
  async joinGroup(userId: string, inviteCode: string) {
    const group = await this.prisma.group.findFirst({
      where: { inviteCode, deletedAt: null },
    });
    if (!group) throw new NotFoundException('邀请码无效');
    const existing = await this.prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId: group.id, userId } },
    });
    if (existing && existing.status === MemberStatus.active) {
      return { id: group.id, name: group.name, alreadyJoined: true };
    }
    const me = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { nickname: true, accountName: true },
    });
    const joinedNickname = me?.nickname || me?.accountName || '新朋友';
    if (existing) {
      await this.prisma.groupMember.update({
        where: { id: existing.id },
        data: { status: MemberStatus.active },
      });
    } else {
      await this.prisma.groupMember.create({
        data: { groupId: group.id, userId, status: MemberStatus.active },
      });
    }
    // 通知群内其它成员（SSE → 客户端刷新成员列表）
    await this.notifyMembersJoined(group.id, group.name, joinedNickname, [userId]);
    return { id: group.id, name: group.name, alreadyJoined: false };
  }

  /** 邀请信息 */
  async getInvite(userId: string, groupId: string) {
    await this.assertMember(groupId, userId);
    const group = await this.getGroupOrThrow(groupId);
    const members = await this.prisma.groupMember.findMany({
      where: { groupId },
      include: { user: { select: { id: true, accountName: true, nickname: true, avatarUrl: true } } },
    });
    return {
      inviteCode: group.inviteCode,
      joinedCount: members.length,
      members: members.map((m) => ({
        userId: m.userId,
        accountName: m.user.accountName,
        nickname: m.user.nickname,
        avatarUrl: m.user.avatarUrl,
      })),
    };
  }
}
