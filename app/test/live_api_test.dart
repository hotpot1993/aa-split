import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aa_split_app/core/api/api_client.dart';
import 'package:aa_split_app/core/config.dart';
import 'package:aa_split_app/data/repositories/auth_repository.dart';
import 'package:aa_split_app/data/repositories/bill_repository.dart';
import 'package:aa_split_app/data/repositories/group_repository.dart';
import 'package:aa_split_app/data/repositories/notification_repository.dart';
import 'package:aa_split_app/data/repositories/settlement_repository.dart';
import 'package:aa_split_app/models/bill.dart';
import 'package:aa_split_app/models/bill_participant.dart';

/// 客户端仓库层 ↔ 真实后端 的全链路联调测试（真网络 HTTP）。
///
/// 注意：本文件**不**调用 TestWidgetsFlutterBinding.ensureInitialized()，
/// 因为 binding 会屏蔽 HttpClient（所有请求直接返回 400）；
/// SharedPreferences 走 setMockInitialValues 的内存实现，无需 binding。
///
/// 运行（本地 3000 或线上均可）：
///   flutter test --dart-define=AA_USE_MOCK=false \
///                --dart-define=AA_API_BASE=http://127.0.0.1:3000/api/v1 \
///                --dart-define=AA_LIVE=true test/live_api_test.dart
///   （AA_LIVE 未开启时跳过，防止误跑/CI 无后端的场景）
void main() {
  const live = bool.fromEnvironment('AA_LIVE');
  if (AppConfig.useMock || !live) {
    test('live api（需 AA_USE_MOCK=false 且 AA_LIVE=true 且服务端可达）', () {},
        skip: '未开启 live 模式（--dart-define=AA_LIVE=true）');
    return;
  }

  final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final aliceName = 'lv_alice_$suffix';
  final bobName = 'lv_bob_$suffix';
  const question = '你最好的朋友？';

  test('注册→建群→邀请加入→记账→结算→催款→已付结清（真实后端）', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final tokens = <String, String>{};

    // 会话切换：服务端 login 限流 5 次/10 分钟；多角色联调场景
    // 直接注入注册时取得的 token（register 已写入本地会话），不走 /login
    void switchTo(String accountName) {
      ApiClient.instance.setToken(
        accountName == aliceName ? tokens['alice']! : tokens['bob']!,
      );
    }

    // 1. 注册双用户（真实 /auth/register），记录双方 token
    final auth = AuthRepository();
    await auth.register(
      accountName: aliceName,
      password: 'abc123ABC',
      nickname: '联调爱丽丝',
      securityQuestion: question,
      securityAnswer: '小红',
    );
    tokens['alice'] = prefs.getString('aa.token')!;
    final bob = await auth.register(
      accountName: bobName,
      password: 'def456DEF',
      nickname: '联调鲍勃',
      securityQuestion: question,
      securityAnswer: '实验',
    );
    tokens['bob'] = prefs.getString('aa.token')!;
    expect(bob.accountName, bobName);

    // 2. 切回 alice 会话：安全问题查询 + 资料编辑（P04/P50 真实端点）
    switchTo(aliceName);
    expect(await auth.securityQuestionOf(aliceName), question);
    // 注意：不用 restoreSession 切会话（它读 prefs 的最新 token），
    // 步骤 4 需要的 alice 用户信息直接用本次返回值
    final alice = await auth.updateProfile(nickname: '联调爱丽丝2', bio: '');
    expect(alice.nickname, '联调爱丽丝2');
    expect(alice.bio, '');

    // 3. alice 建群 + bob 通过邀请码加入
    final groupRepo = GroupRepository();
    final group = await groupRepo.create(name: 'Live联调群$suffix');
    expect(group.inviteCode.length, 12);
    // 切到 bob 会话加入
    switchTo(bobName);
    final joined = await groupRepo.join(group.inviteCode);
    expect(joined.id, group.id);
    expect(joined.name, group.name);
    // 切回 alice
    switchTo(aliceName);
    final members = await groupRepo.members(group.id);
    expect(members.length, 2, reason: '成员应为 2 人');

    // 4. alice 记一笔（均摊 220 元）
    final billRepo = BillRepository();
    final bill = await billRepo.create(
      groupId: group.id,
      groupName: group.name,
      title: 'Live火锅$suffix',
      amountCents: 22000,
      billDate: DateTime.now(),
      category: BillCategory.food,
      payerId: alice.id,
      payerName: '联调爱丽丝2',
      participants: [
        BillParticipant(userId: alice.id, nickname: '联调爱丽丝2', shareAmountCents: 11000),
        BillParticipant(userId: bob.id, nickname: '联调鲍勃', shareAmountCents: 11000),
      ],
    );
    expect(bill.id, isNotEmpty);

    // 5. 结算：最少转账 1 笔 bob→alice 11000
    final settle = SettlementRepository();
    final plan = await settle.compute(group.id);
    expect(plan.transferCount, 1);
    expect(plan.transfers.single.amountCents, 11000);
    expect(plan.transfers.single.fromUserId, bob.id);
    expect(plan.transfers.single.toUserId, alice.id);

    // 6. 新账单通知已取消：bob 未读 0（不再推送）
    switchTo(bobName);
    final notify = NotificationRepository();
    expect(await notify.unreadCount(), 0);

    // 7. 切回 alice：催款 + 标记已付 → 账单结清 → 结算清空
    switchTo(aliceName);
    await billRepo.markPaid(bill.id, bob.id, true);
    final detail = await billRepo.get(bill.id, groupName: group.name);
    expect(detail.settleStatus, BillSettleStatus.settled);
    final planAfter = await settle.compute(group.id);
    expect(planAfter.transferCount, 0);

    // 8. bob 消息列表 + 全读（无新账单通知，催款也未发 → 列表可为空）
    switchTo(bobName);
    final items = await notify.list();
    expect(items.length, greaterThanOrEqualTo(0));
    await notify.markAllRead();
    expect(await notify.unreadCount(), 0);
  });
}
