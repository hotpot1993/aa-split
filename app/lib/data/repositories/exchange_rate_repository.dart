import 'package:dio/dio.dart';

import '../../core/config.dart';
import '../../core/currency.dart';

/// 汇率查询结果
class RateResult {
  const RateResult(this.rate, {this.isReference = false});

  /// 1 单位外币 = 多少人民币
  final double rate;

  /// true = 网络不可用时回退的内置参考汇率（非实时）
  final bool isReference;
}

/// 汇率仓库：提供「1 单位外币 → 人民币」今日汇率。
///
/// - 默认人民币恒为 1；
/// - Demo 模式：内置参考汇率（与 [travelCurrencies] 一致）；
/// - 真实模式：拉取公开汇率 API（按日缓存），失败回退内置参考汇率。
class ExchangeRateRepository {
  ExchangeRateRepository();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  /// 每日缓存：code -> (yyyy-MM-dd, RateResult)
  static final Map<String, (String, RateResult)> _cache = {};

  static String _today() =>
      DateTime.now().toIso8601String().substring(0, 10);

  /// 今日汇率（foreign → CNY）。CNY 恒为 1；结果按天缓存（幂等）。
  Future<RateResult> rate(String code) async {
    if (code == 'CNY') return const RateResult(1);
    final today = _today();
    final cached = _cache[code];
    if (cached != null && cached.$1 == today) return cached.$2;
    final result = AppConfig.useMock ? _reference(code) : await _online(code);
    _cache[code] = (today, result);
    return result;
  }

  RateResult _reference(String code) =>
      RateResult(demoRateOf(code), isReference: true);

  /// 公开汇率 API（USD 基准）：1 外币 = CNY/该外币的单位数
  Future<RateResult> _online(String code) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://open.er-api.com/v6/latest/USD',
      );
      final j = res.data ?? const {};
      final rates = (j['rates'] as Map?)?.cast<String, dynamic>() ?? const {};
      final cny = _num(rates['CNY']);
      final foreign = _num(rates[code]);
      if (cny == null || foreign == null || foreign <= 0) {
        return _reference(code);
      }
      return RateResult(cny / foreign);
    } catch (_) {
      // 网络/解析失败：回退内置参考汇率（UI 会标注「参考汇率」）
      return _reference(code);
    }
  }

  double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
