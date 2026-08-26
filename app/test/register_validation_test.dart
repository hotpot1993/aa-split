// 注册输入限制回归测试（需求：账户名 ≤16 字符；昵称 ≤30 字符或 ≤16 汉字；密码 ≥8 字符）
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/screens/auth/register_screen.dart';

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
        home: const RegisterScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  // 字段顺序：账户名 / 昵称 / 密码 / 确认密码 / 安全问题答案
  testWidgets('账户名最多 16 个字符', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).at(0), 'a' * 17);
    await tester.pump();
    expect(find.text('账户名最多 16个字符哦'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'a' * 16);
    await tester.pump();
    expect(find.text('账户名最多 16个字符哦'), findsNothing);
  });

  testWidgets('昵称最多 30 个字符（1 个汉字按 2 个计，最多 16 字）', (tester) async {
    await _pump(tester);

    // 17 个汉字超限
    await tester.enterText(find.byType(TextField).at(1), '团' * 17);
    await tester.pump();
    expect(find.text('昵称最多 30 个字符（1 个汉字按 2 个计，最多 16 字）'), findsOneWidget);

    // 16 个汉字恰好通过
    await tester.enterText(find.byType(TextField).at(1), '团' * 16);
    await tester.pump();
    expect(find.text('昵称最多 30 个字符（1 个汉字按 2 个计，最多 16 字）'), findsNothing);

    // 31 个 ASCII 字符超限（30 个恰好通过）
    await tester.enterText(find.byType(TextField).at(1), 'a' * 31);
    await tester.pump();
    expect(find.text('昵称最多 30 个字符（1 个汉字按 2 个计，最多 16 字）'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'a' * 30);
    await tester.pump();
    expect(find.text('昵称最多 30 个字符（1 个汉字按 2 个计，最多 16 字）'), findsNothing);
  });

  testWidgets('密码最少 8 个字符', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField).at(2), 'abc123');
    await tester.pump();
    expect(find.text('密码至少 8位哦'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(2), 'abc12345');
    await tester.pump();
    expect(find.text('密码至少 8位哦'), findsNothing);
  });
}
