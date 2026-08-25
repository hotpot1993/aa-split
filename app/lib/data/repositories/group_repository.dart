import '../../core/api/api_client.dart';
import '../../core/api/codec.dart';
import '../../core/config.dart';
import '../../models/bill.dart';
import '../../models/group.dart';
import '../../models/group_member.dart';
import '../mock/mock_store.dart';

/// 群组仓库。
/// Demo 模式走 MockStore；真实模式调用 /groups 系列接口，
/// 群列表/成员净额所需统计（未结清数/总额/净额）由客户端按账单数据派生。
class GroupRepository {
  GroupRepository();

  Future<List<Group>> list() async {
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
    final res = await ApiClient.instance.get('/groups');
    final raw = res.data is List ? res.data as List : const [];
    final groups = raw.map(parseGroup).toList();
    // 派生：未结清数/总额/最近账单（服务端列表不携带）
    final names = <String, String>{for (final g in groups) g.id: g.name};
    for (var i = 0; i < groups.length; i++) {
      final bills = await _billsOf(groups[i].id, names);
      final pending = bills.where((b) => !b.fullySettled).length;
      groups[i] = groups[i].copyWith(
        pendingBillCount: pending,
        totalCents: bills.fold<int>(0, (s, b) => s + b.amountCents),
        recentBillTitle: bills.isEmpty ? '' : bills.first.title,
        recentBillDate: bills.isEmpty ? null : bills.first.billDate,
      );
    }
    return groups;
  }

  Future<Group> create({
    required String name,
    String intro = '',
    String avatar = '🐼',
    GroupDefaultSplit defaultSplit = GroupDefaultSplit.even,
  }) async {
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
    final res = await ApiClient.instance.post('/groups', body: {
      'name': name,
      'intro': intro,
      'avatarUrl': avatar,
      'defaultSplitType': defaultSplit.name,
    });
    final group = parseGroup(res.data);
    return group.copyWith(memberCount: 1);
  }

  Future<Group> get(String id) async {
    if (AppConfig.useMock) {
      final g = MockStore.instance.groupById(id);
      if (g == null) throw UnsupportedError('群组不存在');
      return g;
    }
    final res = await ApiClient.instance.get('/groups/$id');
    return parseGroup(res.data);
  }

  Future<void> update(String id,
      {String? name, String? intro, String? avatar}) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final idx = store.groups.indexWhere((g) => g.id == id);
      if (idx < 0) return;
      final g = store.groups[idx];
      store.groups[idx] = g.copyWith(name: name, intro: intro, avatar: avatar);
      return;
    }
    await ApiClient.instance.patch('/groups/$id', body: {
      'name': ?name,
      'intro': ?intro,
      'avatarUrl': ?avatar,
    });
  }

  /// 解散群组（仅群主，需二次确认）
  Future<void> disband(String id) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      store.groups.removeWhere((g) => g.id == id);
      store.bills.removeWhere((b) => b.groupId == id);
      store.members.remove(id);
      return;
    }
    await ApiClient.instance.delete('/groups/$id');
  }

  Future<List<GroupMember>> members(String groupId) async {
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
    // 详情接口含成员列表；净额派生自未结清账单
    final res = await ApiClient.instance.get('/groups/$groupId');
    final j = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
    final ownerId = (j['ownerId'] ?? '').toString();
    final bills = await _billsOf(groupId, {});
    final net = _netFromBills(bills, groupId);
    final raw = (j['members'] is List) ? j['members'] as List : const [];
    return raw.map((e) {
      final m = parseGroupMember(e, isOwner: false);
      return GroupMember(
        id: m.userId,
        userId: m.userId,
        nickname: m.nickname,
        accountName: m.accountName,
        avatarUrl: m.avatarUrl,
        isOwner: m.userId == ownerId,
        status: m.status,
        joinedAt: m.joinedAt,
        netBalanceCents: net[m.userId] ?? 0,
      );
    }).toList();
  }

  Future<void> addMember(String groupId, String accountName) async {
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
    await ApiClient.instance.post('/groups/$groupId/members', body: {
      'accountName': accountName.trim(),
    });
  }

  Future<void> removeMember(String groupId, String userId) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final list = store.members[groupId];
      if (list == null) return;
      list.removeWhere((m) => m.userId == userId);
      store.refreshGroup(groupId);
      return;
    }
    await ApiClient.instance.delete('/groups/$groupId/members/$userId');
  }

  /// 通过邀请码加入群（扫二维码 / 填写邀请链接均走这里；大小写宽容）
  Future<GroupJoinResult> join(String inviteCode) async {
    final code = inviteCode.trim().toUpperCase();
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      for (final g in store.groups) {
        if (g.inviteCode.toUpperCase() == code) {
          final already =
              store.memberOf(g.id, store.currentUser.id)?.status == 'active';
          return GroupJoinResult(
            id: g.id,
            name: g.name,
            alreadyJoined: already,
          );
        }
      }
      throw const ApiException(404, '邀请码无效');
    }
    final res = await ApiClient.instance.post('/groups/join', body: {
      'inviteCode': code,
    });
    final j = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
    return GroupJoinResult(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      alreadyJoined: (j['alreadyJoined'] ?? false) as bool? ?? false,
    );
  }

  Future<String> inviteLink(String groupId) async {
    if (AppConfig.useMock) {
      final g = MockStore.instance.groupById(groupId);
      final code = g?.inviteCode ?? '';
      return '${AppConfig.inviteScheme}$code';
    }
    final res = await ApiClient.instance.get('/groups/$groupId/invite');
    final j = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
    final code = (j['inviteCode'] ?? '').toString();
    return '${AppConfig.inviteScheme}$code';
  }

  // ---- 内部工具 ----

  Future<List<Bill>> _billsOf(String groupId, Map<String, String> groupNames) async {
    // 群账单流水第一页就够派生统计（上限 100）
    final res = await ApiClient.instance.get('/groups/$groupId/bills',
        query: {'page': 1, 'pageSize': 100});
    final j = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
    final list = (j['list'] is List) ? j['list'] as List : const [];
    return list
        .map((e) => parseBill(e, groupName: groupNames[groupId] ?? ''))
        .toList();
  }

  /// 用户净额派生（正=应收，负=应付）—— 与 Demo 逻辑/Mock 一致
  static Map<String, int> _netFromBills(List<Bill> bills, String groupId) {
    final net = <String, int>{};
    for (final b in bills) {
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

  Map<String, int> _netBalances(MockStore store, String groupId) =>
      _netFromBills(store.billsForGroup(groupId), groupId);

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
}
