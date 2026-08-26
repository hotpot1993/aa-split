import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/main.dart';

void main() {
  testWidgets('main app boots to home in demo mode', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AaSplitApp()));

    // P01 启动页：等待 5s 定时器 + 翻页过渡（Demo 自动登录 → /home）
    await tester.pump(); // 首帧
    await tester.pump(const Duration(seconds: 6)); // 定时器触发跳转
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
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    // 切到群组 Tab（底部导航第 2 项）
    await tester.tap(find.text('群组'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('饭友群'), findsWidgets);
    expect(find.text('合租小分队'), findsWidgets);
    expect(find.text('周末露营'), findsWidgets);
  });

  testWidgets('返回键：非首页 Tab 回首页；首页双击返回退出', (WidgetTester tester) async {
    // 捕获 SystemNavigator.pop（退出应用）
    final pops = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        pops.add(call);
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    Future<void> boot() async {
      await tester.pumpWidget(const ProviderScope(child: AaSplitApp()));
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    Future<void> goTab(String label) async {
      await tester.tap(find.text(label));
      await tester.pump(const Duration(milliseconds: 300));
    }

    await boot();

    // 群组 Tab：按返回 → 回到首页，不退出
    await goTab('群组');
    expect(find.text('我的群组'), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('我的净额'), findsWidgets);
    expect(find.text('我的群组'), findsNothing);
    expect(pops.where((c) => c.method == 'SystemNavigator.pop'), isEmpty,
        reason: '非首页返回不应退出应用');

    // 消息 Tab：同样回首页
    await goTab('消息');
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('我的净额'), findsWidgets);

    // 首页第一次返回：仅提示，不退出
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('再按一次返回键退出应用'), findsOneWidget);
    expect(pops.where((c) => c.method == 'SystemNavigator.pop'), isEmpty);

    // 2 秒内第二次返回：退出应用
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 100));
    expect(pops.any((c) => c.method == 'SystemNavigator.pop'), isTrue);

    // 冲掉 Toast 定时器
    await tester.pump(const Duration(seconds: 2));
  });
}
