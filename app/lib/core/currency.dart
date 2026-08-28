/// 旅行常用货币（「记一笔」可选，默认人民币 CNY）
///
/// 业务规则：用户以外币记账 → 确认账单时按当日汇率自动换算成人民币（分）入账；
/// [demoRate] 为 Demo 模式下的内置参考汇率（1 单位外币 = 多少人民币）。
class TravelCurrency {
  const TravelCurrency(this.code, this.name, this.symbol, this.demoRate);

  /// ISO 4217 代码
  final String code;

  /// 中文名（下拉展示）
  final String name;

  /// 金额输入框前缀符号
  final String symbol;

  /// Demo 参考汇率：1 单位外币 ≈ 多少人民币
  final double demoRate;

  bool get isCny => code == 'CNY';
}

/// 旅行常用货币表（CNY 恒为第一项 = 默认）
const List<TravelCurrency> travelCurrencies = [
  TravelCurrency('CNY', '人民币', '¥', 1),
  TravelCurrency('USD', '美元', r'$', 7.25),
  TravelCurrency('EUR', '欧元', '€', 7.85),
  TravelCurrency('JPY', '日元', '¥', 0.048),
  TravelCurrency('GBP', '英镑', '£', 9.2),
  TravelCurrency('HKD', '港币', 'HK\$', 0.93),
  TravelCurrency('THB', '泰铢', '฿', 0.21),
  TravelCurrency('KRW', '韩元', '₩', 0.0053),
  TravelCurrency('SGD', '新加坡元', 'S\$', 5.4),
  TravelCurrency('AUD', '澳元', 'A\$', 4.8),
  TravelCurrency('CAD', '加元', 'C\$', 5.3),
  TravelCurrency('MYR', '马来西亚林吉特', 'RM', 1.55),
];

/// Demo 参考汇率：1 单位 [code] 外币 = 返回多少人民币（未知币种返回 CNY=1）
double demoRateOf(String code) {
  for (final c in travelCurrencies) {
    if (c.code == code) return c.demoRate;
  }
  return 1;
}

/// 按 ISO 代码匹配旅行货币；空/未知返回 null。
/// 用于「记一笔」OCR 识别成功后自动选中识别出的币种（OCR 币种不在可选表时忽略）。
TravelCurrency? matchTravelCurrency(String? code) {
  if (code == null || code.isEmpty) return null;
  for (final c in travelCurrencies) {
    if (c.code == code) return c;
  }
  return null;
}
