import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/bill_repository.dart';
import '../data/repositories/exchange_rate_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/settlement_repository.dart';

/// 仓库组合根（Demo 模式各仓库直接读 MockStore）
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());
final groupRepositoryProvider = Provider<GroupRepository>((ref) => GroupRepository());
final billRepositoryProvider = Provider<BillRepository>((ref) => BillRepository());
final settlementRepositoryProvider =
    Provider<SettlementRepository>((ref) => SettlementRepository());
final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) => NotificationRepository());
final exchangeRateRepositoryProvider =
    Provider<ExchangeRateRepository>((ref) => ExchangeRateRepository());
