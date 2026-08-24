import 'bill.dart';

/// 定期账单周期
enum RegularCycle { weekly, biweekly, monthly }

/// 定期账单（P34）
class RegularBill {
  const RegularBill({
    required this.id,
    required this.groupId,
    required this.groupName,
    required this.title,
    required this.amountCents,
    required this.category,
    this.splitType = SplitType.even,
    required this.cycle,
    this.dayOfMonth = 1,
    this.active = true,
  });

  final String id;
  final String groupId;
  final String groupName;
  final String title;
  final int amountCents;
  final BillCategory category;
  final SplitType splitType;
  final RegularCycle cycle;

  /// 每月几号（monthly 生效，1-31）
  final int dayOfMonth;
  final bool active;

  factory RegularBill.fromJson(Map<String, dynamic> json) => RegularBill(
        id: json['id'] as String? ?? '',
        groupId: json['groupId'] as String? ?? '',
        groupName: json['groupName'] as String? ?? '',
        title: json['title'] as String? ?? '',
        amountCents: json['amountCents'] as int? ?? 0,
        category: BillCategory.values
            .firstWhere((e) => e.name == json['category'],
                orElse: () => BillCategory.other),
        splitType: SplitType.values
            .firstWhere((e) => e.name == json['splitType'],
                orElse: () => SplitType.even),
        cycle: RegularCycle.values
            .firstWhere((e) => e.name == json['cycle'],
                orElse: () => RegularCycle.monthly),
        dayOfMonth: json['dayOfMonth'] as int? ?? 1,
        active: json['active'] as bool? ?? true,
      );
}
