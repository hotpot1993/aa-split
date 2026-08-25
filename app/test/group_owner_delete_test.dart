// 群主长按账单删除回归测试：
// 1. 群主（ownerId=me）长按账单 → 确认弹窗 → 确认后账单消失
// 2. 非群主长按 → 仅提示无权限，不弹删除确认
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/screens/groups/group_detail_screen.dart';

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
  await tester.pump(); // 异步 FutureProvider 完成
  await tester.pump(const Duration(milliseconds: 300)); // 重绘
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('群主长按账单：确认弹窗后删除', (tester) async {
    await _pump(tester, const GroupDetailScreen(groupId: 'g1'));
    expect(find.textContaining('今晚聚餐'), findsOneWidget);

    // 长按账单行 → 弹出删除确认（默认 Demo 登录用户即 g1 群主）
    await tester.longPress(find.textContaining('今晚聚餐'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('要删除这笔账单吗？'), findsOneWidget);

    // 确认删除 → 账单从流水消失
    await tester.tap(find.text('删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('今晚聚餐'), findsNothing);
    expect(find.text('账单已删除'), findsOneWidget);

    // 等待 toast 定时器结束
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('非群主长按账单：仅提示，不弹确认', (tester) async {
    // g3 群主为 u_xiaolu，当前用户非群主
    await _pump(tester, const GroupDetailScreen(groupId: 'g3'));
    expect(find.textContaining('露营装备'), findsOneWidget);

    await tester.longPress(find.textContaining('露营装备'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('只有群主才能删除账单哦'), findsOneWidget);
    expect(find.text('要删除这笔账单吗？'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });
}
