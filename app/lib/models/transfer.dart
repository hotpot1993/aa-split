/// 一笔转账（结算方案成员）
class Transfer {
  const Transfer({
    required this.fromUserId,
    required this.fromName,
    required this.toUserId,
    required this.toName,
    required this.amountCents,
    this.billIds = const [],
  });

  final String fromUserId;
  final String fromName;
  final String toUserId;
  final String toName;
  final int amountCents;
  final List<String> billIds;

  factory Transfer.fromJson(Map<String, dynamic> json) => Transfer(
        fromUserId: json['fromUserId'] as String? ?? '',
        fromName: json['fromName'] as String? ?? '',
        toUserId: json['toUserId'] as String? ?? '',
        toName: json['toName'] as String? ?? '',
        amountCents: json['amountCents'] as int? ?? 0,
        billIds: ((json['billIds'] as List?) ?? const []).cast<String>(),
      );
}

/// 结算方案（最少转账笔数）
class SettlementPlan {
  const SettlementPlan({
    required this.transferCount,
    required this.transfers,
  });

  final int transferCount;
  final List<Transfer> transfers;

  bool get settled => transfers.isEmpty;

  factory SettlementPlan.fromJson(Map<String, dynamic> json) => SettlementPlan(
        transferCount: json['transferCount'] as int? ?? 0,
        transfers: ((json['transfers'] as List?) ?? const [])
            .map((e) => Transfer.fromJson((e as Map).cast<String, dynamic>()))
            .toList(),
      );
}
