import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';

/** 标记一个路由/控制器为公开（跳过全局 JwtAuthGuard） */
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
