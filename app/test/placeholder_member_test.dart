// 非注册成员（占位账号）回归测试（Demo 模式）：
//   邀请页「方式三：直接添加（无需注册）」/ 成员管理页「未注册」标签、改名、认领、疑似同一人 /
//   群组详情人均口径
// 设计依据：CONTEXT.md、docs/adr/0001、产品原型 P22/P24
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_design/aa_design.dart';
import 'package:aa_split_app/data/mock/mock_store.dart';
import 'package:aa_split_app/data/repositories/group_repository.dart';
import 'package:aa_split_app/models/bill.dart';
import 'package:aa_split_app/models/bill_participant.dart';
import 'package:aa_split_app/models/group.dart';
import 'package:aa_split_app/models/group_member.dart';
import 'package:aa_split_app/screens/groups/group_detail_screen.dart';
import 'package:aa_split_app/screens/groups/invite_screen.dart';
import 'package:aa_split_app/screens/groups/members_screen.dart';

Future<void> _pump(WidgetTester tester, Widget screen) async {
  // 用真机常见的窄屏逻辑宽度（1080/3.0 = 360dp）：v1.0.17 的「方式三」按钮
  // 就是在这里被单行布局挤出屏幕导致点击无响应，测试必须覆盖这个宽度
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAaTheme(),
        home: screen,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 500));
}

/// 每个用例新建一个群，避免共用 MockStore 单例状态互相干扰
Future<Group> _newGroup(String name) =>
    GroupRepository().create(name: name, intro: '非注册成员回归');

/// 给占位账号造一笔未结清账单（用于人均/未结清金额/认领预览）
void _addUnpaidBillFor(Group group, GroupMember guest) {
  MockStore.instance.bills.add(Bill(
    id: 'b_ph_${guest.userId}',
    groupId: group.id,
    groupName: group.name,
    title: '占位账单',
    amountCents: 10000,
    billDate: DateTime(2026, 9, 1),
    category: BillCategory.food,
    payerId: 'me',
    payerName: '团子酱',
    participants: [
      BillParticipant(
          userId: 'me',
          nickname: '团子酱',
          shareAmountCents: 5000,
          paid: true),
      BillParticipant(
          userId: guest.userId,
          nickname: guest.nickname,
          shareAmountCents: 5000),
    ],
    settleStatus: BillSettleStatus.partial,
  ));
}

