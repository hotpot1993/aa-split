// 收款卡片（需求：点击后把「一键智能结算」结果生成图片并保存本地）回归测试：
// - 卡片通过 Overlay 离屏渲染 → RepaintBoundary 截屏 → 保存 PNG（测试态平台通道缺失时仅 toast）
// - 卡片内不包含二维码元素（需求：生成图片中不要二维码）
// - 空方案提示、按钮路径无异常
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:aa_split_app/screens/groups/settlement_screen.dart';

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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('点击「收款卡片」按钮：渲染卡片并尝试保存（无异常）', (tester) async {
    await _pump(tester, const SettlementScreen(groupId: 'g1'));

    // 结算方案已加载（饭友群有未结清账单 → 转账款存在）
    await tester.scrollUntilVisible(find.text('收款卡片'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('收款卡片'), findsOneWidget);
    await tester.tap(find.text('收款卡片'));
    // 触发 Overlay 离屏卡片渲染 + 截屏 + 保存（测试态截屏为真实异步，至多失败提示）
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);

    // 冲掉 Toast 计时器
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('生成的收款卡片不含二维码元素（旧名「收款码卡片」文案已移除）', (tester) async {
    await _pump(tester, const SettlementScreen(groupId: 'g1'));

    await tester.scrollUntilVisible(find.text('收款卡片'), 200,
        scrollable: find.byType(Scrollable).first);
    // 页面上不应再出现旧按钮名
    expect(find.text('收款码卡片'), findsNothing);

    await tester.tap(find.text('收款卡片'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Overlay 中渲染的卡片不含 QrImageView（二维码已移除）
    expect(find.byType(QrImageView), findsNothing);

    await tester.pump(const Duration(seconds: 2));
  });
}
