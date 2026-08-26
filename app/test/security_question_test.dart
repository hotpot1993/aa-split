// 修改安全问题（P52）回归测试：
// - 点击「修改安全问题」进入完整流程（不再仅演示提示）
// - 第 1 步：当前密码验证 → 第 2 步：选新问题 + 填新答案 → 保存生效
// - 本地用户态与 Mock 数据同步更新
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/data/mock/mock_store.dart';
import 'package:aa_split_app/providers/auth_provider.dart';
import 'package:aa_split_app/screens/profile/security_screen.dart';

Future<void> _pump(WidgetTester tester, Widget home,
    {ProviderContainer? container}) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container ?? ProviderContainer(),
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
  testWidgets('修改安全问题：密码验证 → 新问题+答案 → 保存生效', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pump(tester, const SecurityScreen(), container: container);

    // 入口展示当前问题（不再是「演示：需当前密码验证」toast）
    expect(find.textContaining('你第一个朋友的名字？'), findsWidgets);

    await tester.tap(find.text('修改安全问题'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 第 1 步：当前密码验证
    expect(find.text('先验证当前密码'), findsOneWidget);
    expect(find.text('下一步'), findsOneWidget);
    await tester.enterText(find.byType(HandTextField).last, 'abc123');
    await tester.pump();
    await tester.tap(find.text('下一步'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 第 2 步：选择问题 + 填写答案
    expect(find.text('选择新问题并填写答案（用于找回密码）'), findsOneWidget);
    await tester.tap(find.byType(DropdownButton<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('你最喜欢的城市？').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(HandTextField).last, '重庆');
    await tester.pump();
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 弹层关闭 + 本地用户态/Mock 数据同步
    expect(find.text('选择新问题并填写答案（用于找回密码）'), findsNothing);
    expect(container.read(authProvider).user?.securityQuestion,
        '你最喜欢的城市？');
    expect(MockStore.instance.currentUser.securityQuestion, '你最喜欢的城市？');
    // 列表行展示新问题
    expect(find.textContaining('你最喜欢的城市？'), findsWidgets);

    // 冲掉 Toast 计时器
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('修改安全问题：不填当前密码无法进入第 2 步', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await _pump(tester, const SecurityScreen(), container: container);

    await tester.tap(find.text('修改安全问题'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final button = tester.widget<DoodleButton>(find.byType(DoodleButton).last);
    expect(button.onPressed, isNull); // 密码为空 → 「下一步」置灰

    await tester.tap(find.text('下一步'));
    await tester.pump(const Duration(milliseconds: 200));
    // 仍停留在第 1 步
    expect(find.text('先验证当前密码'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
  });
}