void main() {
  testWidgets('邀请页（群主）方式三：输入名称即添加非注册成员，成员列表立即出现', (tester) async {
    final g = await _newGroup('方式三测试群');
    await _pump(tester, InviteScreen(groupId: g.id));

    expect(find.text('方式三：直接添加（无需注册）'), findsOneWidget);
    // 回归（v1.0.17 真机 bug）：方式三的「添加」按钮必须完整落在屏内。
    // 此前它沿用「标签+固定宽输入框+按钮」单行布局，360dp 窄屏下按钮被挤到
    // 屏幕外（实测 x 383.5→410 / 屏宽 360），用户点击无任何响应
    final screenW = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final guestAddBtn = find.ancestor(
      of: find.text('添加').last,
      matching: find.byType(DoodleButton),
    );
    final btnRect = tester.getRect(guestAddBtn);
    expect(btnRect.left, greaterThanOrEqualTo(0));
    expect(btnRect.right, lessThanOrEqualTo(screenW),
        reason: '「添加」按钮被挤出屏幕（屏宽 $screenW，按钮右边界 ${btnRect.right}）');
    expect(tester.takeException(), isNull, reason: '方式三卡片不得有布局溢出');

    // 方式三的输入框在最后一个
    await tester.enterText(find.byType(TextField).last, '老王');
    await tester.tap(find.text('添加').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final members = await GroupRepository().members(g.id);
    final guest = members.where((m) => m.isPlaceholder).toList();
    expect(guest, hasLength(1));
    expect(guest.first.nickname, '老王');
    expect(guest.first.accountName, isEmpty); // 占位账号没有可用账户名
    expect(find.textContaining('老王 ✓'), findsWidgets);

    // 冲掉 Toast 计时
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('邀请页（非群主）不显示方式三', (tester) async {
    // g3「周末露营」群主是 u_xiaolu，当前用户只是成员
    await _pump(tester, const InviteScreen(groupId: 'g3'));
    expect(find.text('方式三：直接添加（无需注册）'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('邀请页方式三：群内重名 → 示例文案提示失败（不新增成员）', (tester) async {
    final g = await _newGroup('重名测试群');
    final repo = GroupRepository();
    await repo.addPlaceholderMember(g.id, '老王');
    await _pump(tester, InviteScreen(groupId: g.id));

    await tester.enterText(find.byType(TextField).last, '老王');
    await tester.tap(find.text('添加').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('群内已有同名成员'), findsOneWidget);
    expect((await repo.members(g.id)).where((m) => m.isPlaceholder), hasLength(1));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('成员管理页：非注册成员显示灰色「未注册」标签，且不显示 @账户名', (tester) async {
    final g = await _newGroup('标签测试群');
    final repo = GroupRepository();
    final guest = await repo.addPlaceholderMember(g.id, '老王');
    await _pump(tester, MembersScreen(groupId: g.id));

    expect(find.text('未注册'), findsOneWidget);
    // 成员名走 Text.rich（昵称 + @账户名 同一行），用 textContaining 匹配
    expect(find.textContaining('老王'), findsWidgets);
    // 全页只有注册成员（我）那一行带 @账户名；占位账号不渲染 @（accountName 为空串）
    expect(find.textContaining('@'), findsOneWidget);
    expect(guest.accountName, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('成员管理页：群主可改名、非群主看不到管理动作', (tester) async {
    final g = await _newGroup('改名测试群');
    final repo = GroupRepository();
    final guest = await repo.addPlaceholderMember(g.id, '老王');
    await _pump(tester, MembersScreen(groupId: g.id));

    expect(find.text('改名'), findsOneWidget);
    expect(find.text('绑定到账户'), findsOneWidget);
    await tester.tap(find.text('改名'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    await tester.enterText(find.byType(TextField).last, '王大爷');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final members = await repo.allMembers(g.id);
    expect(members.firstWhere((m) => m.userId == guest.userId).nickname, '王大爷');
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('成员管理页：认领预览列出合并范围，确认后占位账号并入真实账号', (tester) async {
    final g = await _newGroup('认领测试群');
    final repo = GroupRepository();
    final guest = await repo.addPlaceholderMember(g.id, '老王');
    await repo.addMember(g.id, 'zhangsan'); // 群内真实账号（mock 字典 → 张三）
    _addUnpaidBillFor(g, guest);

    await _pump(tester, MembersScreen(groupId: g.id));
    await tester.tap(find.text('绑定到账户'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('把「老王」绑定到哪个账户？'), findsOneWidget);
    await tester.tap(find.text('张三'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.textContaining('将合并 1 笔账单、0 条历史结算'), findsOneWidget);
    expect(find.textContaining('认领不可撤销'), findsOneWidget);
    await tester.tap(find.text('确认认领'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final members = await repo.allMembers(g.id);
    expect(members.any((m) => m.userId == guest.userId), isFalse);
    final zhang = members.firstWhere((m) => m.nickname == '张三');
    // 占位账号的账单已归到真实账号名下
    final bill =
        MockStore.instance.bills.firstWhere((b) => b.id == 'b_ph_${guest.userId}');
    expect(bill.participants.any((p) => p.userId == zhang.userId), isTrue);
    expect(bill.participants.any((p) => p.userId == guest.userId), isFalse);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('成员管理页：同名注册成员出现「疑似同一人，去认领」并可直达认领', (tester) async {
    final g = await _newGroup('疑似同一人测试群');
    final repo = GroupRepository();
    final guest = await repo.addPlaceholderMember(g.id, '老王');
    await repo.addMember(g.id, 'zhangsan');
    // 真实账号昵称与占位账号同名（服务端只限制占位账号重名，昵称本身不唯一）
    final list = MockStore.instance.members[g.id]!;
    final i = list.indexWhere((m) => m.userId == 'zhangsan');
    list[i] = list[i].copyWith(nickname: '老王');

    await _pump(tester, MembersScreen(groupId: g.id));
    expect(find.text('疑似同一人，去认领 →'), findsOneWidget);

    await tester.tap(find.text('疑似同一人，去认领 →'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // 直达同名注册成员的认领确认弹窗（不再经过选择弹层）
    expect(find.text('把「老王」绑定到「老王」？'), findsOneWidget);
    await tester.tap(find.text('确认认领'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final members = await repo.allMembers(g.id);
    expect(members.any((m) => m.userId == guest.userId), isFalse);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('成员管理页：移除有未结清账单的非注册成员，二次确认列出未结清金额', (tester) async {
    final g = await _newGroup('移除测试群');
    final guest = await GroupRepository().addPlaceholderMember(g.id, '老王');
    _addUnpaidBillFor(g, guest);

    await _pump(tester, MembersScreen(groupId: g.id));
    // 行内已显示未结清金额提示
    expect(find.textContaining('未结清 ¥50'), findsWidgets);

    await tester.tap(find.text('移除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.textContaining('TA 还有 ¥50 未结清'), findsOneWidget);
    expect(find.textContaining('移除后账单仍会保留在群里'), findsOneWidget);

    await tester.tap(find.text('移除').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      (await GroupRepository().allMembers(g.id))
          .any((m) => m.userId == guest.userId && m.isActive),
      isFalse,
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('群组详情：人均分母按 active 成员计（含非注册成员，不含已退出）', (tester) async {
    final g = await _newGroup('人均测试群');
    await GroupRepository().addPlaceholderMember(g.id, '老王');

    await _pump(tester, GroupDetailScreen(groupId: g.id));
    expect(find.textContaining('/ 2人'), findsOneWidget); // 我 + 非注册成员老王
    expect(tester.takeException(), isNull);
  });
}
