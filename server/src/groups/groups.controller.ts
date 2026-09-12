import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  HttpCode,
  HttpStatus,
  Query,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { GroupsService } from './groups.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../common/types';
import { CreateGroupDto } from './dto/create-group.dto';
import { UpdateGroupDto } from './dto/update-group.dto';
import { AddMemberDto } from './dto/add-member.dto';
import { JoinGroupDto } from './dto/join-group.dto';
import { TransferOwnerDto } from './dto/transfer-owner.dto';
import {
  ClaimPlaceholderMemberDto,
  ClaimPreviewQueryDto,
  PlaceholderMemberNameDto,
} from './dto/placeholder-member.dto';

@ApiTags('groups')
@ApiBearerAuth()
@Controller('groups')
export class GroupsController {
  constructor(private readonly groupsService: GroupsService) {}

  @Get()
  list(@CurrentUser() user: JwtPayload) {
    return this.groupsService.listMyGroups(user.sub);
  }

  @Post()
  create(@CurrentUser() user: JwtPayload, @Body() dto: CreateGroupDto) {
    return this.groupsService.createGroup(user.sub, dto);
  }

  @Get(':id')
  detail(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.groupsService.getGroup(user.sub, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() dto: UpdateGroupDto,
  ) {
    return this.groupsService.updateGroup(user.sub, id, dto);
  }

  @Delete(':id')
  remove(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.groupsService.deleteGroup(user.sub, id);
  }

  @Post(':id/members')
  addMember(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() dto: AddMemberDto,
  ) {
    return this.groupsService.addMember(user.sub, id, dto.accountName);
  }

  @HttpCode(HttpStatus.OK)
  @Delete(':id/members/:userId')
  removeMember(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Param('userId') memberId: string,
  ) {
    return this.groupsService.removeMember(user.sub, id, memberId);
  }

  // ---------- 非注册成员（占位账号）：仅群主可调用 ----------

  /** 添加非注册成员（只填名称，无需对方注册） */
  @Post(':id/placeholder-members')
  addPlaceholderMember(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() dto: PlaceholderMemberNameDto,
  ) {
    return this.groupsService.addPlaceholderMember(user.sub, id, dto.displayName);
  }

  /** 认领前预览：将合并多少笔账单 / 多少条结算记录 */
  @Get(':id/placeholder-members/:userId/claim-preview')
  claimPreview(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Param('userId') placeholderUserId: string,
    @Query() query: ClaimPreviewQueryDto,
  ) {
    return this.groupsService.claimPreview(
      user.sub,
      id,
      placeholderUserId,
      query.targetUserId,
    );
  }

  /** 修改非注册成员名称 */
  @HttpCode(HttpStatus.OK)
  @Patch(':id/placeholder-members/:userId')
  renamePlaceholderMember(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Param('userId') placeholderUserId: string,
    @Body() dto: PlaceholderMemberNameDto,
  ) {
    return this.groupsService.renamePlaceholderMember(
      user.sub,
      id,
      placeholderUserId,
      dto.displayName,
    );
  }

  /** 认领（绑定到账户）：把非注册成员的全部历史合并到真实账号，不可撤销 */
  @HttpCode(HttpStatus.OK)
  @Post(':id/placeholder-members/:userId/claim')
  claimPlaceholderMember(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Param('userId') placeholderUserId: string,
    @Body() dto: ClaimPlaceholderMemberDto,
  ) {
    return this.groupsService.claimPlaceholderMember(
      user.sub,
      id,
      placeholderUserId,
      dto.targetUserId,
    );
  }

  @HttpCode(HttpStatus.OK)
  @Post(':id/transfer')
  transferOwner(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() dto: TransferOwnerDto,
  ) {
    return this.groupsService.transferOwner(user.sub, id, dto.newOwnerId);
  }

  @Post('join')
  join(@CurrentUser() user: JwtPayload, @Body() dto: JoinGroupDto) {
    return this.groupsService.joinGroup(user.sub, dto.inviteCode);
  }

  @Get(':id/invite')
  invite(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.groupsService.getInvite(user.sub, id);
  }
}
