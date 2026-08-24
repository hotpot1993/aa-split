import '../../models/bill.dart';
import '../../models/bill_participant.dart';
import '../../models/group.dart';
import '../../models/group_member.dart';
import '../../models/notification_item.dart';
import '../../models/regular_bill.dart';
import '../../models/user.dart';

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
    final now = DateTime.now();
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
        id: 'n2',
        type: NotifyType.newBill,
        title: '合租小分队新增了账单',
        body: '7月房租 ¥1,500.00 · 昨天',
        createdAt: now.subtract(const Duration(days: 1)),
        isRead: false,
        refType: 'bill',
        refId: 'b5',
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
