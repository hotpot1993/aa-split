import '../../core/config.dart';
import '../../models/group.dart';
import '../../models/group_member.dart';
import '../mock/mock_store.dart';

/// 群组仓库（Demo 模式走 MockStore）
///
/// 非 Demo 模式：应改为 async 并调用 ApiClient 的 `/groups` 接口（技术方案 §4.2）。
class GroupRepository {
  GroupRepository();

  List<Group> list() {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final out = store.groups.map((g) {
        final active = store.activeMembersOf(g.id);
        final bills = store.billsForGroup(g.id);
        final pending = bills.where((b) => !b.fullySettled).length;
        final total = bills.fold<int>(0, (s, b) => s + b.amountCents);
        return g.copyWith(
          memberCount: active.length,
          pendingBillCount: pending,
          totalCents: total,
          recentBillTitle: bills.isEmpty ? '' : bills.first.title,
          recentBillDate: bills.isEmpty ? null : bills.first.billDate,
        );
      }).toList();
      return out;
    }
    throw UnsupportedError('useMock=false：GroupRepository.list 需 async + ApiClient');
  }

  Group create({
    required String name,
    String intro = '',
    String avatar = '🐼',
    GroupDefaultSplit defaultSplit = GroupDefaultSplit.even,
  }) {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final me = store.currentUser;
      final group = Group(
        id: 'g${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        avatar: avatar,
        intro: intro,
        ownerId: me.id,
        defaultSplit: defaultSplit,
        inviteCode: 'INV${DateTime.now().millisecondsSinceEpoch % 100000}',
        memberCount: 1,
      );
      store.groups.add(group);
      store.members[group.id] = [
        GroupMember(
          id: '${me.id}_gm',
          userId: me.id,
          nickname: me.nickname,
          accountName: me.accountName,
          avatarUrl: me.avatarUrl,
          isOwner: true,
          status: 'active',
          joinedAt: DateTime.now(),
        ),
      ];
      return group;
    }
    throw UnsupportedError('useMock=false：GroupRepository.create 需 async + ApiClient');
  }

  Group get(String id) {
    if (AppConfig.useMock) {
      final g = MockStore.instance.groupById(id);
      if (g == null) throw UnsupportedError('群组不存在');
      return g;
    }
    throw UnsupportedError('useMock=false：GroupRepository.get 需 async + ApiClient');
  }

  void update(String id, {String? name, String? intro, String? avatar}) {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final idx = store.groups.indexWhere((g) => g.id == id);
      if (idx < 0) return;
      final g = store.groups[idx];
      store.groups[idx] = g.copyWith(name: name, intro: intro, avatar: avatar);
      return;
    }
    throw UnsupportedError('useMock=false：GroupRepository.update 需 async + ApiClient');
  }

  /// 解散群组（仅群主，需二次确认）
  void disband(String id) {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      store.groups.removeWhere((g) => g.id == id);
      store.bills.removeWhere((b) => b.groupId == id);
      store.members.remove(id);
      return;
    }
    throw UnsupportedError('useMock=false：GroupRepository.disband 需 async + ApiClient');
  }

  List<GroupMember> members(String groupId) {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final net = _netBalances(store, groupId);
      return store.activeMembersOf(groupId).map((m) {
        final balance = net[m.userId] ?? 0;
        return GroupMember(
          id: m.id,
          userId: m.userId,
          nickname: m.nickname,
          accountName: m.accountName,
          avatarUrl: m.avatarUrl,
          isOwner: m.isOwner,
          status: m.status,
          joinedAt: m.joinedAt,
          netBalanceCents: balance,
        );
      }).toList();
    }
    throw UnsupportedError('useMock=false：GroupRepository.members 需 async + ApiClient');
  }

  void addMember(String groupId, String accountName) {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final users = _demoUsers;
      String? key;
      for (final k in users.keys) {
        if (k.toLowerCase() == accountName.trim().toLowerCase()) {
          key = k;
          break;
        }
      }
      final nm = key == null ? accountName.trim() : users[key]!;
      final avatar = key == null ? '🐼' : store.avatarFor(key);
      store.members[groupId]!.add(GroupMember(
        id: '${key ?? nm}_gm',
        userId: key ?? nm,
        nickname: nm,
        accountName: key ?? '',
        avatarUrl: avatar,
        isOwner: false,
        status: 'active',
        joinedAt: DateTime.now(),
      ));
      store.refreshGroup(groupId);
      return;
    }
    throw UnsupportedError('useMock=false：GroupRepository.addMember 需 async + ApiClient');
  }

  void removeMember(String groupId, String userId) {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final list = store.members[groupId];
      if (list == null) return;
      list.removeWhere((m) => m.userId == userId);
      store.refreshGroup(groupId);
      return;
    }
    throw UnsupportedError('useMock=false：GroupRepository.removeMember 需 async + ApiClient');
  }

  bool join(String inviteCode) {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      for (final g in store.groups) {
        if (g.inviteCode == inviteCode.trim()) return true;
      }
      return false;
    }
    throw UnsupportedError('useMock=false：GroupRepository.join 需 async + ApiClient');
  }

  String inviteLink(String groupId) {
    if (AppConfig.useMock) {
      final g = MockStore.instance.groupById(groupId);
      final code = g?.inviteCode ?? '';
      return '${AppConfig.inviteScheme}$code';
    }
    throw UnsupportedError('useMock=false：GroupRepository.inviteLink 需 async + ApiClient');
  }

  /// 用于演示的可搜索成员字典（账户名 → 昵称）
  Map<String, String> get _demoUsers => {
        'zhangsan': '张三',
        'lisi': '李四',
        'wangwu': '王五',
        'xiaoming': '小明',
        'xiaohong': '小红',
        'xiaolu': '小鹿',
        'aqiang': '阿强',
        'ahua': '阿花',
      };

  Map<String, int> _netBalances(MockStore store, String groupId) {
    final net = <String, int>{};
    for (final m in store.activeMembersOf(groupId)) {
      net[m.userId] = 0;
    }
    for (final b in store.billsForGroup(groupId)) {
      if (b.fullySettled) continue;
      final payer = b.payerId;
      var credit = 0;
      for (final p in b.participants) {
        if (p.exempt || p.userId == payer || p.paid) continue;
        net[p.userId] = (net[p.userId] ?? 0) - p.shareAmountCents;
        credit += p.shareAmountCents;
      }
      net[payer] = (net[payer] ?? 0) + credit;
    }
    return net;
  }
}
