import 'package:intl/intl.dart';

import '../../models/bill.dart';
import '../../models/group.dart';

/// 金额（分 → ¥xx.xx）与日期文案工具
abstract final class Fmt {
  /// 分 → "¥xx.xx"（不含符号极性）
  static String yuan(int cents) {
    final negative = cents < 0;
    final abs = cents.abs();
    final s = '¥${(abs ~/ 100)}.${(abs % 100).toString().padLeft(2, '0')}';
    return negative ? '-$s' : s;
  }

  /// 分 → 整数元（用于统计标题）
  static String yuanNoSymbol(int cents) {
    final abs = cents.abs();
    return (abs / 100).toStringAsFixed(2);
  }

  static String date(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static String dateShort(DateTime d) => DateFormat('MM-dd').format(d);

  /// 相对时间：刚刚 / x分钟前 / x小时前 / 昨天 / 更早
  static String relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays == 1) return '昨天';
    return '${diff.inDays}天前';
  }

  /// 今晨问候
  static String greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return '夜深啦';
    if (h < 11) return '早上好';
    if (h < 14) return '中午好';
    if (h < 18) return '下午好';
    return '晚上好';
  }
}

/// 分类 → emoji + 文案
abstract final class Cat {
  static String emoji(BillCategory c) => switch (c) {
        BillCategory.food => '🍜',
        BillCategory.traffic => '🚕',
        BillCategory.hotel => '🏠',
        BillCategory.shopping => '🛍',
        BillCategory.fun => '🎮',
        BillCategory.other => '🧾',
      };

  static String label(BillCategory c) => switch (c) {
        BillCategory.food => '餐饮',
        BillCategory.traffic => '交通',
        BillCategory.hotel => '住宿',
        BillCategory.shopping => '购物',
        BillCategory.fun => '娱乐',
        BillCategory.other => '其他',
      };

  static const all = BillCategory.values;
}

/// 分摊方式 → 文案
abstract final class SplitText {
  static String label(SplitType s) => switch (s) {
        SplitType.even => '均摊',
        SplitType.custom => '自定义',
        SplitType.ratio => '按比例',
        SplitType.exempt => '免分摊',
      };

  /// 结算状态 → 印章文案
  static String settleText(BillSettleStatus s) => switch (s) {
        BillSettleStatus.pending => '待结算',
        BillSettleStatus.partial => '部分已付',
        BillSettleStatus.settled => '已结清',
      };
}

/// 群组默认分摊方式 → 文案
abstract final class GroupSplit {
  static String label(GroupDefaultSplit s) => switch (s) {
        GroupDefaultSplit.even => '均摊',
        GroupDefaultSplit.custom => '自定义',
        GroupDefaultSplit.ratio => '按比例',
      };
}
