import { Type } from 'class-transformer';
import { IsInt, IsOptional, Max, Min } from 'class-validator';

/** 统一分页查询 ?page=1&pageSize=20（默认 20，上限 100） */
export class PaginationQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page: number = 1;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(100)
  pageSize: number = 20;
}

export function paginate<T>(
  list: T[],
  total: number,
  page: number,
  pageSize: number,
) {
  return { list, total, page, pageSize };
}
