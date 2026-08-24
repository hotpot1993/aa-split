import '../../core/config.dart';
import '../../models/bill.dart';
import '../../models/bill_participant.dart';
import '../../models/regular_bill.dart';
import '../mock/mock_store.dart';

/// 账单仓库（Demo 模式走 MockStore）
///
/// 非 Demo 模式：应改为 async 并调用 ApiClient 的 `/bills` 接口（技术方案 §4.3）。
class BillRepository {
  BillRepository();

  List<Bill> listAll() {
    if (AppConfig.useMock) {
      return List.of(MockStore.instance.bills)
        ..sort((a, b) => b.billDate.compareTo(a.billDate));
    }
    throw UnsupportedError('useMock=false：BillRepository.listAll 需 async + ApiClient');
  }

  /// 结算状态筛选（P12）
  List<Bill> listFiltered({BillSettleStatus? status, bool minePayer = false}) {
    if (AppConfig.useMock) {
      final me = MockStore.instance.currentUser.id;
      return listAll().where((b) {
        if (status != null && b.settleStatus != status) return false;
        if (minePayer && b.payerId != me) return false;
        return true;
      }).toList();
    }
    throw UnsupportedError('useMock=false：BillRepository.listFiltered 需 async + ApiClient');
  }

  List<Bill> listByGroup(String groupId) {
    if (AppConfig.useMock) {
      return List.of(MockStore.instance.billsForGroup(groupId));
    }
    throw UnsupportedError('useMock=false：BillRepository.listByGroup 需 async + ApiClient');
  }

  Bill get(String id) {
    if (AppConfig.useMock) {
      final b = MockStore.instance.billById(id);
      if (b == null) throw UnsupportedError('账单不存在');
      return b;
    }
    throw UnsupportedError('useMock=false：BillRepository.get 需 async + ApiClient');
  }

  Bill create({
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
  }) {
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
    throw UnsupportedError('useMock=false：BillRepository.create 需 async + ApiClient');
  }

  void delete(String id) {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final b = store.billById(id);
      store.bills.removeWhere((b) => b.id == id);
      if (b != null) store.refreshGroup(b.groupId);
      return;
    }
    throw UnsupportedError('useMock=false：BillRepository.delete 需 async + ApiClient');
  }

  /// 编辑账单（标题/金额/日期/备注）—— P14 编辑
  void update(String id, {String? title, int? amountCents, DateTime? date, String? location}) {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final idx = store.bills.indexWhere((b) => b.id == id);
      if (idx < 0) return;
      final b = store.bills[idx];
      store.bills[idx] = Bill(
        id: b.id,
        groupId: b.groupId,
        groupName: b.groupName,
        title: title ?? b.title,
        amountCents: amountCents ?? b.amountCents,
        billDate: date ?? b.billDate,
        location: location ?? b.location,
        category: b.category,
        payerId: b.payerId,
        payerName: b.payerName,
        participants: b.participants,
        splitType: b.splitType,
        receipts: b.receipts,
        isRegular: b.isRegular,
        settleStatus: b.settleStatus,
        createdAt: b.createdAt,
      );
      store.refreshGroup(b.groupId);
      return;
    }
    throw UnsupportedError('useMock=false：BillRepository.update 需 async + ApiClient');
  }

  /// 替换分摊明细（P31 编辑分摊）
  void replaceParticipants(String id, List<BillParticipant> participants) {
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
    throw UnsupportedError('useMock=false：BillRepository.replaceParticipants 需 async + ApiClient');
  }

  void markPaid(String billId, String userId, bool paid) {
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
    throw UnsupportedError('useMock=false：BillRepository.markPaid 需 async + ApiClient');
  }

  /// 添加凭证照片（P33/P30）
  void addReceipt(String id, Receipt receipt) {
    if (AppConfig.useMock) {
      final store = MockStore.instance;
      final idx = store.bills.indexWhere((b) => b.id == id);
      if (idx < 0) return;
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
      return;
    }
    throw UnsupportedError('useMock=false：BillRepository.addReceipt 需 async + ApiClient');
  }

  void remind(String billId, List<String> userIds, String message) {
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
    throw UnsupportedError('useMock=false：BillRepository.remind 需 async + ApiClient');
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

  List<RegularBill> listRegular() {
    if (AppConfig.useMock) return List.of(MockStore.instance.regularBills);
    throw UnsupportedError('useMock=false：listRegular 需 async + ApiClient');
  }

  void createRegular({
    required String groupId,
    required String groupName,
    required String title,
    required int amountCents,
    required BillCategory category,
    RegularCycle cycle = RegularCycle.monthly,
    int dayOfMonth = 1,
  }) {
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
    throw UnsupportedError('useMock=false：createRegular 需 async + ApiClient');
  }

  void toggleRegular(String id, bool active) {
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
    throw UnsupportedError('useMock=false：toggleRegular 需 async + ApiClient');
  }
}
