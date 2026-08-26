// 「记一笔」表单字段回归测试（需求：货币/群组/垫付人统一右对齐；选项列表高度受限可滚动）
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/screens/add/add_bill_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(720, 1560);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAaTheme(),
        home: const AddBillScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('货币/群组/垫付人 的值统一显示在表单右侧', (tester) async {
    await _pump(tester);

    // 表单内容右缘 ≈ 360 - 16(页面) - 14(卡片) - 2(行内) = 328；
    // 值右侧还有 ▾ 图标，值文本右缘应 > 300（修复前紧跟标签右侧 ≈ 232）
    for (final label in ['人民币 (CNY)', '饭友群', '团子酱']) {
      await tester.ensureVisible(find.text(label));
      final rect = tester.getRect(find.text(label));
      expect(rect.right, greaterThan(300),
          reason: '$label 应右对齐（当前 right=${rect.right.toStringAsFixed(1)}）');
      expect(rect.left, greaterThan(150),
          reason: '$label 不应紧跟左侧标签（当前 left=${rect.left.toStringAsFixed(1)}）');
    }
  });

  testWidgets('货币选择弹层：列表高度受限且可选择（选美元后值右对齐）', (tester) async {
    await _pump(tester);

    await tester.ensureVisible(find.text('人民币 (CNY)'));
    await tester.tap(find.text('人民币 (CNY)'));
    await tester.pumpAndSettle();

    expect(find.text('选个货币'), findsOneWidget);
    final list = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(ListView),
    );
    final listH = tester.getSize(list).height;
    // 12 个货币项，若不受限会 ≈ 624px；限制后 ≤ 屏高 60%（780*0.55≈429）
    expect(listH, lessThanOrEqualTo(430), reason: '选项列表高度应受限（当前 $listH）');

    await tester.tap(find.text('美元 (USD)'));
    await tester.pumpAndSettle();
    expect(find.text('选个货币'), findsNothing);
    expect(find.text('美元 (USD)'), findsOneWidget);
    final rect = tester.getRect(find.text('美元 (USD)'));
    expect(rect.right, greaterThan(300), reason: '切换货币后仍应右对齐');
  });

  testWidgets('群组/垫付人选择弹层：可正常选择并右对齐', (tester) async {
    await _pump(tester);

    // 群组：饭友群 → 合租小分队
    await tester.ensureVisible(find.text('饭友群'));
    await tester.tap(find.text('饭友群'));
    await tester.pumpAndSettle();
    expect(find.text('选个群组'), findsOneWidget);
    await tester.tap(find.text('合租小分队'));
    await tester.pumpAndSettle();
    expect(find.text('合租小分队'), findsOneWidget);
    expect(find.text('饭友群'), findsNothing);
    expect(tester.getRect(find.text('合租小分队')).right, greaterThan(300));

    // 垫付人：团子酱 → 小红（当前群 合租小分队 的成员）
    await tester.tap(find.text('团子酱'));
    await tester.pumpAndSettle();
    expect(find.text('选垫付人'), findsOneWidget);
    await tester.tap(find.text('小红'));
    await tester.pumpAndSettle();
    expect(find.text('小红'), findsOneWidget);
    expect(tester.getRect(find.text('小红')).right, greaterThan(300));
  });
}
