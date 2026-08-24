import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock/mock_store.dart';
import '../models/bill.dart';
import '../models/group.dart';
import '../models/group_member.dart';
import '../models/notification_item.dart';
import '../models/regular_bill.dart';
import '../models/user.dart';
import 'auth_provider.dart';
import 'refresh_provider.dart';
import 'repositories.dart';

/// 当前登录用户
final currentUserProvider = Provider<User?>((ref) => ref.watch(authProvider).user);

/// 全部群组（连带实时成员数/未结清/总额）
final groupsProvider = Provider<List<Group>>((ref) {
  ref.watch(refreshProvider);
  return ref.read(groupRepositoryProvider).list();
});

/// 全部账单（按日期倒序，跨群组）
final billsProvider = Provider<List<Bill>>((ref) {
  ref.watch(refreshProvider);
  return ref.read(billRepositoryProvider).listAll();
});

/// 群组成员表（groupId → 成员）
final groupMembersProvider = Provider<Map<String, List<GroupMember>>>((ref) {
  ref.watch(refreshProvider);
  final store = MockStore.instance;
  final repo = ref.read(groupRepositoryProvider);
  return {
    for (final g in store.groups) g.id: repo.members(g.id),
  };
});

/// 消息列表（按时间倒序）
final notificationsProvider = Provider<List<NotificationItem>>((ref) {
  ref.watch(refreshProvider);
  return ref.read(notificationRepositoryProvider).list();
});

/// 未读消息数（Tab 角标）
final unreadCountProvider = Provider<int>((ref) {
  ref.watch(refreshProvider);
  return ref.read(notificationRepositoryProvider).unreadCount();
});

/// 定期账单
final regularBillsProvider = Provider<List<RegularBill>>((ref) {
  ref.watch(refreshProvider);
  return List.of(MockStore.instance.regularBills);
});
