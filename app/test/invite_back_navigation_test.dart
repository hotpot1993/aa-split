// 邀请页「完成，进入群组」→ 群组详情返回栈回归测试：
// 此前用 context.go 会把「我的群组」壳层整个替换掉 → 左上角返回无响应、
// 物理返回键直接退出应用。修复后 pushReplacement 保留壳层：
// 返回键/左上角返回应回到「我的群组」列表，且不退出应用。
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/main.dart';

Future<void> boot(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: AaSplitApp()));
  await tester.pump(); // 首帧
  await tester.pump(const Duration(seconds: 6)); // 启动页 5s 定时器
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> goToGroupDetailViaInvite(WidgetTester tester) async {
  // 我的群组 → 饭友群详情
  await tester.tap(find.text('群组'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.text('饭友群'));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('群总账'), findsOneWidget);

  // 管理成员 → 邀请成员
  await tester.tap(find.text('管理成员→'));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('成员管理'), findsOneWidget);
  await tester.tap(find.text('＋ 添加成员'));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('邀请成员'), findsOneWidget);

  // 完成，进入群组 → 群组详情
  await tester.tap(find.text('完成，进入群组 →'));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.text('群总账'), findsOneWidget);
}

void main() {
  testWidgets('邀请完成进入群组后：返回键回到「我的群组」且不退出应用', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    await boot(tester);
    await goToGroupDetailViaInvite(tester);

    // 左上角返回按钮 → 回到「我的群组」
    await tester.tap(find.text('‹ 饭友群'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('我的群组'), findsOneWidget);
    expect(find.text('合租小分队'), findsOneWidget);
    expect(pops.where((c) => c.method == 'SystemNavigator.pop'), isEmpty,
        reason: '从群组详情返回不应退出应用');

    // 再次进入群组详情，模拟物理返回键（handlePopRoute）→ 同样回到「我的群组」
    await tester.tap(find.text('饭友群'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('群总账'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('我的群组'), findsOneWidget);
    expect(pops.where((c) => c.method == 'SystemNavigator.pop'), isEmpty,
        reason: '物理返回键从群组详情应回到群组列表，而非退出应用');
  });
}
