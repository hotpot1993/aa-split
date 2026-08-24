/** 业务日期（YYYY-MM-DD）的工具函数，避免 UTC 偏移 */

/** 将 YYYY-MM-DD 解析为本地时区 Date（午夜） */
export function parseDateDay(input: string): Date {
  const [y, m, d] = input.split('-').map((n) => Number(n));
  return new Date(y, m - 1, d);
}

/** 将 Date 格式化为 YYYY-MM-DD（取本地时区年/月/日） */
export function formatDateDay(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date;
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}
