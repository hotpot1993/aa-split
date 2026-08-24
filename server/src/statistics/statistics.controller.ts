import { Controller, Get, Query } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, Min } from 'class-validator';
import { StatisticsService } from './statistics.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../common/types';

class StatisticsQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(2000)
  year?: number;
}

@ApiTags('statistics')
@ApiBearerAuth()
@Controller('me/statistics')
export class StatisticsController {
  constructor(private readonly statisticsService: StatisticsService) {}

  @Get()
  statistics(
    @CurrentUser() user: JwtPayload,
    @Query() query: StatisticsQueryDto,
  ) {
    const year = query.year ?? new Date().getFullYear();
    return this.statisticsService.statistics(user.sub, year);
  }
}
