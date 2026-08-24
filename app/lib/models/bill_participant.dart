/// 账单参与人（分摊明细）
class BillParticipant {
  const BillParticipant({
    required this.userId,
    required this.nickname,
    this.avatarUrl = '🐼',
    required this.shareAmountCents,
    this.paid = false,
    this.exempt = false,
    this.remindCount = 0,
  });

  final String userId;
  final String nickname;
  final String avatarUrl;
  final int shareAmountCents;
  final bool paid;
  final bool exempt;
  final int remindCount;

  factory BillParticipant.fromJson(Map<String, dynamic> json) =>
      BillParticipant(
        userId: json['userId'] as String? ?? '',
        nickname: json['nickname'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String? ?? '🐼',
        shareAmountCents: json['shareAmountCents'] as int? ?? 0,
        paid: json['paid'] as bool? ?? false,
        exempt: json['exempt'] as bool? ?? false,
        remindCount: json['remindCount'] as int? ?? 0,
      );

  BillParticipant copyWith({
    bool? paid,
    int? remindCount,
    int? shareAmountCents,
  }) =>
      BillParticipant(
        userId: userId,
        nickname: nickname,
        avatarUrl: avatarUrl,
        shareAmountCents: shareAmountCents ?? this.shareAmountCents,
        paid: paid ?? this.paid,
        exempt: exempt,
        remindCount: remindCount ?? this.remindCount,
      );
}

/// 凭证照片
class Receipt {
  const Receipt({required this.id, required this.billId, required this.url});

  final String id;
  final String billId;
  final String url;

  factory Receipt.fromJson(Map<String, dynamic> json) => Receipt(
        id: json['id'] as String? ?? '',
        billId: json['billId'] as String? ?? '',
        url: json['url'] as String? ?? '',
      );
}
