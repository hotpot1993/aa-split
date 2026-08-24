/// 群组默认分摊方式
enum GroupDefaultSplit { even, custom, ratio }

/// 群组 —— 原型 §8
class Group {
  const Group({
    required this.id,
    required this.name,
    this.avatar = '🐼',
    this.intro = '',
    required this.ownerId,
    this.defaultSplit = GroupDefaultSplit.even,
    this.inviteCode = '',
    this.memberCount = 0,
    this.pendingBillCount = 0,
    this.recentBillTitle = '',
    this.recentBillDate,
    this.totalCents = 0,
  });

  final String id;
  final String name;
  final String avatar;
  final String intro;
  final String ownerId;
  final GroupDefaultSplit defaultSplit;
  final String inviteCode;

  /// 成员数（冗余，便于列表展示）
  final int memberCount;

  /// 未结清账单数（冗余，列表角标）
  final int pendingBillCount;

  final String recentBillTitle;
  final DateTime? recentBillDate;
  final int totalCents;

  factory Group.fromJson(Map<String, dynamic> json) => Group(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        avatar: json['avatar'] as String? ?? '🐼',
        intro: json['intro'] as String? ?? '',
        ownerId: json['ownerId'] as String? ?? '',
        defaultSplit: GroupDefaultSplit.values
                .firstWhere((e) => e.name == json['defaultSplit'],
                    orElse: () => GroupDefaultSplit.even),
        inviteCode: json['inviteCode'] as String? ?? '',
        memberCount: json['memberCount'] as int? ?? 0,
        pendingBillCount: json['pendingBillCount'] as int? ?? 0,
        recentBillTitle: json['recentBillTitle'] as String? ?? '',
        recentBillDate: json['recentBillDate'] != null
            ? DateTime.tryParse(json['recentBillDate'] as String)
            : null,
        totalCents: json['totalCents'] as int? ?? 0,
      );

  Group copyWith({
    String? name,
    String? avatar,
    String? intro,
    int? memberCount,
    int? pendingBillCount,
    int? totalCents,
    String? recentBillTitle,
    DateTime? recentBillDate,
  }) =>
      Group(
        id: id,
        name: name ?? this.name,
        avatar: avatar ?? this.avatar,
        intro: intro ?? this.intro,
        ownerId: ownerId,
        defaultSplit: defaultSplit,
        inviteCode: inviteCode,
        memberCount: memberCount ?? this.memberCount,
        pendingBillCount: pendingBillCount ?? this.pendingBillCount,
        recentBillTitle: recentBillTitle ?? this.recentBillTitle,
        recentBillDate: recentBillDate ?? this.recentBillDate,
        totalCents: totalCents ?? this.totalCents,
      );
}
