import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/add/add_bill_screen.dart';
import '../screens/add/participants_screen.dart';
import '../screens/add/receipt_screen.dart';
import '../screens/add/regular_bill_screen.dart';
import '../screens/add/split_screen.dart';
import '../screens/auth/forgot_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/reset_screen.dart';
import '../screens/groups/create_group_screen.dart';
import '../screens/groups/group_detail_screen.dart';
import '../screens/groups/group_settings_screen.dart';
import '../screens/groups/groups_screen.dart';
import '../screens/groups/invite_screen.dart';
import '../screens/groups/members_screen.dart';
import '../screens/groups/remind_screen.dart';
import '../screens/groups/settlement_screen.dart';
import '../screens/home/bill_detail_screen.dart';
import '../screens/home/bills_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/stats_screen.dart';
import '../screens/messages/messages_screen.dart';
import '../screens/messages/reminder_settings_screen.dart';
import '../screens/profile/about_screen.dart';
import '../screens/profile/export_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/security_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/shell/shell_screen.dart';
import '../screens/splash/splash_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// 手绘翻页路由（技术方案/UI规范 §8.1：旋转+平移+淡入，非左右滑动）
Page<void> aaPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final turn = Tween<double>(begin: -0.021, end: 0).animate(animation);
      final slide =
          Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
              .animate(animation);
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: slide,
          child: Transform.rotate(angle: turn.value, child: child),
        ),
      );
    },
  );
}

GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      // 接入层
      GoRoute(path: '/', builder: (c, s) => const SplashScreen()),
      GoRoute(
          path: '/login',
          pageBuilder: (c, s) => aaPage(s, const LoginScreen())),
      GoRoute(
          path: '/register',
          pageBuilder: (c, s) => aaPage(s, const RegisterScreen())),
      GoRoute(
          path: '/forgot',
          pageBuilder: (c, s) => aaPage(s, const ForgotScreen())),
      GoRoute(
          path: '/forgot/reset',
          pageBuilder: (c, s) => aaPage(s, const ResetScreen())),

      // 记一笔（P30，中央 ➕ 浮出，无底部导航）
      GoRoute(
          path: '/add',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(s, const AddBillScreen())),

      // 账单
      GoRoute(
          path: '/bills',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(s, const BillsScreen())),
      GoRoute(
          path: '/bills/:id',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(
              s, BillDetailScreen(billId: s.pathParameters['id']!))),
      GoRoute(
          path: '/bills/:id/receipt',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(
              s, ReceiptScreen(billId: s.pathParameters['id']!))),
      GoRoute(
          path: '/bills/:id/split',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(
              s, SplitScreen(billId: s.pathParameters['id']!))),
      GoRoute(
          path: '/bills/:id/participants',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(
              s, ParticipantsScreen(billId: s.pathParameters['id']!))),
      GoRoute(
          path: '/regular-bills',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(s, const RegularBillScreen())),
      GoRoute(
          path: '/stats',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(s, const StatsScreen())),

      // 消息 / 设置 / 搜索
      GoRoute(
          path: '/messages/settings',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(s, const ReminderSettingsScreen())),
      GoRoute(
          path: '/search',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(s, const SearchScreen())),
      GoRoute(
          path: '/settings',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(s, const SettingsScreen())),
      GoRoute(
          path: '/security',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(s, const SecurityScreen())),
      GoRoute(
          path: '/export',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(s, const ExportScreen())),
      GoRoute(
          path: '/about',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(s, const AboutScreen())),

      // 群组详情子页
      GoRoute(
          path: '/groups/create',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(s, const CreateGroupScreen())),
      GoRoute(
          path: '/groups/:id',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(
              s, GroupDetailScreen(groupId: s.pathParameters['id']!))),
      GoRoute(
          path: '/groups/:id/invite',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(
              s, InviteScreen(groupId: s.pathParameters['id']!))),
      GoRoute(
          path: '/groups/:id/members',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(
              s, MembersScreen(groupId: s.pathParameters['id']!))),
      GoRoute(
          path: '/groups/:id/settlement',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(
              s, SettlementScreen(groupId: s.pathParameters['id']!))),
      GoRoute(
          path: '/groups/:id/remind',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(
              s, RemindScreen(groupId: s.pathParameters['id']!))),
      GoRoute(
          path: '/groups/:id/settings',
          parentNavigatorKey: rootNavigatorKey,
          pageBuilder: (c, s) => aaPage(
              s, GroupSettingsScreen(groupId: s.pathParameters['id']!))),

      // 主框架（底部 4 Tab + 中央 ➕）
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ShellScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/home',
                pageBuilder: (c, s) => aaPage(s, const HomeScreen())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/groups',
                pageBuilder: (c, s) => aaPage(s, const GroupsScreen())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/messages',
                pageBuilder: (c, s) => aaPage(s, const MessagesScreen())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile',
                pageBuilder: (c, s) => aaPage(s, const ProfileScreen())),
          ]),
        ],
      ),
    ],
  );
}
