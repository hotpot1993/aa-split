// 账单编辑（P14）回归测试：重新选择垫付人 + 修改分摊方式
// - 编辑弹窗出现「垫付人/分摊方式」行
// - 换垫付人后保存：payerId/payerName 更新，新垫付人标记为已付
// - 通过分摊面板修改分摊方式后保存：分摊明细重算，结算状态同步
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/data/mock/mock_store.dart';
import 'package:aa_split_app/models/bill.dart';
import 'package:aa_split_app/models/bill_participant.dart';
import 'package:aa_split_app/screens/home/bill_detail_screen.dart';
import 'package:aa_split_app/widgets/common.dart';

/// 还原 b1 到种子状态（MockStore 为文件内单例，避免用例间相互影响）
void _resetB1() {
  final store = MockStore.instance;
  final idx = store.bills.indexWhere((b) => b.id == 'b1');
  if (idx < 0) return;
  store.bills[idx] = Bill(
    id: 'b1',
    groupId: 'g1',
    groupName: '饭友群',
    title: '今晚聚餐',
    amountCents: 22000,
    billDate: store.bills[idx].billDate,
    location: '海底捞',
    category: BillCategory.food,
    payerId: 'me',
    payerName: '团子酱',
    participants: [
      BillParticipant(
          userId: 'me', nickname: '团子酱', shareAmountCents: 5500, paid: true),
      BillParticipant(userId: 'u_zhangsan', nickname: '张三', shareAmountCents: 5500),
      BillParticipant(userId: 'u_lisi', nickname: '李四', shareAmountCents: 5500),
      BillParticipant(userId: 'u_wangwu', nickname: '王五', shareAmountCents: 5500),
    ],
    splitType: SplitType.even,
    receipts: const [],
    isRegular: false,
    settleStatus: BillSettleStatus.partial,
    createdAt: store.bills[idx].createdAt,
  );
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAaTheme(),
        home: home,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('编辑账单：重新选择垫付人（李四）并保存', (tester) async {
    _resetB1();
    await _pump(tester, const BillDetailScreen(billId: 'b1'));

    // 打开编辑弹窗
    await tester.tap(find.byWidgetPredicate(
        (w) => w is AaIconImage && w.asset == 'assets/icons/edit.png'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('编辑账单'), findsOneWidget);
    expect(find.text('垫付人'), findsWidgets);
    expect(find.text('分摊方式'), findsWidgets);

    // 垫付人：团子酱 → 李四
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('李四').last);
    await tester.pumpAndSettle();
    expect(find.text('李四'), findsOneWidget);

    // 保存：未改金额且新垫付人已在参与人中 → 直接可保存
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final bill = MockStore.instance.billById('b1')!;
    expect(bill.payerId, 'u_lisi');
    expect(bill.payerName, '李四');
    // 新垫付人份额标记为已付
    final liSi = bill.participants.firstWhere((p) => p.userId == 'u_lisi');
    expect(liSi.paid, isTrue);
    expect(bill.participants.length, 4);

    // 冲掉 Toast 计时器
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('编辑账单：通过分摊面板改成分摊方式并保存', (tester) async {
    _resetB1();
    await _pump(tester, const BillDetailScreen(billId: 'b1'));

    await tester.tap(find.byWidgetPredicate(
        (w) => w is AaIconImage && w.asset == 'assets/icons/edit.png'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 金额改成 400.00 → 原明细合计不再一致 → 需先确认分摊方式
    await tester.enterText(find.byType(HandTextField).last, '400.00');
    await tester.pump();
    expect(find.textContaining('请点击上方确认新的分摊方式'), findsOneWidget);

    // 打开分摊面板 → 生效（均摊 4 人）
    await tester.tap(find.textContaining('点击调整'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('均摊（最常用）'), findsOneWidget);
    await tester.tap(find.text('生效'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('请点击上方确认新的分摊方式'), findsNothing);

    // 保存
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final bill = MockStore.instance.billById('b1')!;
    expect(bill.amountCents, 40000);
    expect(bill.splitType, SplitType.even);
    // 4 人均摊 400 → 每人 100（10000 分）
    final sum = bill.participants.fold<int>(0, (s, p) => s + p.shareAmountCents);
    expect(sum, 40000);
    expect(bill.participants.every((p) => p.shareAmountCents == 10000), isTrue);
    // 垫付人（原 me）已付，其余未付
    expect(bill.participants.firstWhere((p) => p.userId == 'me').paid, isTrue);
    expect(bill.settleStatus, BillSettleStatus.partial);

    await tester.pump(const Duration(seconds: 2));
  });
}
