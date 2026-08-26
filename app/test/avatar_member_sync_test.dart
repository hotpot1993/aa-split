// 头像同步（需求：换头像后群成员列表同步显示新头像）回归测试：
// - 仓库层：Mock 模式下当前用户头像取最新资料（不读取加群时的快照）
// - 界面层：成员行以 SketchAvatar 渲染头像（emoji/本地文件/网络图统一）
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/core/utils/avatar_ref.dart';
import 'package:aa_split_app/data/mock/mock_store.dart';
import 'package:aa_split_app/data/repositories/group_repository.dart';
import 'package:aa_split_app/models/group_member.dart';
import 'package:aa_split_app/providers/auth_provider.dart';
import 'package:aa_split_app/providers/data_providers.dart';
import 'package:aa_split_app/providers/repositories.dart';
import 'package:aa_split_app/screens/groups/members_screen.dart';
import 'package:aa_split_app/widgets/avatar.dart';

/// 成员仓库桩：始终返回「加群时的旧头像」——用于验证 Provider 层
/// 会以当前会话资料覆写本人行（不依赖服务端回包）。
class _StaleMembersRepo extends GroupRepository {
  @override
  Future<List<GroupMember>> members(String groupId) async => [
        const GroupMember(
          id: 'me_gm',
          userId: 'me',
          nickname: '团子酱',
          accountName: 'tuanzi',
          avatarUrl: '🐼',
          isOwner: true,
        ),
        const GroupMember(
          id: 'z_gm',
          userId: 'u_zhangsan',
          nickname: '张三',
          accountName: 'zhangsan',
          avatarUrl: '🐰',
          isOwner: false,
        ),
      ];
}

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

  test('isLocalAvatarRef：识别本机路径脏数据，放行合法头像引用', () {
    // 本机路径（旧版本直接入库 → 跨设备/重启失效）应判定为脏数据
    expect(isLocalAvatarRef('C:/fake/avatar.png'), isTrue);
    expect(isLocalAvatarRef('C:\\Users\\me\\Temp\\avatar.png'), isTrue);
    expect(isLocalAvatarRef('/data/user/0/pkg/cache/avatar.jpg'), isTrue);
    expect(isLocalAvatarRef('file:///data/x.jpg'), isTrue);
    // 合法头像引用放行
    expect(isLocalAvatarRef('/uploads/ab12.jpg'), isFalse);
    expect(isLocalAvatarRef('http://cdn/x/a.png'), isFalse);
    expect(isLocalAvatarRef('https://cdn/x/a.png'), isFalse);
    expect(isLocalAvatarRef('🐼'), isFalse);
    expect(isLocalAvatarRef(''), isFalse);
  });

  test('群成员 Provider：换头像后「我」的行即时用最新头像（无需等服务端回包）', () async {
    final container = ProviderContainer(overrides: [
      // 仓库桩始终返回旧头像（模拟服务端数据滞后）
      groupRepositoryProvider.overrideWithValue(_StaleMembersRepo()),
    ]);
    addTearDown(container.dispose);
    final original = MockStore.instance.currentUser;
    addTearDown(() => MockStore.instance.currentUser = original);

    await container.read(groupMembersProvider.future);
    expect(
      container.read(groupMembersProvider).value!['g1']!
          .firstWhere((m) => m.userId == 'me').avatarUrl,
      '🐼',
    );

    // 模拟「我的」换头像成功（AuthController 同步本地会话态）
    await container.read(authProvider.notifier).updateProfile(avatarUrl: '🦄');
    await container.read(groupMembersProvider.future);

    // 本人行被本地会话资料覆写 → 成员列表无需等服务端回包即显示新头像
    final me = container.read(groupMembersProvider).value!['g1']!
        .firstWhere((m) => m.userId == 'me');
    expect(me.avatarUrl, '🦄');
    // 其它成员仍用服务端返回
    expect(
      container.read(groupMembersProvider).value!['g1']!
          .firstWhere((m) => m.userId == 'u_zhangsan').avatarUrl,
      '🐰',
    );
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
