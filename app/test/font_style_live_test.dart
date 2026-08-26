// 复现/回归：切换字体风格后，已构建页面（如首页）应即时换字体，无需重新导航。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aa_design/aa_design.dart';

import 'package:aa_split_app/main.dart';
import 'package:aa_split_app/providers/settings_provider.dart';

Future<void> bootToHome(WidgetTester tester) async {
  await tester.pump(); // 首帧
  await tester.pump(const Duration(seconds: 6)); // 启动页定时器
  await tester.pump(); // 构建主页
  await tester.pump(const Duration(milliseconds: 350)); // 路由过渡
  await tester.pump(const Duration(milliseconds: 100));
}

Text _homeText(WidgetTester tester, String data) {
  final finder = find.byWidgetPredicate((w) => w is Text && w.data == data);
  expect(finder, findsWidgets);
  return tester.widget<Text>(finder.first);
}

void main() {
  testWidgets('切换字体风格后首页文本立即换字体（无需导航）', (tester) async {
    // 测试环境注入内存版 SharedPreferences，避免插件通道在 fake-async 中挂起
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AAFonts.useStyle(AaFontStyle.hand);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AaSplitApp(),
      ),
    );
    await bootToHome(tester);

    // 首页文本：手绘风格
    expect(_homeText(tester, '我的净额').style?.fontFamily, AAFonts.titleHand);
    expect(_homeText(tester, '快捷入口').style?.fontFamily, AAFonts.titleHand);

    // 切换为标准风格（模拟设置页操作）
    await container.read(fontStyleProvider.notifier).setStyle(AaFontStyle.standard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // 主题动画
    await tester.pump();

    // 同一批已构建的首页文本：字体应为 Noto Sans SC
    expect(tester.takeException(), isNull);
    expect(_homeText(tester, '我的净额').style?.fontFamily, AAFonts.bodyStandard);
    expect(_homeText(tester, '快捷入口').style?.fontFamily, AAFonts.bodyStandard);

    // 还原
    AAFonts.useStyle(AaFontStyle.hand);
  });

  testWidgets('切换风格后仍停留当前路由，返回首页也是新字体', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AAFonts.useStyle(AaFontStyle.hand);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const AaSplitApp(),
      ),
    );
    await bootToHome(tester);

    // 进入一个二级页面（提醒设置）
    GoRouter.of(tester.element(find.text('我的净额').first)).push('/messages/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('提醒设置'), findsWidgets);

    // 在二级页切换风格（等同设置页操作）
    await container.read(fontStyleProvider.notifier).setStyle(AaFontStyle.standard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    // 仍停留在当前二级页（路由栈未丢失），文本立即换新字体
    expect(tester.takeException(), isNull);
    expect(find.text('提醒设置'), findsWidgets);
    expect(
      tester.widget<Text>(find.text('提醒设置').first).style?.fontFamily,
      AAFonts.bodyStandard,
    );

    // 返回首页：首页文本同样是新字体（无需再触发其他交互）
    GoRouter.of(tester.element(find.text('提醒设置').first)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_homeText(tester, '我的净额').style?.fontFamily, AAFonts.bodyStandard);
    expect(_homeText(tester, '快捷入口').style?.fontFamily, AAFonts.bodyStandard);

    AAFonts.useStyle(AaFontStyle.hand);
  });
}
