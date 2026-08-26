import 'dart:io' show File;

import '../../core/api/api_client.dart';
import '../../core/api/codec.dart';
import '../../core/config.dart';
import '../../models/bill.dart';
import '../../models/bill_participant.dart';
import '../../models/group.dart';
import '../../models/regular_bill.dart';
import '../mock/mock_store.dart';

/// 账单仓库。
/// Demo 模式走 MockStore；真实模式调用 /bills 与 /groups/:id/bills、
/// /regular-bills 等接口（技术方案 §4.3）。
class BillRepository {
  BillRepository();

  static const _pageSize = 100;

  /// 全部账单（跨群按日期倒序）。真实模式：逐群拉取第一页合并。
  Future<List<Bill>> listAll() async {
    if (AppConfig.useMock) {
      return List.of(MockStore.instance.bills)
        ..sort((a, b) => b.billDate.compareTo(a.billDate));
    }
    final groups = await _groups();
    final out = <Bill>[];
    for (final g in groups) {
      out.addAll(await listByGroup(g.id, groupName: g.name));
    }
    out.sort((a, b) => b.billDate.compareTo(a.billDate));
    return out;
  }

  /// 结算状态筛选（P12）
  Future<List<Bill>> listFiltered({
    BillSettleStatus? status,
    bool minePayer = false,
  }) async {
    if (AppConfig.useMock) {
      final me = MockStore.instance.currentUser.id;
      final all = await listAll();
      return all.where((b) {
        if (status != null && b.settleStatus != status) return false;
        if (minePayer && b.payerId != me) return false;
        return true;
      }).toList();
    }
    final all = await listAll();
    final me = await _meId();
    return all.where((b) {
      if (status != null && b.settleStatus != status) return false;
      if (minePayer && b.payerId != me) return false;
      return true;
    }).toList();
  }

  Future<List<Bill>> listByGroup(String groupId, {String groupName = ''}) async {
    if (AppConfig.useMock) {
      return List.of(MockStore.instance.billsForGroup(groupId));
    }
    final res = await ApiClient.instance.get('/groups/$groupId/bills',
        query: {'page': 1, 'pageSize': _pageSize});
    final j = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
    final list = (j['list'] is List) ? j['list'] as List : const [];
    return list
        .map((e) => parseBill(e, groupName: groupName))
        .toList();
  }

  Future<Bill> get(String id, {String groupName = ''}) async {
    if (AppConfig.useMock) {
      final b = MockStore.instance.billById(id);
      if (b == null) throw UnsupportedError('账单不存在');
      return b;
    }
    final res = await ApiClient.instance.get('/bills/$id');
    final data = (res.data is Map) ? res.data : null;
    // 服务端详情可能返回 {bill, ...} 包装
    final billData =
        (data is Map && data.containsKey('bill')) ? data['bill'] : data;
    return parseBill(billData, groupName: groupName);
  }

