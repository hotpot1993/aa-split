import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsOptional, IsString, MaxLength } from 'class-validator';
import { UsersService } from './users.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../common/types';

class SearchQueryDto {
  @IsOptional()
  @IsString()
  @MaxLength(32)
  accountName?: string;
}

@ApiTags('users')
@ApiBearerAuth()
@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  /** 搜索账户名（用于添加群成员） */
  @Get('search')
  search(
    @Query() query: SearchQueryDto,
    @CurrentUser() user: JwtPayload,
  ) {
    return this.usersService.search(query.accountName || '', user.sub);
  }

  /** 公开资料 */
  @Get(':id')
  publicProfile(@Param('id') id: string) {
    return this.usersService.getPublicProfile(id);
  }
}
