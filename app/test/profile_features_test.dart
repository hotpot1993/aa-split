// 本轮 UI 需求回归测试：
// 1. 设置页不再展示「深色模式」选项
// 2. 退出登录确认弹窗不展示吉祥物（保持简洁）
// 3. 「我的」点击头像弹出换头像面板（拍一张/从相册选/恢复默认）
// 4. P33 凭证页：点击拍照/相册先弹「模拟拍摄凭证」提示，确认后预览框出现缩略图并更新已拍张数
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/screens/add/receipt_screen.dart';
import 'package:aa_split_app/screens/profile/profile_screen.dart';
import 'package:aa_split_app/screens/profile/settings_screen.dart';
import 'package:aa_split_app/widgets/avatar.dart';

Widget _app(Widget home) => ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAaTheme(),
        home: home,
      ),
    );

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_app(home));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('设置页不再展示深色模式选项', (tester) async {
    await _pump(tester, const SettingsScreen());

    expect(find.text('通知设置'), findsOneWidget);
    expect(find.text('深色模式'), findsNothing);
    expect(find.text('浅色（固定）'), findsNothing);
  });

  testWidgets('退出登录弹窗不展示吉祥物元素', (tester) async {
    await _pump(tester, const SettingsScreen());

    // 滚到退出登录按钮并点击
    await tester.scrollUntilVisible(find.text('退出登录'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('退出登录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('要退出登录吗？'), findsOneWidget);
    // 弹窗内无团团吉祥物
    expect(find.byType(TuanTuan), findsNothing);
    // 底部仍有退出/再想想按钮
    expect(find.text('退出'), findsOneWidget);
    expect(find.text('再想想'), findsOneWidget);
  });

  testWidgets('点击头像区域弹出换头像面板', (tester) async {
    await _pump(tester, const ProfileScreen());

    await tester.tap(find.byType(SketchAvatar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('换头像'), findsOneWidget);
    expect(find.text('拍一张'), findsOneWidget);
    expect(find.text('从相册选'), findsOneWidget);
    expect(find.text('恢复默认'), findsOneWidget);
  });

  testWidgets('P33 凭证页：拍照/相册弹模拟提示，确认后更新张数与预览', (tester) async {
    await _pump(tester, const ReceiptScreen(billId: 'b1'));

    expect(find.text('已拍 0 张：'), findsOneWidget);

    // 点「从相册选」→ 弹出模拟拍摄凭证提示
    await tester.tap(find.text('从相册选'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('模拟拍摄凭证'), findsOneWidget);

    // 确认拍摄 → 已拍 1 张 + 预览框显示缩略图角标
    await tester.tap(find.text('拍摄'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('已拍 1 张：'), findsOneWidget);
    expect(find.text('已拍 1 张'), findsWidgets);

    // 再拍一张 → 2 张
    await tester.tap(find.text('拍一张'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('模拟拍摄凭证'), findsOneWidget);
    await tester.tap(find.text('拍摄'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('已拍 2 张：'), findsOneWidget);

    // 等待 toast 定时器结束，避免遗留 Timer
    await tester.pump(const Duration(seconds: 2));
  });
}
