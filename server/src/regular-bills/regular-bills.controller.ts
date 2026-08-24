import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { RegularBillsService } from './regular-bills.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../common/types';
import { CreateRegularBillDto } from './dto/create-regular-bill.dto';
import { UpdateRegularBillDto } from './dto/update-regular-bill.dto';

@ApiTags('regular-bills')
@ApiBearerAuth()
@Controller('regular-bills')
export class RegularBillsController {
  constructor(private readonly regularBillsService: RegularBillsService) {}

  @Get()
  list(@CurrentUser() user: JwtPayload) {
    return this.regularBillsService.listMy(user.sub);
  }

  @Post()
  create(@CurrentUser() user: JwtPayload, @Body() dto: CreateRegularBillDto) {
    return this.regularBillsService.create(user.sub, dto);
  }

  @Get(':id')
  detail(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.regularBillsService.get(user.sub, id);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Body() dto: UpdateRegularBillDto,
  ) {
    return this.regularBillsService.update(user.sub, id, dto);
  }

  @Delete(':id')
  remove(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.regularBillsService.remove(user.sub, id);
  }
}
