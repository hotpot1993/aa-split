// 消息中心「全部已读」回归测试：
// 有未读消息时按钮出现；点击后当前所有未读消息标记为已读（Mock 全链路），按钮随之隐藏
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/data/mock/mock_store.dart';
import 'package:aa_split_app/screens/messages/messages_screen.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAaTheme(),
        home: const MessagesScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('未读 > 0 时显示「全部已读」；点击后全部标记已读并隐藏按钮', (tester) async {
    await _pump(tester);

    final store = MockStore.instance;
    final unreadBefore = store.notifications.where((n) => !n.isRead).length;
    expect(unreadBefore, greaterThan(0), reason: 'Demo 种子应包含未读消息');
    expect(find.text('全部已读'), findsOneWidget);

    await tester.tap(find.text('全部已读'));
    await tester.pump(); // 异步 markAllRead + bump
    await tester.pump(const Duration(milliseconds: 300)); // 通知列表/角标刷新
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('📮 已全部标记为已读'), findsOneWidget);
    expect(store.notifications.where((n) => !n.isRead), isEmpty,
        reason: '当前所有未读消息应被标记为已读');
    // 未读归零 → 按钮隐藏
    expect(find.text('全部已读'), findsNothing);

    // 冲掉 Toast 计时器
    await tester.pump(const Duration(seconds: 2));
  });
}
