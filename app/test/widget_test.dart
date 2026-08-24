import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/main.dart';

void main() {
  testWidgets('main app boots to home in demo mode', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AaSplitApp()));

    // P01 启动页：等待 2s 定时器 + 翻页过渡（Demo 自动登录 → /home）
    await tester.pump(); // 首帧
    await tester.pump(const Duration(seconds: 3)); // 定时器触发跳转
    await tester.pump(); // 构建主页
    await tester.pump(const Duration(milliseconds: 350)); // 路由过渡
    await tester.pump(const Duration(milliseconds: 100));

    // 断言关键文本（至少 4 处）
    expect(find.text('我的净额'), findsWidgets);
    expect(find.text('快捷入口'), findsWidgets);
    expect(find.text('记一笔'), findsWidgets);
    expect(find.text('最近账单'), findsWidgets);
    expect(find.text('去结算'), findsWidgets);
  });

  testWidgets('groups tab shows existing demo groups', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AaSplitApp()));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // 切到群组 Tab（底部导航第 2 项）
    await tester.tap(find.text('群组'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('饭友群'), findsWidgets);
    expect(find.text('合租小分队'), findsWidgets);
    expect(find.text('周末露营'), findsWidgets);
  });
}
