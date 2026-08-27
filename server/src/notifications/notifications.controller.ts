import {
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  Req,
  Res,
  UnauthorizedException,
} from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Request, Response } from 'express';
import { NotificationsService } from './notifications.service';
import { NotificationSseService } from './notification-sse.service';
import { CurrentUser } from '../common/decorators/current-user.decorator';
import { Public } from '../common/decorators/public.decorator';
import { JwtPayload } from '../common/types';
import { PaginationQueryDto } from '../common/dto/pagination.dto';
import { IsBooleanString, IsOptional } from 'class-validator';

class NotificationQueryDto extends PaginationQueryDto {
  @IsOptional()
  type?: string;

  @IsOptional()
  @IsBooleanString()
  isRead?: string;
}

@ApiTags('notifications')
@ApiBearerAuth()
@Controller('notifications')
export class NotificationsController {
  constructor(
    private readonly notificationsService: NotificationsService,
    private readonly sse: NotificationSseService,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  @Get()
  list(
    @CurrentUser() user: JwtPayload,
    @Query() query: NotificationQueryDto,
  ) {
    const isRead = query.isRead === undefined ? undefined : query.isRead === 'true';
    return this.notificationsService.list(user.sub, {
      type: query.type,
      isRead,
      page: query.page,
      pageSize: query.pageSize,
    });
  }

  @Get('unread-count')
  unreadCount(@CurrentUser() user: JwtPayload) {
    return this.notificationsService.unreadCount(user.sub);
  }

  @Post('read-all')
  readAll(@CurrentUser() user: JwtPayload) {
    return this.notificationsService.readAll(user.sub);
  }

  @Post(':id/read')
  readOne(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.notificationsService.readOne(user.sub, id);
  }

  /** 清空本人全部消息（消息中心「清空」入口） */
  @Delete()
  removeAll(@CurrentUser() user: JwtPayload) {
    return this.notificationsService.removeAll(user.sub);
  }

  /** 删除单条消息（消息中心左滑 / 长按删除） */
  @Delete(':id')
  removeOne(@CurrentUser() user: JwtPayload, @Param('id') id: string) {
    return this.notificationsService.remove(user.sub, id);
  }

  /** SSE 实时通知流（支持 ?access_token= 与 Authorization header） */
  @Public()
  @Get('stream')
  stream(
    @Req() req: Request,
    @Res() res: Response,
    @Query('access_token') accessToken?: string,
  ) {
    const token =
      accessToken ||
      (req.headers.authorization?.startsWith('Bearer ')
        ? req.headers.authorization.substring(7)
        : undefined);

    if (!token) {
      throw new UnauthorizedException('未登录或登录已过期');
    }
    let payload: JwtPayload;
    try {
      payload = this.jwtService.verify<JwtPayload>(token, {
        secret: this.configService.get<string>('JWT_ACCESS_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('登录已过期，请重新登录');
    }

    res.status(200);
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    this.sse.subscribe(payload.sub, res);
    // 心跳注释，避免代理/浏览器断开连接
    const heartbeat = setInterval(() => {
      res.write(': ping\n\n');
    }, 25000);

    req.on('close', () => {
      clearInterval(heartbeat);
      this.sse.unsubscribe(payload.sub, res);
    });
  }
}
