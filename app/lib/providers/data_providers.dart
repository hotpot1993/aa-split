import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config.dart';
import '../data/mock/mock_store.dart';
import '../data/repositories/exchange_rate_repository.dart';
import '../models/bill.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../models/notification_item.dart';
import '../models/regular_bill.dart';
import '../models/transfer.dart';
import '../models/user.dart';
import '../models/user_device.dart';
import 'auth_provider.dart';
import 'refresh_provider.dart';
import 'repositories.dart';

/// 当前登录用户
final currentUserProvider = Provider<User?>((ref) => ref.watch(authProvider).user);

/// 全部群组（连带实时成员数/未结清/总额）
final groupsProvider = FutureProvider<List<Group>>((ref) async {
  ref.watch(refreshProvider);
  return ref.read(groupRepositoryProvider).list();
});

/// 全部账单（按日期倒序，跨群组）
final billsProvider = FutureProvider<List<Bill>>((ref) async {
  ref.watch(refreshProvider);
  return ref.read(billRepositoryProvider).listAll();
});

/// 群组成员表（groupId → 成员，含净额）
final groupMembersProvider = FutureProvider<Map<String, List<GroupMember>>>(
    (ref) async {
  ref.watch(refreshProvider);
  // 本机成员列表以「我」的最新会话资料为准：换头像/改昵称后立即重算同步显示，
  // 无需等服务端回包（与服务端推送的 SSE 刷新双保险）。
  final me = ref.watch(currentUserProvider);
  final repo = ref.read(groupRepositoryProvider);
  final groups = AppConfig.useMock
      ? MockStore.instance.groups
      : (await ref.read(groupsProvider.future));
  final map = <String, List<GroupMember>>{};
  for (final g in groups) {
    map[g.id] = await repo.members(g.id);
  }
  // 本人行（昵称/账户名/头像）覆写为会话最新值 —— 语义与 Demo 仓库一致
  if (me != null) {
    for (final list in map.values) {
      final i = list.indexWhere((m) => m.userId == me.id);
      if (i < 0) continue;
      final m = list[i];
      if (m.nickname == me.nickname &&
          m.accountName == me.accountName &&
          m.avatarUrl == me.avatarUrl) {
        continue;
      }
      list[i] = m.copyWith(
        nickname: me.nickname,
        accountName: me.accountName,
        avatarUrl: me.avatarUrl,
      );
    }
  }
  return map;
});

/// 消息列表（按时间倒序）
final notificationsProvider = FutureProvider<List<NotificationItem>>((ref) async {
  ref.watch(refreshProvider);
  return ref.read(notificationRepositoryProvider).list();
});

/// 未读消息数（Tab 角标）
final unreadCountProvider = FutureProvider<int>((ref) async {
  ref.watch(refreshProvider);
  return ref.read(notificationRepositoryProvider).unreadCount();
});

/// 定期账单
final regularBillsProvider = FutureProvider<List<RegularBill>>((ref) async {
  ref.watch(refreshProvider);
  if (AppConfig.useMock) {
    return List.of(MockStore.instance.regularBills);
  }
  return ref.read(billRepositoryProvider).listRegular();
});

/// 群结算方案（最少转账笔数）
final settlementPlanProvider = FutureProvider.family<SettlementPlan, String>(
    (ref, groupId) async {
  ref.watch(refreshProvider);
  return ref.read(settlementRepositoryProvider).compute(groupId);
});

/// 逐笔结算明细（P25 模式切换）
final perBillTransfersProvider =
    FutureProvider.family<List<Transfer>, String>((ref, groupId) async {
  ref.watch(refreshProvider);
  return ref.read(settlementRepositoryProvider).perBill(groupId);
});

/// 今日汇率（1 单位外币 = 多少人民币；网络失败回退参考汇率并标记）
final exchangeRateProvider =
    FutureProvider.family<RateResult, String>((ref, code) async {
  return ref.read(exchangeRateRepositoryProvider).rate(code);
});

/// 登录设备列表（P52 账号安全：真实数据；Demo 模式为 MockStore 演示数据）
final loginDevicesProvider = FutureProvider<List<UserDevice>>((ref) async {
  ref.watch(refreshProvider);
  return ref.read(authRepositoryProvider).listDevices();
});
