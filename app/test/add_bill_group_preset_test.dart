// 回归：记一笔时群组预选 —— 群组详情进入应预选当前群（Demo 模式）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/screens/add/add_bill_screen.dart';

Future<void> _pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp(home: screen)),
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  testWidgets('initialGroupId=g2 → 预选「合租小分队」，而非第一个群', (tester) async {
    await _pump(tester, const AddBillScreen(initialGroupId: 'g2'));
    expect(tester.takeException(), isNull);
    // 下拉框（关闭态）只显示当前选中群名
    expect(find.text('合租小分队'), findsOneWidget);
    expect(find.text('饭友群'), findsNothing);
  });

  testWidgets('无参 → 默认第一个群（兼容原行为）', (tester) async {
    await _pump(tester, const AddBillScreen());
    expect(tester.takeException(), isNull);
    expect(find.text('饭友群'), findsOneWidget);
  });

  testWidgets('不存在的 groupId → 回退第一个群（Dropdown value 不悬空）', (tester) async {
    await _pump(tester, const AddBillScreen(initialGroupId: 'g404'));
    expect(tester.takeException(), isNull);
    expect(find.text('饭友群'), findsOneWidget);
  });
}
