// 注册页防重复提交回归测试：
// 连点「注册并开始」→ 仅调用一次注册（单次操作限一次）
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_split_app/data/repositories/auth_repository.dart';
import 'package:aa_split_app/models/user.dart';
import 'package:aa_split_app/providers/repositories.dart';
import 'package:aa_split_app/screens/auth/register_screen.dart';

/// 计数版仓库：统计 register 真实调用次数
class _CountingAuthRepository extends AuthRepository {
  int registerCalls = 0;

  @override
  Future<User> register({
    required String accountName,
    required String password,
    required String nickname,
    required String securityQuestion,
    required String securityAnswer,
  }) {
    registerCalls++;
    return super.register(
      accountName: accountName,
      password: password,
      nickname: nickname,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
    );
  }
}

class _RouterHost extends ConsumerStatefulWidget {
  const _RouterHost();
  @override
  ConsumerState<_RouterHost> createState() => _RouterHostState();
}

class _RouterHostState extends ConsumerState<_RouterHost> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/register',
    routes: [
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
      GoRoute(
          path: '/home',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('HOME-OK')))),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: buildAaTheme(),
      routerConfig: _router,
    );
  }
}

void main() {
  testWidgets('连点注册按钮：仅注册一次并进入主框架', (tester) async {
    final repo = _CountingAuthRepository();
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
      child: const _RouterHost(),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    // 填写注册表单（账户/昵称/密码/确认/安全问题答案 + 勾选协议）
    await tester.enterText(find.byType(TextField).at(0), 'xiaohei');
    await tester.enterText(find.byType(TextField).at(1), '小黑');
    await tester.enterText(find.byType(TextField).at(2), 'abc12345');
    await tester.enterText(find.byType(TextField).at(3), 'abc12345');
    await tester.enterText(find.byType(TextField).at(4), '小虎');
    await tester.pump();
    await tester.tap(find.byType(AaCheckbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300)); // 账户可用性检查

    // 同帧连点两次（快速双击）
    final btn = find.text('注册并开始');
    await tester.tap(btn);
    await tester.tap(btn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));

    // 关键断言：仅注册一次 + 已跳转主框架
    expect(repo.registerCalls, 1);
    expect(find.text('HOME-OK'), findsOneWidget);
  });
}
