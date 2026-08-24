import { BillCycle } from '@prisma/client';

/** Asia/Shanghai（以进程本地时区近似，Docker 通过 TZ=Asia/Shanghai 设定） */
const RUN_HOUR = 3;

/** 设置到当日 03:00 */
function atRunHour(date: Date): Date {
  const d = new Date(date);
  d.setHours(RUN_HOUR, 0, 0, 0);
  return d;
}

function addDays(date: Date, days: number): Date {
  const d = new Date(date);
  d.setDate(d.getDate() + days);
  return d;
}

function daysInMonth(year: number, monthIndex: number): number {
  return new Date(year, monthIndex + 1, 0).getDate();
}

/**
 * 计算下次运行时间。
 * weekly: 下次与 dayOfWeek 相同的那个日期（当日为 dayOfWeek 则 +7）
 * biweekly: 与 weekly 相同，但当日为 dayOfWeek 则 +14（两周一节拍）
 * monthly: 下一个 dayOfMonth；dayOfMonth 遇 29-31 顺延为当月最后一天
 * @param from 参考时间：创建=now；扫描=该定期账单当前 nextRunAt
 */
export function computeNextRunAt(
  cycle: BillCycle,
  dayOfWeek: number | null,
  dayOfMonth: number | null,
  from: Date,
): Date {
  if (cycle === BillCycle.weekly && dayOfWeek !== null) {
    const diff = (dayOfWeek - from.getDay() + 7) % 7;
    return atRunHour(addDays(from, diff === 0 ? 7 : diff));
  }
  if (cycle === BillCycle.biweekly && dayOfWeek !== null) {
    const diff = (dayOfWeek - from.getDay() + 7) % 7;
    return atRunHour(addDays(from, diff === 0 ? 14 : diff));
  }
  if (cycle === BillCycle.monthly && dayOfMonth !== null) {
    const target = Math.min(dayOfMonth, 28); // 先按普通天数定位，再钳制到 29-31
    let candidate = new Date(from.getFullYear(), from.getMonth(), target);
    const thisMonthDays = daysInMonth(from.getFullYear(), from.getMonth());
    // 若本月该日已过，则取下月
    if (from.getDate() >= target) {
      candidate = new Date(from.getFullYear(), from.getMonth() + 1, target);
    }
    // 29-31 顺延为当月最后一天
    const y = candidate.getFullYear();
    const m = candidate.getMonth();
    const lastDay = daysInMonth(y, m);
    const effectiveDay = Math.min(dayOfMonth, lastDay);
    return atRunHour(new Date(y, m, effectiveDay));
  }
  throw new Error('定期账单缺少必要的时间字段');
}
