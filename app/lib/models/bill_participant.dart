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
  const Receipt({
    required this.id,
    required this.billId,
    required this.url,
    this.uploadId,
    this.amountCents,
    this.confidence,
    this.currency,
    this.ocrStatus = 'pending',
  });

  final String id;
  final String billId;
  final String url;

  /// 草稿预上传暂存 id（记账页拍/选后经 POST /receipts/pre-upload 获取，提交账单时绑定）
  final String? uploadId;

  /// OCR 识别金额（分）；null = 未识别/识别不到
  final int? amountCents;

  /// OCR 置信度 0~1
  final double? confidence;

  /// OCR 币种（CNY/USD/...；非 CNY 前端提示）
  final String? currency;

  /// pending | processing | success | failed
  final String ocrStatus;

  factory Receipt.fromJson(Map<String, dynamic> json) => Receipt(
        id: json['id'] as String? ?? '',
        billId: json['billId'] as String? ?? '',
        url: json['url'] as String? ?? '',
        uploadId: json['uploadId'] as String?,
        amountCents: json['amountCents'] as int?,
        confidence: (json['confidence'] as num?)?.toDouble(),
        currency: json['currency'] as String?,
        ocrStatus: json['ocrStatus'] as String? ?? 'pending',
      );
}

/// 草稿预上传返回：uploadId（提交账单时绑定）+ 服务端 URL
class ReceiptUploadInfo {
  const ReceiptUploadInfo({required this.uploadId, required this.url});
  final String uploadId;
  final String url;
}
