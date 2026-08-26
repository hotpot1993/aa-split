// 弹窗布局回归测试（需求：弹窗右侧内容不完整 / 弹窗位置偏高留白）：
// - 记一笔分类弹窗：宽度撑满屏幕（不再缩窄留边），高度按内容自适应（贴底，下方无大面积空白）
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/screens/add/add_bill_screen.dart';

Future<void> _pump(WidgetTester tester, Widget home,
    {Size logical = const Size(360, 780)}) async {
  tester.view.physicalSize = logical * 2;
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
  testWidgets('分类弹窗全宽 + 内容自适应高度（不再偏高压顶/右侧截断）', (tester) async {
    await _pump(tester, const AddBillScreen());

    // 打开分类弹窗
    await tester.tap(find.textContaining('餐饮'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('选个分类'), findsOneWidget);

    // 内容首行（标题）应紧贴弹窗左缘（padding 20 → left≈20），说明弹窗撑满屏宽；
    // 修复前 FractionallySizedBox 缩窄到 ~285px，标题 left≈57.5，右缘内容被截
    final titleBox = tester.getRect(find.text('选个分类'));
    expect(titleBox.left, lessThan(25));
    expect(titleBox.right, lessThanOrEqualTo(360 - 20 + 1));

    // 弹窗贴底、高度随内容自适应：标题位置应显著低于屏高一半（修复前 86% 高弹窗顶到 109）
    final screenH = tester.getSize(find.byType(Scaffold).first).height;
    expect(titleBox.top, greaterThan(screenH * 0.6));

    // 分类标签完整渲染（6 个分类）
    expect(find.textContaining('餐饮'), findsWidgets);
    expect(find.textContaining('交通'), findsWidgets);
    expect(find.textContaining('住宿'), findsWidgets);
    expect(find.textContaining('购物'), findsWidgets);
    expect(find.textContaining('娱乐'), findsWidgets);
    expect(find.textContaining('其他'), findsWidgets);

    // 闭合弹窗，回到记一笔页
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('选个分类'), findsNothing);
  });
}
