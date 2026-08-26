/// 群组成员（含在本群的净额）
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
      );

  GroupMember copyWith({
    String? nickname,
    String? accountName,
    String? avatarUrl,
    bool? isOwner,
    String? status,
    int? netBalanceCents,
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
      );
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
