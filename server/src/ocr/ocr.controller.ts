import {
  BadRequestException,
  Controller,
  Param,
  Post,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBearerAuth, ApiConsumes, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { OcrService } from './ocr.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { JwtPayload } from '../common/types';

@ApiTags('ocr')
@ApiBearerAuth()
@Controller()
export class OcrController {
  constructor(private readonly ocrService: OcrService) {}

  /** 草稿预上传：记账页拍/选后立刻上传暂存并识别（返回 uploadId，账单创建时绑定，24h 未绑定回收） */
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }))
  @Throttle({ default: { limit: 10, ttl: 60000 } })
  @Post('receipts/pre-upload')
  preUpload(
    @CurrentUser() user: JwtPayload,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) {
      throw new BadRequestException('缺少凭证文件');
    }
    return this.ocrService.preUpload(user.sub, file);
  }

  /** 重试识别（P33 凭证；权限：创建者/垫付人/群主） */
  @Post('bills/:id/receipts/:receiptId/ocr/retry')
  retry(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
    @Param('receiptId') receiptId: string,
  ) {
    return this.ocrService.retryOcr(user.sub, id, receiptId);
  }
}
