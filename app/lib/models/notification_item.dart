/// 通知类型
enum NotifyType { newBill, remind, invite, regular, settled, member }

/// 消息/通知
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
    this.refType = '',
    this.refId = '',
  });

  final String id;
  final NotifyType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;
  final String refType;
  final String refId;

  /// 归入"今天"还是"更早"
  bool get isToday {
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        id: json['id'] as String? ?? '',
        type: NotifyType.values
            .firstWhere((e) => e.name == json['type'],
                orElse: () => NotifyType.newBill),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        isRead: json['isRead'] as bool? ?? false,
        refType: json['refType'] as String? ?? '',
        refId: json['refId'] as String? ?? '',
      );

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        type: type,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        refType: refType,
        refId: refId,
      );
}
