/**
 * 内存版 FakePrisma —— e2e 契约测试专用（不连接数据库）。
 *
 * 实现 PrismaService 在核心链路上用到的查询子集：
 *   findUnique / findFirst / findMany / create(含嵌套 create) / update(含 increment) /
 *   updateMany / deleteMany / count / createMany / $transaction
 * where 算子子集：等值、null、{in}、{contains}、{gt,gte,lt,lte}、{not}、{equals}
 * include 子集：user、group(owner/_count)、groupMember(user|group)、bill(creator/payer/participants.user)
 *
 * 字段名按 Prisma 模型（camelCase），与 schema.prisma 一致。
 */
import { randomUUID } from 'crypto';

type Row = Record<string, any>;

function matches(row: Row, where: Record<string, any>): boolean {
  for (const [k, v] of Object.entries(where)) {
    if (v === null) {
      if (row[k] != null) return false;
      continue;
    }
    if (typeof v === 'object' && !(v instanceof Date)) {
      if ('in' in v) {
        if (!(v.in as any[]).includes(row[k])) return false;
      } else if ('contains' in v) {
        if (!String(row[k] ?? '').includes(String(v.contains))) return false;
      } else if ('gt' in v) {
        if (!(row[k] > v.gt)) return false;
      } else if ('gte' in v) {
        if (!(row[k] >= v.gte)) return false;
      } else if ('lt' in v) {
        if (!(row[k] < v.lt)) return false;
      } else if ('lte' in v) {
        if (!(row[k] <= v.lte)) return false;
      } else if ('not' in v) {
        const not = v.not;
        // not: null 表示"字段非 null"；其它表示"不等于"
        if (not === null ? row[k] == null : row[k] === not) return false;
      } else if ('equals' in v) {
        if (row[k] !== v.equals) return false;
      } else {
        // 复合唯一键：{ fieldA_fieldB: { fieldA: x, fieldB: y } }
        const keys = k.split('_');
        if (
          keys.length >= 2 &&
          keys.every((kk) => v[kk] !== undefined)
        ) {
          if (!keys.every((kk) => row[kk] === v[kk])) return false;
        } else {
          return false;
        }
      }
    } else if (row[k] !== v) {
      return false;
    }
  }
  return true;
}

function sortRows(rows: Row[], orderBy: any): Row[] {
  const os = Array.isArray(orderBy) ? orderBy : orderBy ? [orderBy] : [];
  if (os.length === 0) return rows;
  return [...rows].sort((a, b) => {
    for (const o of os) {
      const [key, dir] = Object.entries(o as object)[0];
      const av = a[key];
      const bv = b[key];
      if (av === bv) continue;
      const cmp = av > bv ? 1 : -1;
      return dir === 'desc' ? -cmp : cmp;
    }
    return 0;
  });
}

export class FakePrisma {
  /** 内存数据（模型名 → 行数组） */
  private store: Record<string, Row[]> = {
    user: [],
    group: [],
    groupMember: [],
    bill: [],
    billParticipant: [],
    receipt: [],
    receiptUpload: [],
    notification: [],
    regularBill: [],
    settlement: [],
    userDevice: [],
  };

  user = new Model('user', this);
  group = new Model('group', this);
  groupMember = new Model('groupMember', this);
  bill = new Model('bill', this);
  billParticipant = new Model('billParticipant', this);
  receipt = new Model('receipt', this);
  receiptUpload = new Model('receiptUpload', this);
  notification = new Model('notification', this);
  regularBill = new Model('regularBill', this);
  settlement = new Model('settlement', this);
  userDevice = new Model('userDevice', this);

  rowsOf(name: string): Row[] {
    return this.store[name];
  }

  /** 事务：共享同一内存状态 */
  $transaction<T>(fn: (tx: FakePrisma) => Promise<T>): Promise<T> {
    return fn(this);
  }
}

class Model {
  constructor(
    private readonly modelName: string,
    private readonly db: FakePrisma,
  ) {}

  private get rows(): Row[] {
    return this.db.rowsOf(this.modelName);
  }

  private createRow(data: Row): Row {
    const row: Row = { ...data, id: data.id ?? randomUUID() };
    // 模型级默认值（对应 schema.prisma 的 @default）
    const defaults: Record<string, Row> = {
      user: { createdAt: new Date(), updatedAt: new Date() },
      group: { createdAt: new Date(), updatedAt: new Date(), defaultSplitType: 'even' },
      groupMember: { joinedAt: new Date(), status: 'active' },
      bill: { createdAt: new Date(), updatedAt: new Date() },
      billParticipant: { paidAt: null, remindCount: 0 },
      notification: { createdAt: new Date(), isRead: false },
      regularBill: { createdAt: new Date(), updatedAt: new Date(), active: true },
      settlement: { createdAt: new Date(), status: 'pending', billIds: [] },
      receipt: { createdAt: new Date(), sort: 0, ocrStatus: 'pending' },
      receiptUpload: { createdAt: new Date(), status: 'pending', ocrStatus: 'pending' },
      userDevice: { lastLoginAt: new Date(), createdAt: new Date() },
    };
    for (const [k, v] of Object.entries(defaults[this.modelName] ?? {})) {
      if (row[k] === undefined) row[k] = v;
    }
    // 嵌套 create：group.members / bill.participants
    if (this.modelName === 'group' && data.members) {
      const list: Row[] = Array.isArray(data.members.create)
        ? data.members.create
        : [data.members.create];
      for (const c of list) {
        this.db.rowsOf('groupMember').push({ ...c, id: c.id ?? randomUUID(), groupId: row.id });
      }
      delete row.members;
    }
    if (this.modelName === 'bill' && data.participants) {
      const list: Row[] = Array.isArray(data.participants.create)
        ? data.participants.create
        : [data.participants.create];
      for (const c of list) {
        this.db.rowsOf('billParticipant').push({ ...c, id: c.id ?? randomUUID(), billId: row.id });
      }
      delete row.participants;
    }
    this.rows.push(row);
    return row;
  }

