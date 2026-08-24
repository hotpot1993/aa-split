/** JWT 载荷（access & refresh 共用） */
export interface JwtPayload {
  /** 用户 id */
  sub: string;
  /** 账户名 */
  accountName: string;
  /** 昵称 */
  nickname: string;
}

/** 请求上下文中的当前用户（req.user） */
export type AuthUser = JwtPayload;

/** 分页响应 */
export interface Paginated<T> {
  list: T[];
  total: number;
  page: number;
  pageSize: number;
}
