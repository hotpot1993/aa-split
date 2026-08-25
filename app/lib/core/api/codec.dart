import '../../models/bill.dart';
import '../../models/bill_participant.dart';
import '../../models/group.dart';
import '../../models/group_member.dart';
import '../../models/notification_item.dart';
import '../../models/regular_bill.dart';
import '../../models/statistics.dart';
import '../../models/transfer.dart';
import '../../models/user.dart';

/// 服务端 JSON → 客户端模型的防御性解析。
///
/// 服务端返回统一信封 {code,message,data}，本文件只处理 data 内部结构；
/// 金额一律整数分；时间：billDate 为 'YYYY-MM-DD'，其余为 ISO 字符串。
/// 字段名为 Prisma 模型的 camelCase（与客户端模型一致），
/// 枚举为服务端 snake_case（new_bill 等），此处做兼容映射。

String _safeStr(Map<String, dynamic> j, String key, [String def = '']) {
  final v = j[key];
  return v is String ? v : def;
}

int _safeInt(Map<String, dynamic> j, String key, [int def = 0]) {
  final v = j[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? def;
  return def;
}

bool _safeBool(Map<String, dynamic> j, String key, [bool def = false]) {
  final v = j[key];
  if (v is bool) return v;
  return def;
}

DateTime? _safeDate(Map<String, dynamic> j, String key) {
  final v = j[key];
  if (v == null || v.toString().isEmpty) return null;
  return DateTime.tryParse(v.toString());
}

Map<String, dynamic> _asMap(dynamic v) =>
    v is Map ? v.cast<String, dynamic>() : const {};

List<dynamic> _asList(dynamic v) => v is List ? v : const [];

// ---------- User ----------

User parseUser(dynamic data) {
  final j = _asMap(data);
  final created = _safeDate(j, 'createdAt');
  return User(
    id: _safeStr(j, 'id'),
    accountName: _safeStr(j, 'accountName'),
    nickname: _safeStr(j, 'nickname'),
    avatarUrl: _safeStr(j, 'avatarUrl', '🐼'),
    bio: _safeStr(j, 'bio'),
    securityQuestion: _safeStr(j, 'securityQuestion'),
    createdAt: created?.millisecondsSinceEpoch ?? 0,
  );
}

// ---------- Group ----------

GroupDefaultSplit _splitOf(String? v) => GroupDefaultSplit.values
    .firstWhere((e) => e.name == v, orElse: () => GroupDefaultSplit.even);

Group parseGroup(dynamic data) {
  final j = _asMap(data);
  return Group(
    id: _safeStr(j, 'id'),
    name: _safeStr(j, 'name'),
    avatar: _safeStr(j, 'avatarUrl', '🐼'),
    intro: _safeStr(j, 'intro'),
    ownerId: _safeStr(j, 'ownerId'),
    defaultSplit: _splitOf(_safeStr(j, 'defaultSplitType')),
    inviteCode: _safeStr(j, 'inviteCode'),
    memberCount: _safeInt(j, 'memberCount'),
    pendingBillCount: _safeInt(j, 'pendingBillCount'),
    recentBillTitle: _safeStr(j, 'recentBillTitle'),
    recentBillDate: _safeDate(j, 'recentBillDate'),
    totalCents: _safeInt(j, 'totalCents'),
  );
}

GroupMember parseGroupMember(dynamic data, {bool isOwner = false}) {
  final j = _asMap(data);
  return GroupMember(
    id: _safeStr(j, 'id', _safeStr(j, 'userId')),
    userId: _safeStr(j, 'userId'),
    nickname: _safeStr(j, 'nickname'),
    accountName: _safeStr(j, 'accountName'),
    avatarUrl: _safeStr(j, 'avatarUrl', '🐼'),
    isOwner: isOwner || _safeBool(j, 'isOwner'),
    status: _safeStr(j, 'status', 'active'),
    joinedAt: _safeDate(j, 'joinedAt'),
    netBalanceCents: _safeInt(j, 'netBalanceCents'),
  );
}

// ---------- Bill ----------

BillCategory _categoryOf(String? v) => BillCategory.values
    .firstWhere((e) => e.name == v, orElse: () => BillCategory.other);

SplitType _splitTypeOf(String? v) => SplitType.values
    .firstWhere((e) => e.name == v, orElse: () => SplitType.even);

BillSettleStatus _settleOf(String? v) => BillSettleStatus.values
    .firstWhere((e) => e.name == v, orElse: () => BillSettleStatus.pending);

/// 解析服务端 bill 对象（mapBill 形状）。
/// [groupName] 由调用方从群组数据注入（服务端 bill 不带群名）。
/// [payerNameFallback] 服务端 payer 对象缺失时的兜底。
Bill parseBill(dynamic data, {String groupName = '', String payerNameFallback = ''}) {
  final j = _asMap(data);
  final payer = _asMap(j['payer']);
  final date = DateTime.tryParse(_safeStr(j, 'billDate')) ?? DateTime.now();
  return Bill(
    id: _safeStr(j, 'id'),
    groupId: _safeStr(j, 'groupId'),
    groupName: groupName,
    title: _safeStr(j, 'title'),
    amountCents: _safeInt(j, 'amountCents'),
    billDate: date,
    location: _safeStr(j, 'location'),
    category: _categoryOf(_safeStr(j, 'category')),
    // payerId 兜底：老版本服务端 mapBill 只返回嵌套 payer 对象，缺顶层 payerId
    payerId: _safeStr(j, 'payerId', _safeStr(payer, 'id')),
    payerName: _safeStr(payer, 'nickname', payerNameFallback),
    participants: _asList(j['participants']).map(parseParticipant).toList(),
    splitType: _splitTypeOf(_safeStr(j, 'splitType')),
    receipts: _asList(j['receipts']).map(parseReceipt).toList(),
    isRegular: _safeBool(j, 'isRegular'),
    settleStatus: _settleOf(_safeStr(j, 'settleStatus')),
    createdAt: _safeDate(j, 'createdAt'),
  );
}

BillParticipant parseParticipant(dynamic data) {
  final j = _asMap(data);
  final user = _asMap(j['user']);
  return BillParticipant(
    userId: _safeStr(j, 'userId'),
    nickname: _safeStr(user, 'nickname', _safeStr(j, 'nickname')),
    avatarUrl: _safeStr(user, 'avatarUrl', _safeStr(j, 'avatarUrl', '🐼')),
    shareAmountCents: _safeInt(j, 'shareAmountCents'),
    paid: _safeBool(j, 'paid'),
    exempt: _safeBool(j, 'exempt'),
    remindCount: _safeInt(j, 'remindCount'),
  );
}

Receipt parseReceipt(dynamic data) {
  final j = _asMap(data);
  return Receipt(
    id: _safeStr(j, 'id'),
    billId: _safeStr(j, 'billId'),
    url: _safeStr(j, 'url'),
  );
}

// ---------- Transfer / Settlement ----------

Transfer parseTransfer(dynamic data) {
  final j = _asMap(data);
  return Transfer(
    fromUserId: _safeStr(j, 'fromUserId'),
    fromName: _safeStr(j, 'fromName', _safeStr(j, 'fromUserId')),
    toUserId: _safeStr(j, 'toUserId'),
    toName: _safeStr(j, 'toName', _safeStr(j, 'toUserId')),
    amountCents: _safeInt(j, 'amountCents'),
    billIds: _asList(j['billIds']).map((e) => e.toString()).toList(),
  );
}

// ---------- Notification ----------

NotifyType _notifyOf(String? v) => switch (v) {
      'new_bill' => NotifyType.newBill,
      'remind' => NotifyType.remind,
      'invite' => NotifyType.invite,
      'regular' => NotifyType.regular,
      'settled' => NotifyType.settled,
      'member' => NotifyType.member,
      _ => NotifyType.newBill,
    };

NotificationItem parseNotification(dynamic data) {
  final j = _asMap(data);
  return NotificationItem(
    id: _safeStr(j, 'id'),
    type: _notifyOf(_safeStr(j, 'type')),
    title: _safeStr(j, 'title'),
    body: _safeStr(j, 'body'),
    createdAt: _safeDate(j, 'createdAt') ?? DateTime.now(),
    isRead: _safeBool(j, 'isRead'),
    refType: _safeStr(j, 'refType'),
    refId: _safeStr(j, 'refId'),
  );
}

// ---------- RegularBill ----------

RegularCycle _cycleOf(String? v) => RegularCycle.values
    .firstWhere((e) => e.name == v, orElse: () => RegularCycle.monthly);

RegularBill parseRegularBill(dynamic data, {String groupName = ''}) {
  final j = _asMap(data);
  return RegularBill(
    id: _safeStr(j, 'id'),
    groupId: _safeStr(j, 'groupId'),
    groupName: groupName,
    title: _safeStr(j, 'title'),
    amountCents: _safeInt(j, 'amountCents'),
    category: _categoryOf(_safeStr(j, 'category')),
    splitType: _splitTypeOf(_safeStr(j, 'splitType')),
    cycle: _cycleOf(_safeStr(j, 'cycle')),
    dayOfMonth: _safeInt(j, 'dayOfMonth', 1),
    active: _safeBool(j, 'active', true),
  );
}

// ---------- Statistics（服务端 → 客户端统计模型） ----------

Statistics parseStatistics(dynamic data) {
  final j = _asMap(data);
  final byMonth = _asList(j['byMonth']).map((e) {
    final m = _asMap(e);
    return MonthStat(
      label: '${_safeInt(m, 'month')}月',
      amountCents: _safeInt(m, 'amountCents'),
    );
  }).toList();
  final byCategory = _asList(j['byCategory']).map((e) {
    final c = _asMap(e);
    return CategoryStat(
      category: _categoryOf(_safeStr(c, 'category')),
      amountCents: _safeInt(c, 'amountCents'),
    );
  }).toList();
  return Statistics(
    totalCents: _safeInt(j, 'totalAmountCents'),
    billCount: _safeInt(j, 'billCount'),
    categoryStats: byCategory,
    monthlyTrend: byMonth,
  );
}
