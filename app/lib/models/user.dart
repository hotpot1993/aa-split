/// 用户（账户）—— 原型 §8
class User {
  const User({
    required this.id,
    required this.accountName,
    required this.nickname,
    this.avatarUrl = '🐼',
    this.bio = '',
    this.securityQuestion = '',
    this.createdAt = 0,
  });

  final String id;
  final String accountName;
  final String nickname;
  final String avatarUrl;
  final String bio;
  final String securityQuestion;
  final int createdAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String? ?? '',
        accountName: json['accountName'] as String? ?? '',
        nickname: json['nickname'] as String? ?? '',
        avatarUrl: json['avatarUrl'] as String? ?? '🐼',
        bio: json['bio'] as String? ?? '',
        securityQuestion: json['securityQuestion'] as String? ?? '',
        createdAt: json['createdAt'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'accountName': accountName,
        'nickname': nickname,
        'avatarUrl': avatarUrl,
        'bio': bio,
        'securityQuestion': securityQuestion,
        'createdAt': createdAt,
      };

  User copyWith({String? nickname, String? avatarUrl, String? bio, String? securityQuestion}) => User(
        id: id,
        accountName: accountName,
        nickname: nickname ?? this.nickname,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        securityQuestion: securityQuestion ?? this.securityQuestion,
        createdAt: createdAt,
      );
}
