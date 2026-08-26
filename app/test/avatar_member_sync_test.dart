// 头像同步（需求：换头像后群成员列表同步显示新头像）回归测试：
// - 仓库层：Mock 模式下当前用户头像取最新资料（不读取加群时的快照）
// - 界面层：成员行以 SketchAvatar 渲染头像（emoji/本地文件/网络图统一）
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/data/mock/mock_store.dart';
import 'package:aa_split_app/data/repositories/group_repository.dart';
import 'package:aa_split_app/screens/groups/members_screen.dart';
import 'package:aa_split_app/widgets/avatar.dart';

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
  test('换头像后 Mock 成员数据即时使用最新头像（快照不再生效）', () async {
    final original = MockStore.instance.currentUser;
    addTearDown(() => MockStore.instance.currentUser = original);

    // 更换头像（如相册本地路径）
    MockStore.instance.currentUser =
        original.copyWith(avatarUrl: 'C:/fake/avatar.png');
    final members = await GroupRepository().members('g1');
    final me = members.firstWhere((m) => m.userId == 'me');
    expect(me.avatarUrl, 'C:/fake/avatar.png');

    // 恢复默认头像
    MockStore.instance.currentUser = original.copyWith(avatarUrl: '🦄');
    final members2 = await GroupRepository().members('g1');
    expect(members2.firstWhere((m) => m.userId == 'me').avatarUrl, '🦄');
    // 其他成员头像不受影响
    expect(members2.firstWhere((m) => m.userId == 'u_zhangsan').avatarUrl,
        '🐰');
  });

  testWidgets('成员管理：每行以 SketchAvatar 渲染头像', (tester) async {
    await _pump(tester, const MembersScreen(groupId: 'g1'));
    // 饭友群 4 名成员 → 4 个头像组件
    expect(find.byType(SketchAvatar), findsNWidgets(4));
    // 昵称行正常展示
    expect(find.textContaining('团子酱'), findsWidgets);
    expect(find.textContaining('张三'), findsWidgets);
  });
}
