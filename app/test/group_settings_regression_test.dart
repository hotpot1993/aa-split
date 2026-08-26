// 群组设置回归测试：
// 1. 已移除「默认分摊方式」；「免分摊人员默认」可点击 → 成员多选弹层 → 保存生效
// 2. 普通成员无打开群组设置页权限（守卫兜底）
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/data/mock/mock_store.dart';
import 'package:aa_split_app/screens/groups/group_settings_screen.dart';

Future<void> _pump(WidgetTester tester, String groupId) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAaTheme(),
        home: GroupSettingsScreen(groupId: groupId),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('群主：已无「默认分摊方式」；免分摊人员默认可交互并保存', (tester) async {
    await _pump(tester, 'g1');

    // 默认分摊方式已移除
    expect(find.text('默认分摊方式'), findsNothing);
    expect(find.text('免分摊人员默认'), findsOneWidget);

    // 点击 → 成员多选弹层（可正常交互）
    await tester.tap(find.text('免分摊人员默认'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.textContaining('默认免分摊人员'), findsOneWidget);
    expect(find.text('张三'), findsOneWidget);

    // 勾选张三 → 确定
    await tester.tap(find.text('张三'));
    await tester.pump();
    await tester.tap(find.text('确定（1人免分摊）✓'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // 已保存到群组设置（Mock 全链路）
    final g1 = MockStore.instance.groupById('g1')!;
    expect(g1.defaultExemptUserIds, ['u_zhangsan']);
    expect(find.text('张三 ▾'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2)); // 冲掉 Toast
  });

  testWidgets('非群主：无权限进入群组设置（守卫）', (tester) async {
    // g3 群主为 u_xiaolu，当前用户非群主
    await _pump(tester, 'g3');
    expect(find.text('只有群主才能进入群组设置哦'), findsOneWidget);
    expect(find.text('免分摊人员默认'), findsNothing);
  });
}
