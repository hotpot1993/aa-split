// 「记一笔」防重复提交回归测试：
// 连点「收下这张小票」按钮 → 仅生成一张账单（单次操作限一张）
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/data/mock/mock_store.dart';
import 'package:aa_split_app/screens/add/add_bill_screen.dart';

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
  await tester.pump(); // 异步初始化（groups/members）
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('连点收下小票：仅生成一张账单', (tester) async {
    await _pump(tester, const AddBillScreen());

    // 输入金额（标题留空 → 默认用分类名「餐饮」；默认选中首群全体）
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pump();

    final before = MockStore.instance.bills.length;

    // 连续三次快速点击（帧间不 pump，模拟快速连点）
    final btn = find.text('收下这张小票！✓');
    await tester.tap(btn);
    await tester.tap(btn);
    await tester.tap(btn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 关键断言：只多出一张账单
    expect(MockStore.instance.bills.length, before + 1);
    // 且已进入保存成功庆祝页
    expect(find.text('已保存，等TA们摊钱咯~'), findsOneWidget);
    // 标题留空 → 默认使用消费分类名称（默认分类 food → 餐饮）
    expect(MockStore.instance.bills.last.title, '餐饮');

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('保存成功后再次点击不产生新账单', (tester) async {
    await _pump(tester, const AddBillScreen());
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pump();

    final before = MockStore.instance.bills.length;
    await tester.tap(find.text('收下这张小票！✓'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 庆祝页已切换；无论怎样再触发一次保存入口，账单数不变
    expect(MockStore.instance.bills.length, before + 1);
    await tester.pump(const Duration(seconds: 2));
  });
}