  private hydrateRow(row: Row | null, include?: any): any {
    if (!row || !include) return row;
    const out: Row = { ...row };
    if (this.modelName === 'group') {
      if (include.owner) out.owner = this.db.rowsOf('user').find((u) => u.id === row.ownerId) ?? null;
      if (include._count?.select?.members) {
        out._count = { members: this.db.rowsOf('groupMember').filter((m) => m.groupId === row.id).length };
      }
    }
    if (this.modelName === 'groupMember') {
      if (include.user) out.user = this.db.rowsOf('user').find((u) => u.id === row.userId) ?? null;
      if (include.group) {
        const g = this.db.rowsOf('group').find((x) => x.id === row.groupId);
        if (g) {
          const go: Row = { ...g };
          if (include.group.include?.owner) go.owner = this.db.rowsOf('user').find((u) => u.id === g.ownerId) ?? null;
          if (include.group.include?._count?.select?.members) {
            go._count = { members: this.db.rowsOf('groupMember').filter((m) => m.groupId === g.id).length };
          }
          out.group = go;
        } else {
          out.group = null;
        }
      }
    }
    if (this.modelName === 'bill') {
      if (include.creator) out.creator = this.db.rowsOf('user').find((u) => u.id === row.creatorId) ?? null;
      if (include.payer) out.payer = this.db.rowsOf('user').find((u) => u.id === row.payerId) ?? null;
      if (include.participants) {
        out.participants = this.db.rowsOf('billParticipant')
          .filter((p) => p.billId === row.id)
          .map((p) => {
            const pp: Row = { ...p };
            if (include.participants?.include?.user) {
              pp.user = this.db.rowsOf('user').find((u) => u.id === p.userId) ?? null;
            }
            return pp;
          });
      }
      if (include.receipts) {
        out.receipts = this.db
          .rowsOf('receipt')
          .filter((r) => r.billId === row.id)
          .slice()
          .sort((a, b) => (a.sort ?? 0) - (b.sort ?? 0));
      }
    }
    if (this.modelName === 'receipt') {
      if (include.bill) {
        const b = this.db.rowsOf('bill').find((x) => x.id === row.billId);
        if (b) {
          const bo: Row = { ...b };
          if (include.bill?.include?.group?.select?.ownerId) {
            const g = this.db.rowsOf('group').find((gg) => gg.id === b.groupId);
            bo.group = g ? { ownerId: g.ownerId } : null;
          }
          out.bill = bo;
        } else {
          out.bill = null;
        }
      }
    }
    return out;
  }

  async findUnique({ where, include }: { where: any; include?: any }) {
    const row = this.rows.find((r) => matches(r, where)) ?? null;
    return this.hydrateRow(row, include);
  }

  async findFirst({ where, include, orderBy }: { where?: any; include?: any; orderBy?: any }) {
    const found = sortRows(this.rows.filter((r) => matches(r, where ?? {})), orderBy);
    return this.hydrateRow(found[0] ?? null, include);
  }

  async findMany({
    where,
    include,
    orderBy,
    skip,
    take,
  }: {
    where?: any;
    include?: any;
    orderBy?: any;
    skip?: number;
    take?: number;
  }) {
    let list = sortRows(this.rows.filter((r) => matches(r, where ?? {})), orderBy);
    if (skip) list = list.slice(skip);
    if (take !== undefined) list = list.slice(0, take);
    return list.map((r) => this.hydrateRow(r, include));
  }

  async create({ data, include }: { data: Row; include?: any }) {
    const row = this.createRow(data);
    return this.hydrateRow(row, include);
  }

  async update({ where, data, include }: { where: Row; data: Row; include?: any }) {
    const idx = this.rows.findIndex((r) => matches(r, where));
    if (idx < 0) {
      throw new Error(`[FakePrisma] ${this.modelName}.update 未找到：${JSON.stringify(where)}`);
    }
    const patch: Row = {};
    for (const [k, v] of Object.entries(data)) {
      if (v && typeof v === 'object' && !(v instanceof Date) && 'increment' in v) {
        patch[k] = (this.rows[idx][k] ?? 0) + v.increment;
      } else {
        patch[k] = v;
      }
    }
    this.rows[idx] = { ...this.rows[idx], ...patch };
    return this.hydrateRow(this.rows[idx], include);
  }

  async updateMany({ where, data }: { where: Row; data: Row }) {
    let count = 0;
    for (const r of this.rows) {
      if (matches(r, where)) {
        Object.assign(r, data);
        count++;
      }
    }
    return { count };
  }

  async deleteMany({ where }: { where: Row }) {
    const before = this.rows.length;
    for (let i = this.rows.length - 1; i >= 0; i--) {
      if (matches(this.rows[i], where)) this.rows.splice(i, 1);
    }
    return { count: before - this.rows.length };
  }

  async createMany({ data, skipDuplicates }: { data: Row[]; skipDuplicates?: boolean }) {
    for (const d of data) {
      if (skipDuplicates && this.rows.some((r) => matches(r, d))) continue;
      this.rows.push({ ...d, id: d.id ?? randomUUID() });
    }
    return { count: data.length };
  }

  async count({ where }: { where?: Row }) {
    return this.rows.filter((r) => matches(r, where ?? {})).length;
  }
}
