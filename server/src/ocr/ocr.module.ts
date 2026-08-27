import { Module } from '@nestjs/common';
import { BullModule } from '@nestjs/bullmq';
import { OcrService } from './ocr.service';
import { OcrProcessor } from './ocr.processor';
import { OcrController } from './ocr.controller';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [BullModule.registerQueue({ name: 'receipt-ocr' }), NotificationsModule],
  controllers: [OcrController],
  providers: [OcrService, OcrProcessor],
  exports: [OcrService],
})
export class OcrModule {}
