import { Controller, Get, Query, Res } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { Response } from 'express';
import { ExportService } from './export.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../common/types';
import { IsIn } from 'class-validator';

class ExportQueryDto {
  @IsIn(['xlsx', 'csv'])
  format!: 'xlsx' | 'csv';
}

@ApiTags('export')
@ApiBearerAuth()
@Controller('me/export')
export class ExportController {
  constructor(private readonly exportService: ExportService) {}

  @Get()
  async exportFile(
    @CurrentUser() user: JwtPayload,
    @Query() query: ExportQueryDto,
    @Res() res: Response,
  ) {
    const file = await this.exportService.exportUserData(user.sub, query.format);
    res.setHeader('Content-Type', file.contentType);
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="${file.filename}"`,
    );
    res.send(file.buffer);
  }
}