  Future<Bill> create({
    required String groupId,
    required String groupName,
    required String title,
    required int amountCents,
    required DateTime billDate,
    required BillCategory category,
    required String payerId,
    required String payerName,
    String location = '',
    List<BillParticipant> participants = const [],
    SplitType splitType = SplitType.even,
    List<Receipt> receipts = const [],
    bool isRegular = false,
  }) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final bill = Bill(
        id: 'b${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        groupName: groupName,
        title: title,
        amountCents: amountCents,
        billDate: billDate,
        location: location,
        category: category,
        payerId: payerId,
        payerName: payerName,
        participants: participants,
        splitType: splitType,
        receipts: receipts,
        isRegular: isRegular,
        settleStatus: billStatusOf(participants),
        createdAt: DateTime.now(),
      );
      store.bills.add(bill);
      store.refreshGroup(groupId);
      return bill;
    }
    if (participants.isEmpty) {
      // 服务端要求显式参与人；这里按全群成员均摊由服务端处理不了（服务端校验 sum），
      // 故至少把垫付人带上（服务端 even 模式自动均摊）。
      throw UnsupportedError(
          '真实模式创建账单需提供 participants（服务端事务校验分摊合计）');
    }
    final res = await ApiClient.instance.post('/bills', body: {
      'groupId': groupId,
      'title': title,
      'location': location,
      'amountCents': amountCents,
      'billDate': _dateStr(billDate),
      'category': category.name,
      'splitType': splitType.name,
      'payerId': payerId,
      'participants': [
        for (final p in participants)
          {
            'userId': p.userId,
            'shareAmountCents': p.shareAmountCents,
            'exempt': p.exempt,
          },
      ],
    });
    final data = (res.data is Map) ? res.data : null;
    final billData =
        (data is Map && data.containsKey('bill')) ? data['bill'] : data;
    return parseBill(billData, groupName: groupName);
  }

  Future<void> delete(String id) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final b = store.billById(id);
      store.bills.removeWhere((b) => b.id == id);
      if (b != null) store.refreshGroup(b.groupId);
      return;
    }
    await ApiClient.instance.delete('/bills/$id');
  }

  /// 编辑账单（标题/金额/日期/备注/垫付人/分摊方式）—— P14 编辑
  Future<void> update(String id,
      {String? title,
      int? amountCents,
      DateTime? date,
      String? location,
      String? payerId,
      String? payerName,
      SplitType? splitType,
      List<BillParticipant>? participants}) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final idx = store.bills.indexWhere((b) => b.id == id);
      if (idx < 0) return;
      final b = store.bills[idx];
      final ps = participants ?? b.participants;
      store.bills[idx] = Bill(
        id: b.id,
        groupId: b.groupId,
        groupName: b.groupName,
        title: title ?? b.title,
        amountCents: amountCents ?? b.amountCents,
        billDate: date ?? b.billDate,
        location: location ?? b.location,
        category: b.category,
        payerId: payerId ?? b.payerId,
        payerName: payerName ?? b.payerName,
        participants: ps,
        splitType: splitType ?? b.splitType,
        receipts: b.receipts,
        isRegular: b.isRegular,
        settleStatus: participants != null ? billStatusOf(ps) : b.settleStatus,
        createdAt: b.createdAt,
      );
      store.refreshGroup(b.groupId);
      return;
    }
    await ApiClient.instance.patch('/bills/$id', body: {
      'title': ?title,
      'amountCents': ?amountCents,
      'billDate': ?(date == null ? null : _dateStr(date)),
      'location': ?location,
      'payerId': ?payerId,
      'splitType': ?splitType?.name,
      'participants': ?(participants == null
          ? null
          : [
              for (final p in participants)
                {
                  'userId': p.userId,
                  'shareAmountCents': p.shareAmountCents,
                  'exempt': p.exempt,
                },
            ]),
    });
  }

  /// 替换分摊明细（P31 编辑分摊）
  Future<void> replaceParticipants(String id, List<BillParticipant> participants) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final idx = store.bills.indexWhere((b) => b.id == id);
      if (idx < 0) return;
      final b = store.bills[idx];
      store.bills[idx] = Bill(
        id: b.id,
        groupId: b.groupId,
        groupName: b.groupName,
        title: b.title,
        amountCents: b.amountCents,
        billDate: b.billDate,
        location: b.location,
        category: b.category,
        payerId: b.payerId,
        payerName: b.payerName,
        participants: participants,
        splitType: b.splitType,
        receipts: b.receipts,
        isRegular: b.isRegular,
        settleStatus: billStatusOf(participants),
        createdAt: b.createdAt,
      );
      store.refreshGroup(b.groupId);
      return;
    }
    await ApiClient.instance.patch('/bills/$id', body: {
      'participants': [
        for (final p in participants)
          {
            'userId': p.userId,
            'shareAmountCents': p.shareAmountCents,
            'exempt': p.exempt,
          },
      ],
    });
  }

  /// 一键结清：群内全部账单统一标记为「已付」。
  /// 返回被结清的账单数；真实模式为服务端单事务（幂等）。
  Future<int> settleAll(String groupId) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      var count = 0;
      for (final b in store.billsForGroup(groupId)) {
        if (b.fullySettled) continue;
        final ps =
            b.participants.map((p) => p.copyWith(paid: true)).toList();
        final idx = store.bills.indexWhere((x) => x.id == b.id);
        if (idx < 0) continue;
        store.bills[idx] = Bill(
          id: b.id,
          groupId: b.groupId,
          groupName: b.groupName,
          title: b.title,
          amountCents: b.amountCents,
          billDate: b.billDate,
          location: b.location,
          category: b.category,
          payerId: b.payerId,
          payerName: b.payerName,
          participants: ps,
          splitType: b.splitType,
          receipts: b.receipts,
          isRegular: b.isRegular,
          settleStatus: billStatusOf(ps),
          createdAt: b.createdAt,
        );
        count++;
      }
      store.refreshGroup(groupId);
      return count;
    }
    final res =
        await ApiClient.instance.post('/groups/$groupId/bills/settle-all');
    final j = (res.data as Map?)?.cast<String, dynamic>() ?? const {};
    return (j['updatedBills'] as num?)?.toInt() ?? 0;
  }

  /// 替换凭证图片：重新拍照/从相册选后替换原图（Demo 模式直接更新本地记录；
  /// 真实模式 multipart 上传后服务端更新凭证记录并清理旧图）
  Future<Receipt> replaceReceipt(
      String billId, String receiptId, String newFilePath) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final idx = store.bills.indexWhere((b) => b.id == billId);
      if (idx < 0) throw UnsupportedError('账单不存在');
      final b = store.bills[idx];
      if (!b.receipts.any((r) => r.id == receiptId)) {
        throw UnsupportedError('凭证不存在');
      }
      store.bills[idx] = Bill(
        id: b.id,
        groupId: b.groupId,
        groupName: b.groupName,
        title: b.title,
        amountCents: b.amountCents,
        billDate: b.billDate,
        location: b.location,
        category: b.category,
        payerId: b.payerId,
        payerName: b.payerName,
        participants: b.participants,
        splitType: b.splitType,
        receipts: [
          for (final r in b.receipts)
            if (r.id == receiptId)
              Receipt(id: r.id, billId: billId, url: newFilePath)
            else
              r,
        ],
        isRegular: b.isRegular,
        settleStatus: b.settleStatus,
        createdAt: b.createdAt,
      );
      return Receipt(id: receiptId, billId: billId, url: newFilePath);
    }
    final res = await ApiClient.instance.upload(
      '/bills/$billId/receipts/$receiptId/replace',
      newFilePath,
      field: 'file',
    );
    return parseReceipt(res.data);
  }

  Future<void> markPaid(String billId, String userId, bool paid) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final idx = store.bills.indexWhere((b) => b.id == billId);
      if (idx < 0) return;
      final bill = store.bills[idx];
      final ps = bill.participants.map((p) {
        if (p.userId == userId) return p.copyWith(paid: paid);
        return p;
      }).toList();
      final updated = Bill(
        id: bill.id,
        groupId: bill.groupId,
        groupName: bill.groupName,
        title: bill.title,
        amountCents: bill.amountCents,
        billDate: bill.billDate,
        location: bill.location,
        category: bill.category,
        payerId: bill.payerId,
        payerName: bill.payerName,
        participants: ps,
        splitType: bill.splitType,
        receipts: bill.receipts,
        isRegular: bill.isRegular,
        settleStatus: billStatusOf(ps),
        createdAt: bill.createdAt,
      );
      store.bills[idx] = updated;
      store.refreshGroup(bill.groupId);
      return;
    }
    await ApiClient.instance.post('/bills/$billId/mark-paid', body: {
      'userId': userId,
      'paid': paid,
    });
  }

  /// 添加凭证照片（P33/P30；真实模式为 multipart 上传）
  Future<Receipt> addReceipt(String id, Receipt receipt) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final idx = store.bills.indexWhere((b) => b.id == id);
      if (idx < 0) return receipt;
      final b = store.bills[idx];
      final real = Receipt(id: receipt.id, billId: id, url: receipt.url);
      store.bills[idx] = Bill(
        id: b.id,
        groupId: b.groupId,
        groupName: b.groupName,
        title: b.title,
        amountCents: b.amountCents,
        billDate: b.billDate,
        location: b.location,
        category: b.category,
        payerId: b.payerId,
        payerName: b.payerName,
        participants: b.participants,
        splitType: b.splitType,
        receipts: [...b.receipts, real],
        isRegular: b.isRegular,
        settleStatus: b.settleStatus,
        createdAt: b.createdAt,
      );
      return real;
    }
    // 真实模式：receipt 需携带本地文件路径/字节（由 P33 拍照后填充）
    if (receipt.url.isEmpty) {
      throw UnsupportedError('真实模式凭证上传需先拍照，或在 Demo 模式下使用');
    }
    final file = File(receipt.url);
    if (!file.existsSync()) {
      throw UnsupportedError('凭证文件不存在');
    }
    final res = await ApiClient.instance.upload(
      '/bills/$id/receipts',
      file.path,
      field: 'file',
    );
    return parseReceipt(res.data);
  }

  Future<void> remind(String billId, List<String> userIds, String message) async {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final bill = store.billById(billId);
      if (bill == null) return;
      final idx = store.bills.indexWhere((b) => b.id == billId);
      if (idx < 0) return;
      final ps = bill.participants.map((p) {
        if (userIds.contains(p.userId)) {
          return p.copyWith(remindCount: p.remindCount + 1);
        }
        return p;
      }).toList();
      store.bills[idx] = Bill(
        id: bill.id,
        groupId: bill.groupId,
        groupName: bill.groupName,
        title: bill.title,
        amountCents: bill.amountCents,
        billDate: bill.billDate,
        location: bill.location,
        category: bill.category,
        payerId: bill.payerId,
        payerName: bill.payerName,
        participants: ps,
        splitType: bill.splitType,
        receipts: bill.receipts,
        isRegular: bill.isRegular,
        settleStatus: bill.settleStatus,
        createdAt: bill.createdAt,
      );
      return;
    }
    await ApiClient.instance.post('/bills/$billId/remind', body: {
      'userIds': userIds,
      if (message.isNotEmpty) 'message': message,
    });
  }

  /// 派生结算状态（服务端也如此维护）
  static BillSettleStatus billStatusOf(List<BillParticipant> participants) {
    final relevant =
        participants.where((p) => !p.exempt && p.shareAmountCents > 0).toList();
    if (relevant.isEmpty) return BillSettleStatus.settled;
    final paidCount = relevant.where((p) => p.paid).length;
    if (paidCount == relevant.length) return BillSettleStatus.settled;
    if (paidCount > 0) return BillSettleStatus.partial;
    return BillSettleStatus.pending;
  }

  // ---- 定期账单 ----

  Future<List<RegularBill>> listRegular() async {
    if (AppConfig.useMock) {
      return List.of(MockStore.instance.regularBills);
    }
    final res = await ApiClient.instance.get('/regular-bills');
    final raw = res.data is List ? res.data as List : const [];
    final groups = await _groups();
    final names = {for (final g in groups) g.id: g.name};
    return raw.map((e) {
      final j = (e as Map).cast<String, dynamic>();
      final gid = j['groupId']?.toString() ?? '';
      return parseRegularBill(e, groupName: names[gid] ?? '');
    }).toList();
  }

  Future<void> createRegular({
    required String groupId,
    required String groupName,
    required String title,
    required int amountCents,
    required BillCategory category,
    RegularCycle cycle = RegularCycle.monthly,
    int dayOfMonth = 1,
  }) async {
    if (AppConfig.useMock) {
      MockStore.instance.regularBills.add(RegularBill(
        id: 'rb${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        groupName: groupName,
        title: title,
        amountCents: amountCents,
        category: category,
        cycle: cycle,
        dayOfMonth: dayOfMonth,
        active: true,
      ));
      return;
    }
    await ApiClient.instance.post('/regular-bills', body: {
      'groupId': groupId,
      'title': title,
      'amountCents': amountCents,
      'category': category.name,
      'splitType': 'even',
      'cycle': cycle.name,
      if (cycle == RegularCycle.monthly) 'dayOfMonth': dayOfMonth,
      'participants': <Map<String, dynamic>>[],
    });
  }

  Future<void> toggleRegular(String id, bool active) async {
    if (AppConfig.useMock) {
      final idx = MockStore.instance.regularBills.indexWhere((r) => r.id == id);
      if (idx < 0) return;
      final r = MockStore.instance.regularBills[idx];
      MockStore.instance.regularBills[idx] = RegularBill(
        id: r.id,
        groupId: r.groupId,
        groupName: r.groupName,
        title: r.title,
        amountCents: r.amountCents,
        category: r.category,
        splitType: r.splitType,
        cycle: r.cycle,
        dayOfMonth: r.dayOfMonth,
        active: active,
      );
      return;
    }
    await ApiClient.instance.patch('/regular-bills/$id', body: {'active': active});
  }

  // ---- 内部工具 ----

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<Group>> _groups() async {
    final res = await ApiClient.instance.get('/groups');
    final raw = res.data is List ? res.data as List : const [];
    return raw.map(parseGroup).toList();
  }

  Future<String> _meId() async {
    try {
      final res = await ApiClient.instance.get('/auth/me');
      return parseUser(res.data).id;
    } catch (_) {
      return '';
    }
  }
}
