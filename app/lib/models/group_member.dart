/// 群组成员（含在本群的净额）
///
/// 成员有两类（见 CONTEXT.md）：
/// - 注册成员：拥有账户、可自己登录，`isPlaceholder == false`
/// - 非注册成员：只在本群内存在、只有名称，由群主代为加入，
///   由服务端的一个「占位账号」承载，`isPlaceholder == true`；
///   它没有可用账户名（服务端一律返回空串），也不可登录、不接收通知
class GroupMember {
  const GroupMember({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.accountName,
    this.avatarUrl = '🐼',
    required this.isOwner,
    this.status = 'active',
    this.joinedAt,
    this.netBalanceCents = 0,
    this.isPlaceholder = false,
  });

  final String id;
  final String userId;
  final String nickname;
  final String accountName;
  final String avatarUrl;
  final bool isOwner;
  final String status;
  final DateTime? joinedAt;

  /// 本群净额（正=应收，负=应付）
  final int netBalanceCents;

  /// 非注册成员（占位账号）：不显示 @账户名，可改名/被认领
  final bool isPlaceholder;

  /// 在群（active）；false = 已退出（left），仅历史账单仍保留
  bool get isActive => status == 'active';

  /// 显示名兜底：占位账号只有名称，注册成员昵称缺失时退回账户名
  String get displayName =>
      nickname.isNotEmpty ? nickname : (isPlaceholder ? '未注册成员' : accountName);

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        id: json['id'] as String? ?? '',
        userId: json['userId'] as String? ?? '',
        nickname: json['nickname'] as String? ?? '',
        accountName: json['accountName'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String? ?? '🐼',
        isOwner: json['isOwner'] as bool? ?? false,
        status: json['status'] as String? ?? 'active',
        joinedAt: json['joinedAt'] != null
            ? DateTime.tryParse(json['joinedAt'] as String)
            : null,
        netBalanceCents: json['netBalanceCents'] as int? ?? 0,
        isPlaceholder: json['isPlaceholder'] as bool? ?? false,
      );

  GroupMember copyWith({
    String? nickname,
    String? accountName,
    String? avatarUrl,
    bool? isOwner,
    String? status,
    int? netBalanceCents,
    bool? isPlaceholder,
  }) =>
      GroupMember(
        id: id,
        userId: userId,
        nickname: nickname ?? this.nickname,
        accountName: accountName ?? this.accountName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isOwner: isOwner ?? this.isOwner,
        status: status ?? this.status,
        joinedAt: joinedAt,
        netBalanceCents: netBalanceCents ?? this.netBalanceCents,
        isPlaceholder: isPlaceholder ?? this.isPlaceholder,
      );
}

/// 认领前预览（P24 二次确认文案：将合并 N 笔账单、M 条历史结算）
class ClaimPreview {
  const ClaimPreview({
    required this.billCount,
    required this.settlementCount,
    this.placeholderName = '',
    this.targetName = '',
    this.targetInGroup = false,
  });

  final int billCount;
  final int settlementCount;
  final String placeholderName;
  final String targetName;

  /// 目标账号是否已在群内（false → 认领后自动入群）
  final bool targetInGroup;
}

/// 群成员统计（供成员管理/P24 使用）
class GroupMemberStats {
  const GroupMemberStats({
    required this.member,
    this.paidInBillCount = 0,
    this.remindCount = 0,
  });

  final GroupMember member;
  final int paidInBillCount;
  final int remindCount;
}
