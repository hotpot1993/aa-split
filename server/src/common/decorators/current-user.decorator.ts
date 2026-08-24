import { createParamDecorator, ExecutionContext } from '@nestjs/common';

/** 从请求中取当前登录用户（由 JwtAuthGuard 注入 req.user） */
export const CurrentUser = createParamDecorator(
  (data: string | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user = request.user;
    return data ? user?.[data] : user;
  },
);
