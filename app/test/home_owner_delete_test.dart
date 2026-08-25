// 首页「最近账单」长按删除回归测试：
// 1. 群主（ownerId=me）长按首页最近账单 → 确认弹窗 → 确认后账单从首页消失
// 2. 非群主长按 → 仅提示无权限，不弹删除确认
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/main.dart';

Future<void> setPhoneViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> bootToHome(WidgetTester tester) async {
  await tester.pump(); // 首帧
  await tester.pump(const Duration(seconds: 3)); // 启动页定时器（Demo 自动登录）
  await tester.pump(); // 构建主页
  await tester.pump(const Duration(milliseconds: 350)); // 路由过渡
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('群主长按首页最近账单：确认弹窗后删除', (tester) async {
    await setPhoneViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: AaSplitApp()));
    await bootToHome(tester);

    // Demo 假数据：b1「今晚聚餐」属 g1（当前用户是群主），日期 2 天前 → 首页最近列表
    expect(find.text('今晚聚餐'), findsOneWidget);

    await tester.longPress(find.text('今晚聚餐'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('要删除这笔账单吗？'), findsOneWidget);

    await tester.tap(find.text('删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('账单已删除'), findsOneWidget);
    expect(find.text('今晚聚餐'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('非群主长按首页最近账单：仅提示，不弹确认', (tester) async {
    await setPhoneViewport(tester);
    await tester.pumpWidget(const ProviderScope(child: AaSplitApp()));
    await bootToHome(tester);

    // b10「过路费」属 g3（群主 u_xiaolu，当前用户非群主），日期 1 天前 → 首页最近列表
    expect(find.text('过路费'), findsOneWidget);

    await tester.longPress(find.text('过路费'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('只有群主才能删除账单哦'), findsOneWidget);
    expect(find.text('要删除这笔账单吗？'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });
}
