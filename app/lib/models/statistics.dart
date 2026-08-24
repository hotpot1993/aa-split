import 'bill.dart';

/// 统计页数据（P13）
class CategoryStat {
  const CategoryStat({required this.category, required this.amountCents});

  final BillCategory category;
  final int amountCents;
}

class MonthStat {
  const MonthStat({required this.label, required this.amountCents});

  final String label;
  final int amountCents;
}

class Statistics {
  const Statistics({
    this.totalCents = 0,
    this.billCount = 0,
    this.categoryStats = const [],
    this.monthlyTrend = const [],
    this.topBillCents = const [],
  });

  final int totalCents;
  final int billCount;
  final List<CategoryStat> categoryStats;
  final List<MonthStat> monthlyTrend;

  /// 我的前几笔大额（金额，分）
  final List<int> topBillCents;
}
