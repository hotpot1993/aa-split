import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';

/** 所有成功响应统一包装为 { code: 0, message: "ok", data } */
@Injectable()
export class TransformInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(
      map((data) => {
        // SSE 通过 @Res() 手动写出，data 为 undefined，不进行包装
        if (data === undefined) return data;
        return { code: 0, message: 'ok', data };
      }),
    );
  }
}
