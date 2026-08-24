// 真机 UI 走查（integration_test）：
// 真实后端（AA_USE_MOCK=false）下完成 注册 → 主框架 → 群组/消息 Tab 切换。
//
// 运行（Android 模拟器 / 桌面可直接跑；真机需厂商允许模拟点击注入）：
//   flutter test integration_test/app_walkthrough_test.dart -d <device> \
//     --dart-define=AA_USE_MOCK=false \
//     --dart-define=AA_API_BASE=http://103.11.77.228:3000/api/v1 \
//     --dart-define=AA_IT_RUN=true
//
// 注意：部分国产 ROM（小米 HyperOS 等）默认拒绝 Framework 级触摸注入，
// 真机环境下若 tap 无效，请改用 adb 驱动（uiautomator dump 取坐标 +
// `input tap/text`，需开发者选项开启「USB 调试(安全设置)」）；
// 2026-08-24 已在 小米 13 (HyperOS) 用 adb 驱动完成 4 Tab 全量走查。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aa_split_app/main.dart' as app;
import 'package:aa_split_app/screens/auth/register_screen.dart';

/// 轮询等待某个 finder 出现（真实网络/异步加载）
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 45),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 300));
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .take(30)
      .join(' | ');
  throw TestFailure('等待超时，未找到: $finder\n当前屏幕文本: $texts');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const itRun = bool.fromEnvironment('AA_IT_RUN');
  if (!itRun) {
    testWidgets('真机走查（需 --dart-define=AA_IT_RUN=true）', (tester) async {},
        skip: true);
    return;
  }
  final suffix = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final account = 'wt_$suffix';
  const password = 'wtest123ABC';

  testWidgets('真机走查：注册登录 → 主框架 → 群组/消息 Tab', (tester) async {
    app.main();
    await tester.pump(const Duration(seconds: 2));

    // 1. 登录页渲染（真实模式未自动登录）
    await pumpUntil(tester, find.text('去记账咯 →'));
    expect(find.text('注册新账户'), findsOneWidget);

    // 2. 注册新账户（真实 /auth/register）
    await tester.tap(find.text('注册新账户'));
    await pumpUntil(tester, find.text('注册并开始'),
        timeout: const Duration(seconds: 15));

    // 字段顺序（限定在注册页内，避免路由栈中登录页字段混入）：
    // 账户名 / 昵称 / 密码 / 确认密码 / 安全问题答案（下拉选择非 TextField）
    final fields = find.descendant(
      of: find.byType(RegisterScreen),
      matching: find.byType(TextField),
    );
    expect(fields.evaluate().length, greaterThanOrEqualTo(5),
        reason: '注册页应有至少 5 个输入框');
    await tester.enterText(fields.at(0), account);
    await tester.enterText(fields.at(1), '走查团子');
    await tester.enterText(fields.at(2), password);
    await tester.enterText(fields.at(3), password);
    await tester.enterText(fields.at(4), '小红');
    await tester.pump(const Duration(milliseconds: 300));
    // 收起输入焦点：否则 SingleChildScrollView 会因 focus 自动回滚到顶部，后续 tap 错位
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(milliseconds: 600));

    // 勾选协议 + 提交注册（ensureVisible 会自动滚到目标；避免指定错误的 Scrollable）
    final agree = find.text('已阅读并同意《用户协议》《隐私政策》');
    await tester.ensureVisible(agree);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(agree, warnIfMissed: true);
    await tester.pump(const Duration(milliseconds: 500));
    // 确认勾选状态（复选框出现对勾图标）
    expect(find.byIcon(Icons.check), findsWidgets,
        reason: '协议应已勾选（出现 check 图标）');
    final submit = find.text('注册并开始');
    await tester.ensureVisible(submit);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(submit, warnIfMissed: true);
    await tester.pump(const Duration(milliseconds: 500));

    // 3. 注册成功 → 主框架首页（真实网络加载）
    await pumpUntil(tester, find.text('今天也把账算明白～'));

    // 4. Tab 走查：群组 → 消息 → 回到总览
    await tester.tap(find.text('群组'));
    await pumpUntil(tester, find.text('还没有群组，拉上小伙伴开个AA局吧～'),
        timeout: const Duration(seconds: 20));

    await tester.tap(find.text('消息'));
    await pumpUntil(tester, find.text('安静的一天～ 没有新消息'),
        timeout: const Duration(seconds: 20));

    await tester.tap(find.text('总览'));
    await pumpUntil(tester, find.text('今天也把账算明白～'));

    // 结论
    expect(true, isTrue, reason: '走查完成：注册→总览→群组→消息→总览 全部通过');
  });
}
