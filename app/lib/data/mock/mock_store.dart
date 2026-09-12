import '../../core/api/api_client.dart';
import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../models/bill_participant.dart';
import '../../models/group.dart';
import '../../models/group_member.dart';
import '../../models/notification_item.dart';
import '../../models/regular_bill.dart';
import '../../models/user.dart';
import '../../models/user_device.dart';

/// 内存假数据（Demo 模式）
///
/// 用户名：团子酱；3 个群；每群 3-4 成员 + 3-5 笔账单（含 pending/partial/settled、
/// 垫付人、分摊明细、部分已付）；若干通知；结算方案示例（≥3 笔）。
/// 金额一律以「分」存储。
class MockStore {
  MockStore._() {
    _seed();
  }

  static final MockStore instance = MockStore._();

  User currentUser = const User(
    id: 'me',
    accountName: 'tuanzi',
    nickname: '团子酱',
    avatarUrl: '🐼',
    bio: '吃小笼包长大的团团本团',
    securityQuestion: '你第一个朋友的名字？',
    createdAt: 1717200000000,
  );

  final List<Group> groups = [];
  final Map<String, List<GroupMember>> members = {};
  final List<Bill> bills = [];
  final List<NotificationItem> notifications = [];
  final List<RegularBill> regularBills = [];
  final List<UserDevice> devices = [
    UserDevice(
      id: 'demo-dev-1',
      deviceId: 'demo-current',
      platform: 'android',
      deviceName: '演示设备 · Android',
      osVersion: '15',
      ip: '127.0.0.1',
      lastLoginAt: Fmt.clock(),
    ),
    UserDevice(
      id: 'demo-dev-2',
      deviceId: 'demo-old',
      platform: 'ios',
      deviceName: '旧手机 · iPhone 15',
      osVersion: '18',
      ip: '127.0.0.1',
      lastLoginAt: Fmt.clock().subtract(const Duration(days: 1)),
    ),
  ];

  // ---------- 查询 ----------

  List<Bill> billsForGroup(String groupId) =>
      bills.where((b) => b.groupId == groupId).toList()
        ..sort((a, b) => b.billDate.compareTo(a.billDate));

  List<GroupMember> membersOf(String groupId) => members[groupId] ?? const [];

  List<GroupMember> activeMembersOf(String groupId) =>
      (members[groupId] ?? const [])
          .where((m) => m.status == 'active')
          .toList();

