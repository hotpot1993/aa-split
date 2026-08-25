// 解散群组回归测试：
// 解散确认后，「我的群组」列表应立即移除该群（Demo 模式同步验证全链路）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/main.dart';
import 'package:aa_split_app/widgets/common.dart';

Future<void> bootToHome(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('解散群组：确认后从「我的群组」列表消失', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: AaSplitApp()));
    await bootToHome(tester);

    // 进入「我的群组」Tab
    await tester.tap(find.text('群组'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('饭友群'), findsOneWidget);

    // 进入饭友群详情 → 右上角设置 → 群组设置
    await tester.tap(find.text('饭友群'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AaIconImage), findsWidgets);
    await tester.tap(find.byWidgetPredicate(
        (w) => w is AaIconImage && w.asset == 'assets/icons/settings.png').first);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('群组设置'), findsOneWidget);

    // 解散群组 → 二次确认
    await tester.ensureVisible(find.text('🔥 解散群组'));
    await tester.tap(find.text('🔥 解散群组'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('要解散「饭友群」吗？'), findsOneWidget);

    await tester.tap(find.text('解散'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));

    // 回到群组列表：饭友群消失，其它群仍在
    expect(find.text('群组已解散'), findsOneWidget);
    expect(find.text('饭友群'), findsNothing);
    expect(find.text('合租小分队'), findsOneWidget);
    expect(find.text('周末露营'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });
}
