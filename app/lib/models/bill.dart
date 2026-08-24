import 'bill_participant.dart';

/// 分类枚举
enum BillCategory { food, traffic, hotel, shopping, fun, other }

/// 分摊方式枚举
enum SplitType { even, custom, ratio, exempt }

/// 结算状态派生
enum BillSettleStatus { pending, partial, settled }

/// 账单 —— 原型 §8 ★核心
class Bill {
  const Bill({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.title,
    required this.amountCents,
    required this.billDate,
    this.location = '',
    required this.category,
    required this.payerId,
    required this.payerName,
    required this.participants,
    this.splitType = SplitType.even,
    this.receipts = const [],
    this.isRegular = false,
    required this.settleStatus,
    this.createdAt,
  });

  final String id;
  final String groupId;
  final String groupName;
  final String title;
  final int amountCents;
  final DateTime billDate;
  final String location;
  final BillCategory category;

  /// 垫付人
  final String payerId;
  final String payerName;

  final List<BillParticipant> participants;
  final SplitType splitType;
  final List<Receipt> receipts;
  final bool isRegular;
  final BillSettleStatus settleStatus;
  final DateTime? createdAt;

  int get paidCents => participants
      .where((p) => p.paid)
      .fold(0, (sum, p) => sum + p.shareAmountCents);

  bool get fullySettled => settleStatus == BillSettleStatus.settled;

  bool get hasUnpaid => !fullySettled;

  factory Bill.fromJson(Map<String, dynamic> json) => Bill(
        id: json['id'] as String? ?? '',
        groupId: json['groupId'] as String? ?? '',
        groupName: json['groupName'] as String? ?? '',
        title: json['title'] as String? ?? '',
        amountCents: json['amountCents'] as int? ?? 0,
        billDate: DateTime.tryParse(json['billDate'] as String? ?? '') ??
            DateTime.now(),
        location: json['location'] as String? ?? '',
        category: BillCategory.values
            .firstWhere((e) => e.name == json['category'],
                orElse: () => BillCategory.other),
        payerId: json['payerId'] as String? ?? '',
        payerName: json['payerName'] as String? ?? '',
        participants: ((json['participants'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => BillParticipant.fromJson(e.cast<String, dynamic>()))
            .toList(),
        splitType: SplitType.values
            .firstWhere((e) => e.name == json['splitType'],
                orElse: () => SplitType.even),
        receipts: ((json['receipts'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Receipt.fromJson(e.cast<String, dynamic>()))
            .toList(),
        isRegular: json['isRegular'] as bool? ?? false,
        settleStatus: BillSettleStatus.values
            .firstWhere((e) => e.name == json['settleStatus'],
                orElse: () => BillSettleStatus.pending),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}
