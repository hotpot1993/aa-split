import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aa_design/aa_design.dart';

/// 主题已固定为浅色（与 docs/ui-demo/index.html 一致），不再提供深色模式。

/// 字体风格偏好读写（设置页「字体风格」切换）。
/// 值持久化到 SharedPreferences，App 重启后保持；启动时由 main() 调用 [init] 恢复。
abstract final class FontStyleStore {
  static const _kFontStyle = 'aa.fontStyle';

  /// 从本地存储恢复字体风格并立即生效（未存过 → 手绘风格）。
  /// 在 runApp 之前调用，避免启动先显示默认风格再跳变。
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_kFontStyle);
      final style = AaFontStyle.values.firstWhere(
        (s) => s.name == name,
        orElse: () => AAFonts.currentStyle,
      );
      AAFonts.useStyle(style);
    } catch (_) {
      // 读失败不阻断启动：保持默认（手绘）风格
    }
  }

  static Future<void> save(AaFontStyle style) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFontStyle, style.name);
    } catch (_) {
      // 写失败忽略：本次会话内仍生效，下次启动回到上次保存值
    }
  }
}

/// 当前字体风格（手绘风格 / 标准风格），见 [AaFontStyle]。
final fontStyleProvider =
    NotifierProvider<FontStyleController, AaFontStyle>(FontStyleController.new);

class FontStyleController extends Notifier<AaFontStyle> {
  @override
  AaFontStyle build() => AAFonts.currentStyle;

  /// 切换字体风格：立即生效（全局 AaFonts + 主题重建）+ 持久化。
  Future<void> setStyle(AaFontStyle style) async {
    if (state == style) return;
    AAFonts.useStyle(style);
    state = style;
    await FontStyleStore.save(style);
  }
}

/// 通知偏好（P41 提醒设置）
class NotifyPrefs {
  const NotifyPrefs({
    this.remind = true,
    this.regular = true,
    this.mention = true,
    this.dndEnabled = true,
    this.dndStart = '22:00',
    this.dndEnd = '08:00',
    this.remindDefaultText =
        '嗨～[昵称]，上一笔AA（[账单标题]）你还没付哦，[金额]元，去收款卡里收款啦 🙏',
  });

  final bool remind;
  final bool regular;
  final bool mention;
  final bool dndEnabled;
  final String dndStart;
  final String dndEnd;
  final String remindDefaultText;

  NotifyPrefs copyWith({
    bool? remind,
    bool? regular,
    bool? mention,
    bool? dndEnabled,
    String? remindDefaultText,
  }) =>
      NotifyPrefs(
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

  void set({bool? remind, bool? regular, bool? mention, bool? dndEnabled}) {
    state = state.copyWith(
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
