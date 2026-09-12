import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { MemberStatus, Prisma, SettlementStatus } from '@prisma/client';
import { randomUUID } from 'crypto';
import { sanitizeDisplayName } from './dto/placeholder-member.dto';
import { PLACEHOLDER_PREFIX, PLACEHOLDER_SECRET_HASH } from '../common/placeholder';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CreateGroupDto } from './dto/create-group.dto';
import { UpdateGroupDto } from './dto/update-group.dto';

const INVITE_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const INVITE_LENGTH = 12;

/** 单群成员上限（active 计数；仅新增非注册成员接口校验，不动既有添加成员路径） */
const MAX_GROUP_MEMBERS = 50;

/** 群成员视图：占位账号一律返回空 accountName（ADR-0001：老客户端会直接渲染 @账户名） */
interface MemberViewSource {
  userId: string;
  status: MemberStatus;
  joinedAt: Date;
  user: {
    accountName: string;
    nickname: string;
    avatarUrl: string | null;
    isPlaceholder: boolean;
  };
}

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
          },
        },
      },
      orderBy: { joinedAt: 'desc' },
    });
    // memberCount 只计 active 成员（人均分母同此口径）；已退出（left）成员不计入。
    // 不能用 _count.members —— 它把 left 成员也算进去，与 Demo/产品口径不一致。
    const groupIds = memberships.map((m) => m.groupId);
    const activeRows = groupIds.length
      ? await this.prisma.groupMember.findMany({
          where: { groupId: { in: groupIds }, status: MemberStatus.active },
          select: { groupId: true },
        })
      : [];
    const activeCount = new Map<string, number>();
    for (const row of activeRows) {
      activeCount.set(row.groupId, (activeCount.get(row.groupId) ?? 0) + 1);
    }
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
        defaultExemptUserIds: m.group.defaultExemptUserIds,
        memberCount: activeCount.get(m.group.id) ?? 0,
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

  /** 群详情（含成员列表：完整列表含已退出，便于 P24 渲染「已退出」状态） */
  async getGroup(userId: string, groupId: string) {
    await this.assertMember(groupId, userId);
    const group = await this.getGroupOrThrow(groupId);
    const members = await this.prisma.groupMember.findMany({
      where: { groupId },
      include: {
        user: {
          select: {
            id: true,
            accountName: true,
            nickname: true,
            avatarUrl: true,
            isPlaceholder: true,
          },
        },
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
      defaultExemptUserIds: group.defaultExemptUserIds,
      inviteCode: group.inviteCode,
      // memberCount 只计 active 成员（人均分母同此口径）；members 仍是完整列表
      memberCount: members.filter((m) => m.status === MemberStatus.active).length,
      members: members.map((m) => this.toMemberView(m)),
    };
  }

  /** 成员视图：占位账号不带账户名（老客户端会直接渲染 @账户名） */
  private toMemberView(m: MemberViewSource) {
    return {
      userId: m.userId,
      accountName: m.user.isPlaceholder ? '' : m.user.accountName,
      nickname: m.user.nickname,
      avatarUrl: m.user.avatarUrl,
      isPlaceholder: m.user.isPlaceholder,
      status: m.status,
      joinedAt: m.joinedAt,
    };
  }

  /** 修改群信息（仅 owner）；默认免分摊人员仅保留群内 active 成员 */
  async updateGroup(userId: string, groupId: string, dto: UpdateGroupDto) {
    const group = await this.getGroupOrThrow(groupId);
    if (group.ownerId !== userId) throw new ForbiddenException('仅群主可修改群信息');
    const data: Prisma.GroupUpdateInput = {};
    if (dto.name !== undefined) data.name = dto.name;
    if (dto.avatarUrl !== undefined) data.avatarUrl = dto.avatarUrl;
    if (dto.intro !== undefined) data.intro = dto.intro;
    if (dto.defaultSplitType !== undefined) data.defaultSplitType = dto.defaultSplitType;
    if (dto.defaultExemptUserIds !== undefined) {
      const members = await this.prisma.groupMember.findMany({
        where: { groupId, status: MemberStatus.active },
        select: { userId: true },
      });
      const memberIds = new Set(members.map((m) => m.userId));
      data.defaultExemptUserIds = [...new Set(dto.defaultExemptUserIds)].filter(
        (id) => memberIds.has(id),
      );
    }
    return this.prisma.group.update({
      where: { id: groupId },
      data,
    });
  }

  /** 解散群（软删除，仅 owner）。解散后给其它 active 成员写通知并推 SSE，
   *  客户端收到后 bump 刷新 —— 群组从组员端列表中同步移除。 */
  async deleteGroup(userId: string, groupId: string) {
    const group = await this.getGroupOrThrow(groupId);
    if (group.ownerId !== userId) throw new ForbiddenException('仅群主可解散群组');
    await this.prisma.group.update({
      where: { id: groupId },
      data: { deletedAt: new Date() },
    });
    const members = await this.prisma.groupMember.findMany({
      where: { groupId, status: MemberStatus.active },
      select: { userId: true },
    });
    const targets = members
      .map((m) => m.userId)
      .filter((uid) => uid !== userId);
    if (targets.length > 0) {
      await this.notificationsService.createMany(targets, {
        type: 'member',
        title: '群组已解散',
        body: `「${group.name}」已被群主解散`,
        refType: 'group',
        refId: groupId,
      });
    }
    return { success: true };
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

  /** 按账户名添加成员（任一 active 成员可添加；占位账号不可被"添加"） */
  async addMember(userId: string, groupId: string, accountName: string) {
    await this.assertMember(groupId, userId);
    const group = await this.getGroupOrThrow(groupId);
    const target = await this.prisma.user.findFirst({
      // 非注册成员由群主在邀请页单独添加，不能通过账户名直加；
      // 否则任何人可凭 ~guest_ 账户名把别群的非注册成员拉进本群
      where: { accountName, deletedAt: null, isPlaceholder: false },
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
      include: { user: { select: { isPlaceholder: true } } },
    });
    if (!membership) throw new NotFoundException('新群主必须是群成员');
    // 非注册成员（占位账号）没有账号、不能登录：转让后群将无人可管理
    if (membership.user?.isPlaceholder) {
      throw new BadRequestException('非注册成员没有账号，不能成为群主');
    }
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
      include: {
        user: {
          select: {
            id: true,
            accountName: true,
            nickname: true,
            avatarUrl: true,
            isPlaceholder: true,
          },
        },
      },
    });
    return {
      inviteCode: group.inviteCode,
      joinedCount: members.filter((m) => m.status === MemberStatus.active).length,
      members: members.map((m) => this.toMemberView(m)),
    };
  }

  // ---------- 非注册成员（占位账号）----------
  // 见 CONTEXT.md「非注册成员」/「占位账号」、ADR-0001、技术方案 §3.4 §4.2

  /** 仅群主可操作 */
  private assertOwner(ownerId: string, userId: string, message: string) {
    if (ownerId !== userId) throw new ForbiddenException(message);
  }

  /** 成员显示名：昵称优先，其次账户名（占位账号账户名不可用，故只认昵称） */
  private displayNameOf(user: {
    nickname: string;
    accountName: string;
    isPlaceholder: boolean;
  }): string {
    return (user.nickname || (user.isPlaceholder ? '' : user.accountName) || '').trim();
  }

  /** 群内重名校验：与全体成员显示名比对（含已退出成员，避免历史同名混淆） */
  private async assertDisplayNameFree(
    groupId: string,
    name: string,
    exceptUserId?: string,
  ) {
    const members = await this.prisma.groupMember.findMany({
      where: { groupId },
      include: {
        user: {
          select: { id: true, nickname: true, accountName: true, isPlaceholder: true },
        },
      },
    });
    const dup = members.some(
      (m) => m.userId !== exceptUserId && this.displayNameOf(m.user) === name,
    );
    if (dup) throw new ConflictException('群内已有同名成员，换个名字吧');
  }

  /** 占位账号账户名：前缀 + 20 位随机（varchar(32) 内） */
  private async createUniquePlaceholderAccountName(): Promise<string> {
    for (let attempt = 0; attempt < 5; attempt++) {
      const name = PLACEHOLDER_PREFIX + randomUUID().replace(/-/g, '').slice(0, 20);
      const exists = await this.prisma.user.findUnique({ where: { accountName: name } });
      if (!exists) return name;
    }
    throw new ConflictException('非注册成员创建失败，请重试');
  }

  /** 取本群内未被认领的占位账号成员 */
  private async getPlaceholderMember(groupId: string, placeholderUserId: string) {
    // 先看账号本身：认领后群成员行会被删除（目标已在群时），
    // 但占位账号行会保留并记下 mergedIntoUserId —— 重复认领必须报「已认领」而不是「不存在」
    const user = await this.prisma.user.findFirst({
      where: { id: placeholderUserId, isPlaceholder: true },
      select: {
        id: true,
        nickname: true,
        accountName: true,
        isPlaceholder: true,
        mergedIntoUserId: true,
        deletedAt: true,
      },
    });
    if (!user) throw new NotFoundException('非注册成员不存在');
    if (user.mergedIntoUserId || user.deletedAt) {
      throw new ConflictException('该成员已被认领，不能重复操作');
    }
    const membership = await this.prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId, userId: placeholderUserId } },
    });
    if (!membership) throw new NotFoundException('该成员不在本群');
    return { ...membership, user };
  }

  /** 认领前置校验：占位账号 ∈ 本群且未被认领、目标是真实账号 */
  private async assertClaimable(
    groupId: string,
    placeholderUserId: string,
    targetUserId: string,
  ) {
    const placeholder = await this.getPlaceholderMember(groupId, placeholderUserId);
    const target = await this.prisma.user.findFirst({
      where: { id: targetUserId, isPlaceholder: false, deletedAt: null },
      select: { id: true, accountName: true, nickname: true },
    });
    if (!target) throw new NotFoundException('目标账号不存在');
    if (target.id === placeholderUserId) throw new BadRequestException('不能认领到本人');
    return { placeholder, target };
  }

  /** 认领影响范围：将合并多少笔账单、多少条结算记录（确认弹窗用） */
  private async claimImpact(
    groupId: string,
    placeholderUserId: string,
    targetUserId: string,
  ) {
    const [partRows, payerRows, settlementsFrom, settlementsTo] = await Promise.all([
      this.prisma.billParticipant.findMany({
        where: { userId: placeholderUserId },
        select: { billId: true },
      }),
      this.prisma.bill.findMany({
        where: { payerId: placeholderUserId, deletedAt: null },
        select: { id: true },
      }),
      this.prisma.settlement.count({ where: { groupId, fromUserId: placeholderUserId } }),
      this.prisma.settlement.count({ where: { groupId, toUserId: placeholderUserId } }),
    ]);
    const billIds = new Set<string>([
      ...partRows.map((p) => p.billId),
      ...payerRows.map((b) => b.id),
    ]);
    return {
      billCount: billIds.size,
      settlementCount: settlementsFrom + settlementsTo,
      targetUserId,
    };
  }

  /** 添加非注册成员（仅群主） */
  async addPlaceholderMember(userId: string, groupId: string, displayName: string) {
    await this.assertMember(groupId, userId);
    const group = await this.getGroupOrThrow(groupId);
    this.assertOwner(group.ownerId, userId, '仅群主可添加非注册成员');

    const name = sanitizeDisplayName(displayName);
    if (!name) throw new BadRequestException('请填写成员名称');
    await this.assertDisplayNameFree(groupId, name);

    const activeMembers = await this.prisma.groupMember.findMany({
      where: { groupId, status: MemberStatus.active },
      select: { userId: true },
    });
    if (activeMembers.length >= MAX_GROUP_MEMBERS) {
      throw new ConflictException(`群成员已达上限 ${MAX_GROUP_MEMBERS} 人`);
    }

    const placeholder = await this.prisma.user.create({
      data: {
        accountName: await this.createUniquePlaceholderAccountName(),
        nickname: name,
        passwordHash: PLACEHOLDER_SECRET_HASH,
        securityQuestion: '',
        securityAnswerHash: PLACEHOLDER_SECRET_HASH,
        isPlaceholder: true,
      },
    });
    await this.prisma.groupMember.create({
      data: { groupId, userId: placeholder.id, status: MemberStatus.active },
    });
    // 其他成员照常收到「新成员加入」播报；占位账号自己不接收通知
    await this.notifyMembersJoined(groupId, group.name, name, [userId, placeholder.id]);

    return {
      userId: placeholder.id,
      accountName: '',
      nickname: name,
      avatarUrl: null,
      isPlaceholder: true,
      status: MemberStatus.active,
      joinedAt: placeholder.createdAt,
    };
  }

  /** 修改非注册成员名称（仅群主；群内不可重名） */
  async renamePlaceholderMember(
    userId: string,
    groupId: string,
    placeholderUserId: string,
    displayName: string,
  ) {
    await this.assertMember(groupId, userId);
    const group = await this.getGroupOrThrow(groupId);
    this.assertOwner(group.ownerId, userId, '仅群主可修改非注册成员名称');
    await this.getPlaceholderMember(groupId, placeholderUserId);

    const name = sanitizeDisplayName(displayName);
    if (!name) throw new BadRequestException('请填写成员名称');
    await this.assertDisplayNameFree(groupId, name, placeholderUserId);

    await this.prisma.user.update({
      where: { id: placeholderUserId },
      data: { nickname: name },
    });
    return { userId: placeholderUserId, nickname: name, isPlaceholder: true };
  }

  /** 认领前预览（仅群主，只读） */
  async claimPreview(
    userId: string,
    groupId: string,
    placeholderUserId: string,
    targetUserId: string,
  ) {
    await this.assertMember(groupId, userId);
    const group = await this.getGroupOrThrow(groupId);
    this.assertOwner(group.ownerId, userId, '仅群主可认领非注册成员');
    const { placeholder, target } = await this.assertClaimable(
      groupId,
      placeholderUserId,
      targetUserId,
    );
    const targetMembership = await this.prisma.groupMember.findUnique({
      where: { groupId_userId: { groupId, userId: targetUserId } },
      select: { status: true },
    });
    const impact = await this.claimImpact(groupId, placeholderUserId, targetUserId);
    return {
      ...impact,
      placeholderName: placeholder.user.nickname,
      targetName: target.nickname || target.accountName,
      // 目标不在群里 → 认领后自动入群（确认文案用）
      targetInGroup: targetMembership?.status === MemberStatus.active,
    };
  }

  /**
   * 认领：把占位账号的全部历史合并到真实账号（仅群主，不可撤销）。
   * 迁移步骤严格按技术方案 §3.4，整体单事务，任一步失败全部回滚。
   */
  async claimPlaceholderMember(
    userId: string,
    groupId: string,
    placeholderUserId: string,
    targetUserId: string,
  ) {
    await this.assertMember(groupId, userId);
    const group = await this.getGroupOrThrow(groupId);
    this.assertOwner(group.ownerId, userId, '仅群主可认领非注册成员');
    const { placeholder, target } = await this.assertClaimable(
      groupId,
      placeholderUserId,
      targetUserId,
    );
    const impact = await this.claimImpact(groupId, placeholderUserId, targetUserId);

    await this.prisma.$transaction(async (tx) => {
      // ① 群成员关系：目标已在群 → 删占位行、加入时间取更早；否则占位行改挂目标（自动入群）
      const targetMembership = await tx.groupMember.findUnique({
        where: { groupId_userId: { groupId, userId: targetUserId } },
      });
      const placeholderMembership = await tx.groupMember.findUnique({
        where: { groupId_userId: { groupId, userId: placeholderUserId } },
      });
      if (targetMembership) {
        if (
          placeholderMembership &&
          placeholderMembership.joinedAt.getTime() < targetMembership.joinedAt.getTime()
        ) {
          await tx.groupMember.update({
            where: { id: targetMembership.id },
            data: { joinedAt: placeholderMembership.joinedAt },
          });
        }
        if (placeholderMembership) {
          await tx.groupMember.delete({ where: { id: placeholderMembership.id } });
        }
      } else if (placeholderMembership) {
        await tx.groupMember.update({
          where: { id: placeholderMembership.id },
          data: { userId: targetUserId },
        });
      }

      // ② 账单参与人：同账单两人都有份额 → 金额相加（保住账单总额）、paid/exempt 取 AND；其余改挂
      const placeholderParts = await tx.billParticipant.findMany({
        where: { userId: placeholderUserId },
      });
      for (const pp of placeholderParts) {
        const tp = await tx.billParticipant.findUnique({
          where: { billId_userId: { billId: pp.billId, userId: targetUserId } },
        });
        if (tp) {
          const bothPaid = tp.paid && pp.paid;
          await tx.billParticipant.update({
            where: { id: tp.id },
            data: {
              shareAmountCents: tp.shareAmountCents + pp.shareAmountCents,
              paid: bothPaid,
              exempt: tp.exempt && pp.exempt,
              paidAt: bothPaid ? (tp.paidAt ?? pp.paidAt) : null,
            },
          });
          await tx.billParticipant.delete({ where: { id: pp.id } });
        } else {
          await tx.billParticipant.update({
            where: { id: pp.id },
            data: { userId: targetUserId },
          });
        }
      }

      // ③ 垫付人（creator 无需处理：占位账号不可能登录创建账单）
      await tx.bill.updateMany({
        where: { payerId: placeholderUserId },
        data: { payerId: targetUserId },
      });

      // ④ 结算记录：历史改挂；该群 pending 方案是派生数据，清掉由 getSettlement 重建
      await tx.settlement.updateMany({
        where: { groupId, fromUserId: placeholderUserId },
        data: { fromUserId: targetUserId },
      });
      await tx.settlement.updateMany({
        where: { groupId, toUserId: placeholderUserId },
        data: { toUserId: targetUserId },
      });
      await tx.settlement.deleteMany({
        where: { groupId, status: SettlementStatus.pending },
      });

      // ⑤ 免分摊名单（TEXT[]，无外键保护）
      const exemptIds = group.defaultExemptUserIds ?? [];
      if (exemptIds.includes(placeholderUserId)) {
        await tx.group.update({
          where: { id: groupId },
          data: {
            defaultExemptUserIds: [
              ...new Set(exemptIds.map((id) => (id === placeholderUserId ? targetUserId : id))),
            ],
          },
        });
      }

      // ⑥ 定期账单模板（JSON，无外键保护）：替换 userId，重复则金额相加、免摊取 AND
      const templates = await tx.regularBill.findMany({
        where: { groupId, deletedAt: null },
        select: { id: true, participants: true },
      });
      for (const rb of templates) {
        const list = Array.isArray(rb.participants)
          ? (rb.participants as Record<string, unknown>[])
          : [];
        if (!list.some((p) => p?.userId === placeholderUserId)) continue;
        const merged = new Map<string, Record<string, unknown>>();
        for (const p of list) {
          const uid = (p?.userId === placeholderUserId ? targetUserId : p?.userId) as
            | string
            | undefined;
          if (!uid) continue;
          const prev = merged.get(uid);
          const prevShare = prev?.shareAmountCents as number | undefined;
          const curShare = p?.shareAmountCents as number | undefined;
          if (!prev) {
            merged.set(uid, { ...p, userId: uid });
            continue;
          }
          merged.set(uid, {
            ...prev,
            userId: uid,
            // 两行都未显式给金额时保持「均摊」语义（不加 0）
            ...(prevShare === undefined && curShare === undefined
              ? {}
              : { shareAmountCents: (prevShare ?? 0) + (curShare ?? 0) }),
            exempt: Boolean(prev.exempt) && Boolean(p?.exempt),
          });
        }
        await tx.regularBill.update({
          where: { id: rb.id },
          data: { participants: [...merged.values()] as Prisma.InputJsonValue },
        });
      }

      // ⑦ 占位账号行本身：保留不删，记录合并去向（可追溯 + 避免外键悬空）
      await tx.user.update({
        where: { id: placeholderUserId },
        data: { deletedAt: new Date(), mergedIntoUserId: targetUserId },
      });
    });

    return {
      success: true,
      placeholderUserId,
      targetUserId,
      placeholderName: placeholder.user.nickname,
      targetName: target.nickname || target.accountName,
      billCount: impact.billCount,
      settlementCount: impact.settlementCount,
    };
  }
}
