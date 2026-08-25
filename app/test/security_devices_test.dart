// 账号安全页「登录设备」回归测试（Demo 模式）：
// 列表来自 loginDevicesProvider（MockStore 真实数据源），非硬编码行：
// 1. 首行设备标「当前」，其余设备可「退出」
// 2. 点击退出 → 该设备从列表消失（不再是无响应的假数据）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_design/aa_design.dart';

import 'package:aa_split_app/screens/profile/security_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAaTheme(),
          home: const SecurityScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('登录设备：真实数据渲染，当前/退出交互可用', (tester) async {
    await pump(tester);

    // 列表来自 provider（MockStore 演示设备），非硬编码「iPhone 15 本机」
    expect(find.textContaining('演示设备'), findsOneWidget);
    expect(find.textContaining('旧手机'), findsOneWidget);
    expect(find.text('当前'), findsOneWidget);
    expect(find.text('退出'), findsOneWidget);
    expect(find.text('iPhone 15'), findsNothing);

    // 退出旧手机 → toast 出现；等 toast 消失后行从列表移除
    await tester.tap(find.text('退出'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('已退出「旧手机'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2)); // toast 自动消失
    expect(find.textContaining('旧手机'), findsNothing);
    // 当前设备仍显示
    expect(find.text('当前'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });
}
