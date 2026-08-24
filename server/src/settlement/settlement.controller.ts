import { Controller, Get, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { SettlementService } from './settlement.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../common/types';

@ApiTags('settlement')
@ApiBearerAuth()
@Controller()
export class SettlementController {
  constructor(private readonly settlementService: SettlementService) {}

  /** 计算最少转账结算方案（并落库为最新 pending 记录） */
  @Get('groups/:id/settlement')
  getSettlement(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.settlementService.getSettlement(user.sub, id);
  }

  /** 标记某笔结算记录已收款 */
  @HttpCode(HttpStatus.OK)
  @Post('settlements/:id/paid')
  markPaid(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.settlementService.markPaid(user.sub, id);
  }
}
