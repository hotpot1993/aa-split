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
