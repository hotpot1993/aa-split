// 字体风格（设置页「字体风格」切换）回归测试：
// - AAFonts 角色按 AaFontStyle 正确解析
// - 设置页可打开弹层切换到「标准风格」并即时生效
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_design/aa_design.dart';

import 'package:aa_split_app/providers/settings_provider.dart';
import 'package:aa_split_app/screens/profile/profile_screen.dart';

void main() {
  group('AAFonts 角色解析', () {
    test('手绘风格：手写字体家族 + 货币符号统一 JetBrains Mono', () {
      AAFonts.useStyle(AaFontStyle.hand);
      expect(AAFonts.title, AAFonts.titleHand);
      expect(AAFonts.hand, AAFonts.amountHand);
      expect(AAFonts.brand, AAFonts.brandHand);
      // 货币符号（¥）：两种风格统一 JetBrains Mono
      expect(AAFonts.currency, AAFonts.amountStandard);
      expect(AAFonts.accent, AAFonts.accentHand);
    });

    test('标准风格：金额/货币 JetBrains Mono，其余 Noto Sans SC', () {
      AAFonts.useStyle(AaFontStyle.standard);
      expect(AAFonts.hand, AAFonts.amountStandard);
      expect(AAFonts.currency, AAFonts.amountStandard);
      expect(AAFonts.title, AAFonts.bodyStandard);
      expect(AAFonts.brand, AAFonts.bodyStandard);
      expect(AAFonts.accent, AAFonts.bodyStandard);
      AAFonts.useStyle(AaFontStyle.hand);
    });
  });

  testWidgets('手绘风格下 HandAmount：正负号与 ¥ 用 JetBrains Mono，数字保留龙藏体', (tester) async {
    AAFonts.useStyle(AaFontStyle.hand);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HandAmount(amountCents: -102450, showSign: true),
        ),
      ),
    );
    final sign = tester.widget<Text>(find.text('-'));
    expect(sign.style?.fontFamily, AAFonts.amountStandard); // JetBrainsMono
    final yen = tester.widget<Text>(find.text('¥'));
    expect(yen.style?.fontFamily, AAFonts.amountStandard); // JetBrainsMono
    final num = tester.widget<Text>(find.text('1024.50'));
    expect(num.style?.fontFamily, AAFonts.amountHand); // LongCang
  });

  testWidgets('「我的」主页可切换字体风格并即时生效', (tester) async {
    AAFonts.useStyle(AaFontStyle.hand);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAaTheme(),
          home: const ProfileScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // 「我的」设置行值默认「手绘风格」
    expect(container.read(fontStyleProvider), AaFontStyle.hand);
    expect(find.text('手绘风格'), findsWidgets);

    // 打开「字体风格」弹层：两种风格 + 实时预览
    // （我的页头像有无限摇晃动效，不能用 pumpAndSettle，用固定时长推进）
    await tester.tap(find.text('字体风格'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('标准风格'), findsOneWidget);
    expect(find.text('¥ 1,024.50'), findsWidgets);

    // 选择「标准风格」→ 立即生效 + 持久化
    await tester.ensureVisible(find.text('标准风格'));
    await tester.tap(find.text('标准风格'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(container.read(fontStyleProvider), AaFontStyle.standard);
    expect(AAFonts.currentStyle, AaFontStyle.standard);
    // 弹层已关闭，「我的」页行内值同步为「标准风格」
    expect(find.text('标准风格'), findsWidgets);
    expect(find.text('手绘风格'), findsNothing);

    // 冲掉 Toast 计时器，避免 pending timer
    await tester.pump(const Duration(seconds: 2));

    // 还原为默认风格，避免影响其他用例
    AAFonts.useStyle(AaFontStyle.hand);
  });
}
