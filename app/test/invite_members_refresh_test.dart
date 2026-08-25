// 回归：邀请页「方式二」添加成员后，群组详情/成员列表应刷新显示新成员（Demo 模式）
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/providers/data_providers.dart';
import 'package:aa_split_app/screens/groups/group_detail_screen.dart';
import 'package:aa_split_app/screens/groups/invite_screen.dart';

void main() {
  testWidgets('邀请页添加成员 → 群详情成员行立即出现新成员', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    Widget app(Widget child) => UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: child),
        );

    // 1. 邀请页（g1 饭友群）
    await tester.pumpWidget(app(const InviteScreen(groupId: 'g1')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));

    // 2. 方式二：添加一个 g1 中原本没有的成员「小明」（mock 字典 xiaoming）
    await tester.enterText(find.byType(TextField).first, 'xiaoming');
    await tester.tap(find.text('添加'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));

    // 3. 数据层：成员列表已包含小明（共 5 人）
    final members = (container.read(groupMembersProvider).value ?? {})['g1'] ?? [];
    final names = members.map((m) => m.nickname).toList();
    expect(names, contains('小明'));
    expect(members.length, 5);

    // 4. UI 层：切到群详情（模拟「完成，进入群组」），成员行渲染出小明
    await tester.pumpWidget(app(const GroupDetailScreen(groupId: 'g1')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('小明'), findsWidgets);
  });
}
