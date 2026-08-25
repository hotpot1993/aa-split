import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { BillsService } from './bills.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../common/types';
import { PaginationQueryDto } from '../common/dto/pagination.dto';
import { CreateBillDto } from './dto/create-bill.dto';
import { UpdateBillDto } from './dto/update-bill.dto';
import { MarkPaidDto } from './dto/mark-paid.dto';
import { RemindDto } from './dto/remind.dto';

@ApiTags('bills')
@ApiBearerAuth()
@Controller('bills')
export class BillsController {
  constructor(private readonly billsService: BillsService) {}

  @Post()
  create(@CurrentUser() user: JwtPayload, @Body() dto: CreateBillDto) {
    return this.billsService.createBill(user.sub, dto);
  }

  @Get(':id')
  detail(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.billsService.getBill(user.sub, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() dto: UpdateBillDto,
  ) {
    return this.billsService.updateBill(user.sub, id, dto);
  }

  @Delete(':id')
  remove(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.billsService.deleteBill(user.sub, id);
  }

  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file'))
  @Post(':id/receipts')
  uploadReceipt(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.billsService.uploadReceipt(user.sub, id, file);
  }

  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file'))
  @Post(':id/receipts/:receiptId/replace')
  replaceReceipt(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Param('receiptId') receiptId: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    return this.billsService.replaceReceipt(user.sub, id, receiptId, file);
  }

  @Post(':id/mark-paid')
  markPaid(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() dto: MarkPaidDto,
  ) {
    return this.billsService.markPaid(user.sub, id, dto.userId, dto.paid);
  }

  @Post(':id/remind')
  remind(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() dto: RemindDto,
  ) {
    return this.billsService.remind(user.sub, id, dto.userIds, dto.message);
  }
}

/** /groups/:id/bills —— 群账单流水 */
@ApiTags('bills')
@ApiBearerAuth()
@Controller('groups/:groupId/bills')
export class GroupBillsController {
  constructor(private readonly billsService: BillsService) {}

  @Get()
  list(
    @CurrentUser() user: JwtPayload,
    @Param('groupId') groupId: string,
    @Query() query: PaginationQueryDto,
  ) {
    return this.billsService.listBills(user.sub, groupId, query.page, query.pageSize);
  }

  /** 一键结清：群内全部未结清账单统一标记已付 */
  @Post('settle-all')
  settleAll(
    @CurrentUser() user: JwtPayload,
    @Param('groupId') groupId: string,
  ) {
    return this.billsService.settleAll(user.sub, groupId);
  }
}
