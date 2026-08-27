// 消息中心「删除消息」回归测试：
// 1. 左滑消息卡 → 二次确认弹层；点「再想想」→ 消息保留
// 2. 左滑消息卡 → 点「删除」→ 消息从 MockStore 移除 + Toast 提示
// 3. AppBar「清空」→ 二次确认 → 全部消息清空 + Toast 提示
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

/// 左滑第一条消息卡并等待确认弹层出现
Future<void> _swipeFirstCard(WidgetTester tester) async {
  await tester.drag(find.byType(Dismissible).first, const Offset(-520, 0));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  // 弹层入场动画推进到位（带超时防挂起）
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 3),
  );
}

void main() {
  testWidgets('左滑消息卡弹二次确认；「再想想」取消后消息保留', (tester) async {
    await _pump(tester);
    final store = MockStore.instance;
    final countBefore = store.notifications.length;
    expect(countBefore, greaterThan(0), reason: 'Demo 种子应包含消息');

    await _swipeFirstCard(tester);
    expect(find.text('删除这条消息？'), findsOneWidget);

    // 取消 → 不删除
    await tester.tap(find.text('再想想'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(store.notifications.length, countBefore,
        reason: '取消删除后消息数量不变');

    // 冲掉滑回动画计时
    await tester.pump(const Duration(milliseconds: 350));
  });

  testWidgets('左滑消息卡确认「删除」后消息被移除', (tester) async {
    await _pump(tester);
    final store = MockStore.instance;
    final sorted = List.of(store.notifications)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final firstId = sorted.first.id;
    final countBefore = store.notifications.length;

    await _swipeFirstCard(tester);
    expect(find.text('删除这条消息？'), findsOneWidget);

    // 确认删除（弹层内 DoodleButton「删除」，避开左滑背景里的同文案 Text）
    await tester.tap(find.widgetWithText(DoodleButton, '删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('🗑️ 已删除'), findsOneWidget);
    expect(store.notifications.length, countBefore - 1,
        reason: '确认后消息应被删除一条');
    expect(store.notifications.where((n) => n.id == firstId), isEmpty,
        reason: '被删除的应是刚左滑的那条消息');

    // 冲掉 Toast 计时器
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('AppBar「清空」确认后清空全部消息', (tester) async {
    await _pump(tester);
    final store = MockStore.instance;
    expect(store.notifications, isNotEmpty, reason: '前置用例后仍应存在消息');
    expect(find.text('清空'), findsOneWidget);

    await tester.tap(find.text('清空'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('清空全部消息？'), findsOneWidget);

    // 弹层内确认按钮也叫「清空」→ 用 DoodleButton 精准定位
    await tester.tap(find.widgetWithText(DoodleButton, '清空'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('🗑️ 已清空全部消息'), findsOneWidget);
    expect(store.notifications, isEmpty, reason: '确认后全部消息应被清空');

    // 冲掉 Toast 计时器
    await tester.pump(const Duration(seconds: 2));
  });
}
