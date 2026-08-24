/**
 * 演示数据 seed（可选）：造 1 个群 + 若干成员 + 一笔账单。
 * 运行：npx prisma db seed
 * 需要数据库可连接；在无数据库环境请跳过。
 */
import { PrismaClient, SplitType, Category, NotificationType } from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  const passwordHash = await bcrypt.hash('pass123456', 12);
  const securityAnswerHash = await bcrypt.hash('小虎', 12);

  const users = await Promise.all(
    [
      { accountName: 'tuanzi_t', nickname: '团子酱' },
      { accountName: 'zhangsan', nickname: '张三' },
      { accountName: 'lisi', nickname: '李四' },
    ].map((u) =>
      prisma.user.create({
        data: {
          accountName: u.accountName,
          nickname: u.nickname,
          passwordHash,
          securityQuestion: '你第一个朋友的名字？',
          securityAnswerHash,
        },
      }),
    ),
  );

  const group = await prisma.group.create({
    data: {
      name: '饭友群',
      intro: '一起吃饭的朋友',
      ownerId: users[0].id,
      inviteCode: 'AABBCCDDEEFF',
      members: {
        create: users.map((u, i) => ({
          userId: u.id,
          status: 'active',
          joinedAt: new Date(Date.now() - i * 3600_000),
        })),
      },
    },
  });

  // 一笔三方均摊账单（A 垫付 10000 分 = ¥100）
  const amountCents = 10000;
  const per = Math.floor(amountCents / users.length);
  const first = amountCents - per * (users.length - 1);
  const bill = await prisma.bill.create({
    data: {
      groupId: group.id,
      creatorId: users[0].id,
      payerId: users[0].id,
      title: '今晚聚餐',
      amountCents,
      billDate: new Date(),
      category: Category.food,
      splitType: SplitType.even,
      participants: {
        create: users.map((u, i) => ({
          userId: u.id,
          shareAmountCents: i === 0 ? first : per,
        })),
      },
    },
  });

  // 给其他成员发新账单通知
  await Promise.all(
    users.slice(1).map((u) =>
      prisma.notification.create({
        data: {
          userId: u.id,
          type: NotificationType.new_bill,
          title: '新账单',
          body: `「${bill.title}」新增，¥${(amountCents / 100).toFixed(2)}`,
          refType: 'bill',
          refId: bill.id,
        },
      }),
    ),
  );

  console.log('Seed 完成：群', group.name, '账单', bill.title, '金额(分)', amountCents);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
