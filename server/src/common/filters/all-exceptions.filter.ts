import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Response } from 'express';

/**
 * 全局异常过滤器：把所有异常统一映射为 { code: 非0, message }。
 * - HttpException（含 class-validator 校验异常）→ 提取友好 message
 * - Prisma 已知错误：P2002 → 409，P2025 → 404
 * - 其余 → 500
 */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = '服务器内部错误';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const res = exception.getResponse();
      if (typeof res === 'string') {
        message = res;
      } else if (res && typeof res === 'object') {
        const m = (res as any).message;
        if (Array.isArray(m)) message = m.join('; ');
        else if (typeof m === 'string') message = m;
        else message = exception.message;
      } else {
        message = exception.message;
      }
    } else if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      if (exception.code === 'P2002') {
        status = HttpStatus.CONFLICT;
        message = '数据已存在，请检查唯一字段（如账户名已占用）';
      } else if (exception.code === 'P2025') {
        status = HttpStatus.NOT_FOUND;
        message = '资源不存在或已被删除';
      } else if (exception.code === 'P2003') {
        status = HttpStatus.BAD_REQUEST;
        message = '关联数据不合法';
      } else if (exception.code === 'P2028' || exception.code === 'P1001') {
        status = HttpStatus.SERVICE_UNAVAILABLE;
        message = '数据库连接异常，请稍后重试';
      } else {
        message = `数据库错误(${exception.code})`;
      }
    } else if (exception instanceof Error) {
      message = exception.message || '服务器内部错误';
      this.logger.error(exception.message, exception.stack);
    } else {
      this.logger.error(String(exception));
    }

    // 成功响应用 code:0；错误统一用 HTTP 状态码作为业务 code
    response.status(status).json({ code: status, message });
  }
}
