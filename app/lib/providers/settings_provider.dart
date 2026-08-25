import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 主题已固定为浅色（与 docs/ui-demo/index.html 一致），不再提供深色模式。

/// 通知偏好（P41 提醒设置）
class NotifyPrefs {
  const NotifyPrefs({
    this.newBill = true,
    this.remind = true,
    this.regular = true,
    this.mention = true,
    this.dndEnabled = true,
    this.dndStart = '22:00',
    this.dndEnd = '08:00',
    this.remindDefaultText =
        '嗨～[昵称]，上一笔AA（[账单标题]）你还没付哦，[金额]元，去收款卡里收款啦 🙏',
  });

  final bool newBill;
  final bool remind;
  final bool regular;
  final bool mention;
  final bool dndEnabled;
  final String dndStart;
  final String dndEnd;
  final String remindDefaultText;

  NotifyPrefs copyWith({
    bool? newBill,
    bool? remind,
    bool? regular,
    bool? mention,
    bool? dndEnabled,
    String? remindDefaultText,
  }) =>
      NotifyPrefs(
        newBill: newBill ?? this.newBill,
        remind: remind ?? this.remind,
        regular: regular ?? this.regular,
        mention: mention ?? this.mention,
        dndEnabled: dndEnabled ?? this.dndEnabled,
        dndStart: dndStart,
        dndEnd: dndEnd,
        remindDefaultText: remindDefaultText ?? this.remindDefaultText,
      );
}

final notifyPrefsProvider =
    NotifierProvider<NotifyPrefsController, NotifyPrefs>(NotifyPrefsController.new);

class NotifyPrefsController extends Notifier<NotifyPrefs> {
  @override
  NotifyPrefs build() => const NotifyPrefs();

  void set({bool? newBill, bool? remind, bool? regular, bool? mention, bool? dndEnabled}) {
    state = state.copyWith(
      newBill: newBill,
      remind: remind,
      regular: regular,
      mention: mention,
      dndEnabled: dndEnabled,
    );
  }

  void setText(String value) {
    state = state.copyWith(remindDefaultText: value);
  }
}
