// 登录流程回归测试：
// 1. 未注册账户登录 → 停留登录页并给出「账户不存在」提示（修复：登录失败不得进入总览）
// 2. 已注册账户登录 → 成功进入总览首页
// 3. 未登录态访问主框架路由 → 路由守卫重定向回登录页
// 4. 「我的」未登录态提供「去登录」出口（修复：不再无路可退）
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_split_app/providers/auth_provider.dart';
import 'package:aa_split_app/router/app_router.dart';
import 'package:aa_split_app/screens/auth/login_screen.dart';
import 'package:aa_split_app/screens/profile/profile_screen.dart';

/// 未登录起步的控制器（Demo 默认自动登录，本组测试需要从登录页开始）
class _LoggedOutAuthController extends AuthController {
  @override
  AuthState build() => const AuthState();
}

/// 测试里的全局路由句柄（供用例直接驱动导航，断言路由守卫）
GoRouter? testRouter;

/// 与生产一致的路由宿主：ProviderScope 之下的 ConsumerStatefulWidget
class _RouterHost extends ConsumerStatefulWidget {
  const _RouterHost();
  @override
  ConsumerState<_RouterHost> createState() => _RouterHostState();
}

class _RouterHostState extends ConsumerState<_RouterHost> {
  late final GoRouter _router = buildRouter(ref);

  @override
  void initState() {
    super.initState();
    testRouter = _router;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: buildAaTheme(),
      routerConfig: _router,
    );
  }
}

Widget _app() => ProviderScope(
      overrides: [authProvider.overrideWith(_LoggedOutAuthController.new)],
      child: const _RouterHost(),
    );

/// 等待启动页 5s 定时器 → 未登录跳转登录页
Future<void> _toLogin(WidgetTester tester) async {
  await tester.pumpWidget(_app());
  await tester.pump(); // 首帧
  await tester.pump(const Duration(seconds: 6)); // 启动页定时器
  await tester.pump(const Duration(milliseconds: 350)); // 翻页过渡
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _fillAndSubmit(WidgetTester tester, String account) async {
  await tester.enterText(find.byType(TextField).first, account);
  await tester.enterText(find.byType(TextField).last, 'abc12345');
  await tester.pump();
  await tester.tap(find.text('登 录🐾'));
  await tester.pump(); // 触发异步提交
  await tester.pump(const Duration(milliseconds: 350)); // 翻页过渡
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400)); // 旧页面退场
}

void main() {
  tearDown(() {
    testRouter = null;
  });

  testWidgets('未注册账户登录：停留登录页并提示账户不存在', (tester) async {
    await _toLogin(tester);
    expect(find.byType(LoginScreen), findsOneWidget);

    await _fillAndSubmit(tester, 'nobody_xyz');

    // 关键断言：未注册账户不进入总览，登录页显示行内错误
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('账户不存在，请注册'), findsOneWidget);
    expect(find.text('我的净额'), findsNothing);
  });

  testWidgets('已注册账户登录：成功进入总览首页', (tester) async {
    await _toLogin(tester);
    await _fillAndSubmit(tester, 'tuanzi');

    // Demo 演示账户 tuanzi（任意密码）→ 进入总览
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('我的净额'), findsWidgets);
  });

  testWidgets('未登录访问主框架：路由守卫重定向回登录页', (tester) async {
    await _toLogin(tester);
    final router = testRouter!;

    // 直接深链总览（绕过登录按钮）→ 守卫应打回登录页
    router.go('/home');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('我的净额'), findsNothing);
  });

  testWidgets('「我的」未登录态：提供去登录出口，不再无路可退', (tester) async {
    // 兜底场景：登录态失效但仍停留在主框架（此处用无守卫的最小路由直接渲染「我的」）
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(_LoggedOutAuthController.new)],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: buildAaTheme(),
        routerConfig: router,
      ),
    ));
    await tester.pump();

    expect(find.text('还没登录哦'), findsOneWidget);
    expect(find.text('🔑 去登录'), findsOneWidget);

    // 点击后回到登录页
    await tester.tap(find.text('🔑 去登录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