  GroupMember? memberOf(String groupId, String userId) {
    for (final m in (members[groupId] ?? const [])) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  Group? groupById(String id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  Bill? billById(String id) {
    for (final b in bills) {
      if (b.id == id) return b;
    }
    return null;
  }

  /// 成员头像（emoji）
  String avatarFor(String userId) => _avatarOf(userId);

  // ---------- 非注册成员（占位账号）----------
  // 语义与服务端一致（见 CONTEXT.md / docs/adr/0001）：不可登录、不接收通知、
  // 群内不可重名（含已退出成员）、单群上限 50 人、认领后合并历史且不可撤销。

  /// 名称净化：去除换行与控制字符后 trim（服务端同规则）
  static String sanitizeDisplayName(String raw) =>
      raw.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '').trim();

  /// 群内重名校验（含已退出成员）
  void _assertNameFree(String groupId, String name, {String? exceptUserId}) {
    final dup = membersOf(groupId).any(
      (m) => m.userId != exceptUserId && m.displayName == name,
    );
    if (dup) throw const ApiException(409, '群内已有同名成员，换个名字吧');
  }

  /// 添加非注册成员（仅群主，由界面保证入口可见性）
  GroupMember addPlaceholderMember(String groupId, String displayName) {
    final list = members[groupId];
    if (list == null) throw const ApiException(404, '群组不存在');
    final name = sanitizeDisplayName(displayName);
    if (name.isEmpty || name.length > 32) {
      throw const ApiException(400, '名称长度需为 1–32 个字符');
    }
    _assertNameFree(groupId, name);
    if (list.where((m) => m.isActive).length >= 50) {
      throw const ApiException(409, '群成员已达上限 50 人');
    }
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final member = GroupMember(
      id: 'ph_$stamp',
      userId: 'ph_$stamp',
      nickname: name,
      accountName: '', // 占位账号没有可用账户名
      avatarUrl: '🐼',
      isOwner: false,
      status: 'active',
      joinedAt: Fmt.clock(),
      isPlaceholder: true,
    );
    list.add(member);
    refreshGroup(groupId);
    // 其他成员照常收到「新成员加入」播报（占位账号本人不接收任何通知）
    final group = groupById(groupId);
    notifications.add(NotificationItem(
      id: 'n_ph_$stamp',
      type: NotifyType.member,
      title: '新成员加入',
      body: '$name 加入了「${group?.name ?? '群组'}」',
      createdAt: Fmt.clock(),
      isRead: false,
      refType: 'group',
      refId: groupId,
    ));
    return member;
  }

  /// 修改非注册成员名称
  void renamePlaceholderMember(
    String groupId,
    String userId,
    String displayName,
  ) {
    final list = members[groupId];
    if (list == null) throw const ApiException(404, '群组不存在');
    final idx = list.indexWhere((m) => m.userId == userId);
    if (idx < 0 || !list[idx].isPlaceholder) {
      throw const ApiException(404, '非注册成员不存在');
    }
    final name = sanitizeDisplayName(displayName);
    if (name.isEmpty || name.length > 32) {
      throw const ApiException(400, '名称长度需为 1–32 个字符');
    }
    _assertNameFree(groupId, name, exceptUserId: userId);
    list[idx] = list[idx].copyWith(nickname: name);
    refreshGroup(groupId);
  }

  /// 认领前的合法性校验（服务端同规则）
  ({GroupMember placeholder, GroupMember target}) _assertClaimable(
    String groupId,
    String userId,
    String targetUserId,
  ) {
    final placeholder = memberOf(groupId, userId);
    if (placeholder == null || !placeholder.isPlaceholder) {
      throw const ApiException(404, '非注册成员不存在');
    }
    final target = memberOf(groupId, targetUserId);
    if (target == null || target.isPlaceholder) {
      throw const ApiException(404, '目标账号不存在');
    }
    if (target.userId == placeholder.userId) {
      throw const ApiException(400, '不能认领到本人');
    }
    return (placeholder: placeholder, target: target);
  }

  ClaimPreview claimPreview(
    String groupId,
    String userId,
    String targetUserId,
  ) {
    final v = _assertClaimable(groupId, userId, targetUserId);
    final billCount = billsForGroup(groupId)
        .where((b) =>
            b.payerId == userId ||
            b.participants.any((p) => p.userId == userId))
        .length;
    return ClaimPreview(
      billCount: billCount,
      // Demo 模式的结算方案是即时算出来的，没有落库的历史记录
      settlementCount: 0,
      placeholderName: v.placeholder.nickname,
      targetName: v.target.nickname,
      targetInGroup: v.target.isActive,
    );
  }

  /// 认领：把非注册成员的全部历史合并到真实账号（不可撤销）
  ClaimPreview claimPlaceholderMember(
    String groupId,
    String userId,
    String targetUserId,
  ) {
    final v = _assertClaimable(groupId, userId, targetUserId);
    final preview = claimPreview(groupId, userId, targetUserId);
    final list = members[groupId]!;

    // ① 成员关系：目标已在群 → 加入时间取更早、删除占位行；否则占位行改挂目标（自动入群）
    final tIndex = list.indexWhere((m) => m.userId == targetUserId);
    final pIndex = list.indexWhere((m) => m.userId == userId);
    if (tIndex >= 0) {
      final t = list[tIndex];
      final p = list[pIndex];
      final joinedAt =
          (p.joinedAt != null && t.joinedAt != null && p.joinedAt!.isBefore(t.joinedAt!))
              ? p.joinedAt
              : t.joinedAt;
      list[tIndex] = GroupMember(
        id: t.id,
        userId: t.userId,
        nickname: t.nickname,
        accountName: t.accountName,
        avatarUrl: t.avatarUrl,
        isOwner: t.isOwner,
        status: t.status,
        joinedAt: joinedAt,
        netBalanceCents: t.netBalanceCents,
      );
      list.removeAt(pIndex);
    } else {
      final p = list[pIndex];
      list[pIndex] = GroupMember(
        id: v.target.id,
        userId: v.target.userId,
        nickname: v.target.nickname,
        accountName: v.target.accountName,
        avatarUrl: v.target.avatarUrl,
        isOwner: v.target.isOwner,
        status: 'active',
        joinedAt: p.joinedAt,
        netBalanceCents: v.target.netBalanceCents,
      );
    }

    // ② 账单参与人：冲突行金额相加（保住账单总额）、paid/exempt 取 AND；无冲突行改挂
    for (var i = 0; i < bills.length; i++) {
      final b = bills[i];
      if (b.groupId != groupId) continue;
      final hasPlaceholder = b.participants.any((p) => p.userId == userId);
      final isPayer = b.payerId == userId;
      if (!hasPlaceholder && !isPayer) continue;

      final next = <BillParticipant>[];
      for (final p in b.participants) {
        if (p.userId != userId) {
          next.add(p);
          continue;
        }
        final ti = next.indexWhere((x) => x.userId == targetUserId);
        if (ti >= 0) {
          final t = next[ti];
          final bothPaid = t.paid && p.paid;
          next[ti] = BillParticipant(
            userId: t.userId,
            nickname: t.nickname,
            avatarUrl: t.avatarUrl,
            shareAmountCents: t.shareAmountCents + p.shareAmountCents,
            paid: bothPaid,
            exempt: t.exempt && p.exempt,
            remindCount: t.remindCount,
          );
        } else {
          next.add(BillParticipant(
            userId: targetUserId,
            nickname: v.target.nickname,
            avatarUrl: v.target.avatarUrl,
            shareAmountCents: p.shareAmountCents,
            paid: p.paid,
            exempt: p.exempt,
            remindCount: p.remindCount,
          ));
        }
      }
      bills[i] = b.copyWith(
        payerId: isPayer ? targetUserId : null,
        payerName: isPayer ? v.target.nickname : null,
        participants: next,
      );
    }

    // ③ 免分摊名单替换（与服务端 default_exempt_user_ids 同语义）
    final gIndex = groups.indexWhere((g) => g.id == groupId);
    if (gIndex >= 0) {
      final g = groups[gIndex];
      if (g.defaultExemptUserIds.contains(userId)) {
        groups[gIndex] = g.copyWith(
          defaultExemptUserIds: {
            for (final id in g.defaultExemptUserIds)
              id == userId ? targetUserId : id,
          }.toList(),
        );
      }
    }

    refreshGroup(groupId);
    return preview;
  }

  /// 重新计算群组的成员数/未结清笔数/总额，并写回（供增删成员/账单后刷新）
  void refreshGroup(String groupId) {
    final idx = groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;
    final g = groups[idx];
    final active = activeMembersOf(groupId).length;
    final bs = billsForGroup(groupId);
    final pending = bs.where((b) => !b.fullySettled).length;
    final total = bs.fold<int>(0, (s, b) => s + b.amountCents);
    groups[idx] = g.copyWith(
      memberCount: active,
      pendingBillCount: pending,
      totalCents: total,
      recentBillTitle: bs.isEmpty ? '' : bs.first.title,
      recentBillDate: bs.isEmpty ? null : bs.first.billDate,
    );
  }

  // ---------- 种子 ----------
  void _seed() {
    // 演示数据日期取自可注入时钟：配合 Fmt.clock 固定后，商店截图/测试跨时段稳定
    final now = Fmt.clock();
    final me = currentUser;

    // 成员定义
    final zhangSan = _gm('u_zhangsan', '张三', '🐰');
    final liSi = _gm('u_lisi', '李四', '🐻');
    final wangWu = _gm('u_wangwu', '王五', '🐹');
    final xiaoMing = _gm('u_xiaoming', '小明', '🦊');
    final xiaoHong = _gm('u_xiaohong', '小红', '🐷');
    final xiaoLu = _gm('u_xiaolu', '小鹿', '🦌', isOwner: true);
    final aQiang = _gm('u_aqiang', '阿强', '🐯');
    final aHua = _gm('u_ahua', '阿花', '🐣');

    // ---- 群 1：饭友群 ----
    final g1 = Group(
      id: 'g1',
      name: '饭友群',
      avatar: '🍚',
      intro: '干饭人的快乐老家',
      ownerId: me.id,
      inviteCode: 'FAN12345',
      memberCount: 4,
      pendingBillCount: 2,
      recentBillTitle: '今晚聚餐',
      recentBillDate: now.subtract(const Duration(days: 2)),
    );
    groups.add(g1);
    members['g1'] = [
      _gm(me.id, me.nickname, me.avatarUrl, isOwner: true),
      zhangSan,
      liSi,
      wangWu,
    ];

    bills.addAll([
      _bill(
        'b1',
        g1,
        title: '今晚聚餐',
        amountCents: 22000,
        date: now.subtract(const Duration(days: 2)),
        category: BillCategory.food,
        payerId: me.id,
        payerName: me.nickname,
        location: '海底捞',
        participants: [
          _p(me.id, me.nickname, 5500, paid: true),
          _p('u_zhangsan', '张三', 5500, paid: false),
          _p('u_lisi', '李四', 5500, paid: false),
          _p('u_wangwu', '王五', 5500, paid: false),
        ],
        status: BillSettleStatus.partial,
      ),
      _bill(
        'b2',
        g1,
        title: '打车去饭店',
        amountCents: 3800,
        date: now.subtract(const Duration(days: 5)),
        category: BillCategory.traffic,
        payerId: 'u_zhangsan',
        payerName: '张三',
        participants: [
          _p(me.id, me.nickname, 950, paid: true),
          _p('u_zhangsan', '张三', 950, paid: true),
          _p('u_lisi', '李四', 950, paid: true),
          _p('u_wangwu', '王五', 950, paid: true),
        ],
        status: BillSettleStatus.settled,
        receipts: [const Receipt(id: 'r_b2_0', billId: 'b2', url: '🧾')],
      ),
      _bill(
        'b3',
        g1,
        title: '老火锅',
        amountCents: 31000,
        date: now.subtract(const Duration(days: 8)),
        category: BillCategory.food,
        payerId: me.id,
        payerName: me.nickname,
        location: '朝天门',
        participants: [
          _p(me.id, me.nickname, 10333, paid: true),
          _p('u_lisi', '李四', 10333, paid: false),
          _p('u_wangwu', '王五', 10334, paid: true),
          _p('u_zhangsan', '张三', 0, exempt: true), // 张三请客，免摊
        ],
        status: BillSettleStatus.partial,
      ),
      _bill(
        'b4',
        g1,
        title: '电影',
        amountCents: 12000,
        date: now.subtract(const Duration(days: 10)),
        category: BillCategory.fun,
        payerId: 'u_lisi',
        payerName: '李四',
        participants: [
          _p(me.id, me.nickname, 3000, paid: true),
          _p('u_zhangsan', '张三', 3000, paid: true),
          _p('u_lisi', '李四', 3000, paid: true),
          _p('u_wangwu', '王五', 3000, paid: true),
        ],
        status: BillSettleStatus.settled,
      ),
    ]);

    // ---- 群 2：合租小分队 ----
    final g2 = Group(
      id: 'g2',
      name: '合租小分队',
      avatar: '🏠',
      intro: '三个人的小家',
      ownerId: me.id,
      inviteCode: 'HEZU8888',
      memberCount: 3,
      pendingBillCount: 2,
      recentBillTitle: '7月房租',
      recentBillDate: now.subtract(const Duration(days: 1)),
    );
    groups.add(g2);
    members['g2'] = [
      _gm(me.id, me.nickname, me.avatarUrl, isOwner: true),
      xiaoMing,
      xiaoHong,
    ];
    bills.addAll([
      _bill(
        'b5',
        g2,
        title: '7月房租',
        amountCents: 150000,
        date: now.subtract(const Duration(days: 1)),
        category: BillCategory.hotel,
        payerId: me.id,
        payerName: me.nickname,
        participants: [
          _p(me.id, me.nickname, 50000, paid: true),
          _p('u_xiaoming', '小明', 50000, paid: true),
          _p('u_xiaohong', '小红', 50000, paid: false),
        ],
        status: BillSettleStatus.partial,
        isRegular: true,
      ),
      _bill(
        'b6',
        g2,
        title: '电费',
        amountCents: 12000,
        date: now.subtract(const Duration(days: 6)),
        category: BillCategory.other,
        payerId: 'u_xiaoming',
        payerName: '小明',
        participants: [
          _p(me.id, me.nickname, 4000, paid: true),
          _p('u_xiaoming', '小明', 4000, paid: true),
          _p('u_xiaohong', '小红', 4000, paid: true),
        ],
        status: BillSettleStatus.settled,
      ),
      _bill(
        'b7',
        g2,
        title: '清洁用品',
        amountCents: 8800,
        date: now.subtract(const Duration(days: 3)),
        category: BillCategory.shopping,
        payerId: 'u_xiaohong',
        payerName: '小红',
        participants: [
          _p(me.id, me.nickname, 2934, paid: true),
          _p('u_xiaoming', '小明', 2933, paid: false),
          _p('u_xiaohong', '小红', 2933, paid: true),
        ],
        status: BillSettleStatus.partial,
      ),
    ]);

    // ---- 群 3：周末露营 ----
    final g3 = Group(
      id: 'g3',
      name: '周末露营',
      avatar: '⛺',
      intro: '拒绝宅家，去野去野',
      ownerId: 'u_xiaolu',
      inviteCode: 'CAMP0001',
      memberCount: 4,
      pendingBillCount: 2,
      recentBillTitle: '露营装备',
      recentBillDate: now.subtract(const Duration(days: 4)),
    );
    groups.add(g3);
    members['g3'] = [
      _gm(me.id, me.nickname, me.avatarUrl),
      xiaoLu,
      aQiang,
      aHua,
    ];
    bills.addAll([
      _bill(
        'b8',
        g3,
        title: '露营装备',
        amountCents: 46000,
        date: now.subtract(const Duration(days: 4)),
        category: BillCategory.shopping,
        payerId: 'u_xiaolu',
        payerName: '小鹿',
        participants: [
          _p(me.id, me.nickname, 11500, paid: true),
          _p('u_xiaolu', '小鹿', 11500, paid: true),
          _p('u_aqiang', '阿强', 11500, paid: false),
          _p('u_ahua', '阿花', 11500, paid: false),
        ],
        status: BillSettleStatus.partial,
      ),
      _bill(
        'b9',
        g3,
        title: '烧烤食材',
        amountCents: 21000,
        date: now.subtract(const Duration(days: 7)),
        category: BillCategory.food,
        payerId: 'u_aqiang',
        payerName: '阿强',
        participants: [
          _p(me.id, me.nickname, 5250, paid: true),
          _p('u_xiaolu', '小鹿', 5250, paid: true),
          _p('u_aqiang', '阿强', 5250, paid: true),
          _p('u_ahua', '阿花', 5250, paid: true),
        ],
        status: BillSettleStatus.settled,
      ),
      _bill(
        'b10',
        g3,
        title: '过路费',
        amountCents: 8650,
        date: now.subtract(const Duration(days: 1)),
        category: BillCategory.traffic,
        payerId: 'u_ahua',
        payerName: '阿花',
        participants: [
          _p(me.id, me.nickname, 2163, paid: false),
          _p('u_xiaolu', '小鹿', 2162, paid: false),
          _p('u_aqiang', '阿强', 2162, paid: false),
          _p('u_ahua', '阿花', 2163, paid: true),
        ],
        status: BillSettleStatus.pending,
      ),
    ]);

    // ---- 通知 ----
    notifications.addAll([
      NotificationItem(
        id: 'n1',
        type: NotifyType.remind,
        title: '张三催你付 AA',
        body: '今晚聚餐 · 2小时前',
        createdAt: now.subtract(const Duration(hours: 2)),
        isRead: false,
        refType: 'bill',
        refId: 'b1',
      ),
      NotificationItem(
        id: 'n3',
        type: NotifyType.invite,
        title: '小鹿邀请你加入「徒步群」',
        body: '点击接受，一起走起',
        createdAt: now.subtract(const Duration(days: 2)),
        isRead: false,
        refType: 'group',
        refId: 'g3',
      ),
      NotificationItem(
        id: 'n4',
        type: NotifyType.regular,
        title: '7月房租已生成',
        body: '定期账单 · ¥1,500.00',
        createdAt: now.subtract(const Duration(days: 1)),
        isRead: true,
        refType: 'bill',
        refId: 'b5',
      ),
      NotificationItem(
        id: 'n5',
        type: NotifyType.member,
        title: '阿花加入了「周末露营」',
        body: '欢迎新人～',
        createdAt: now.subtract(const Duration(days: 3)),
        isRead: true,
        refType: 'group',
        refId: 'g3',
      ),
      NotificationItem(
        id: 'n6',
        type: NotifyType.settled,
        title: '饭友群已清账',
        body: '两不相欠啦 🎉',
        createdAt: now.subtract(const Duration(days: 4)),
        isRead: true,
        refType: 'group',
        refId: 'g1',
      ),
    ]);

    // ---- 定期账单 ----
    regularBills.addAll([
      RegularBill(
        id: 'rb1',
        groupId: 'g2',
        groupName: '合租小分队',
        title: '房租',
        amountCents: 150000,
        category: BillCategory.hotel,
        cycle: RegularCycle.monthly,
        dayOfMonth: 1,
      ),
      RegularBill(
        id: 'rb2',
        groupId: 'g2',
        groupName: '合租小分队',
        title: '水电',
        amountCents: 15000,
        category: BillCategory.other,
        cycle: RegularCycle.monthly,
        dayOfMonth: 5,
      ),
    ]);
  }

  GroupMember _gm(String userId, String nickname, String avatar,
          {bool isOwner = false}) =>
      GroupMember(
        id: '${userId}_gm',
        userId: userId,
        nickname: nickname,
        accountName: nickname.toLowerCase(),
        avatarUrl: avatar,
        isOwner: isOwner,
        status: 'active',
        joinedAt: DateTime(2025, 1, 1),
      );

  BillParticipant _p(String userId, String nickname, int share,
          {bool paid = false, bool exempt = false}) =>
      BillParticipant(
        userId: userId,
        nickname: nickname,
        avatarUrl: _avatarOf(userId),
        shareAmountCents: share,
        paid: paid,
        exempt: exempt,
      );

  Bill _bill(
    String id,
    Group group, {
    required String title,
    required int amountCents,
    required DateTime date,
    required BillCategory category,
    required String payerId,
    required String payerName,
    String location = '',
    List<BillParticipant> participants = const [],
    BillSettleStatus status = BillSettleStatus.pending,
    bool isRegular = false,
    List<Receipt> receipts = const [],
  }) =>
      Bill(
        id: id,
        groupId: group.id,
        groupName: group.name,
        title: title,
        amountCents: amountCents,
        billDate: date,
        location: location,
        category: category,
        payerId: payerId,
        payerName: payerName,
        participants: participants,
        splitType: SplitType.even,
        receipts: receipts,
        isRegular: isRegular,
        settleStatus: status,
        createdAt: date,
      );

  String _avatarOf(String userId) => switch (userId) {
        'me' => '🐼',
        'u_zhangsan' => '🐰',
        'u_lisi' => '🐻',
        'u_wangwu' => '🐹',
        'u_xiaoming' => '🦊',
        'u_xiaohong' => '🐷',
        'u_xiaolu' => '🦌',
        'u_aqiang' => '🐯',
        'u_ahua' => '🐣',
        _ => '🐼',
      };
}
