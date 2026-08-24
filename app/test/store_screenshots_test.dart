// 商店截图生成器（黄金文件渲染，非普通测试）
// 运行：flutter test --update-goldens test/store_screenshots_test.dart
// 产出：test/goldens/store_screenshots/*.png（1080x1920），随后由脚本拷贝到 docs/store/screenshots/
//
// 注意：
// - 使用 Demo 模式（useMock 默认 true），数据来自 mock_store（团子酱 + 3 群演示数据）
// - 字体从磁盘直接加载（ZCOOLKuaiLe/LongCang/Segoe UI Emoji），保证截图与真机一致
// - 在 CI/普通 `flutter test` 中也会执行，但只有 --update-goldens 时生成新图；
//   无 --update-goldens 且文件存在时按黄金比对（检测页面回归）
import 'dart:io';

import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aa_split_app/screens/add/add_bill_screen.dart';
import 'package:aa_split_app/screens/groups/groups_screen.dart';
import 'package:aa_split_app/screens/groups/settlement_screen.dart';
import 'package:aa_split_app/screens/home/bill_detail_screen.dart';
import 'package:aa_split_app/screens/home/home_screen.dart';
import 'package:aa_split_app/screens/home/stats_screen.dart';
import 'package:aa_split_app/screens/messages/messages_screen.dart';
import 'package:aa_split_app/screens/profile/profile_screen.dart';

const _shotKey = ValueKey('store-shot');

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> _loadAllFonts() async {
  const base = 'packages/aa_design/assets/fonts';
  // 默认 family 'Roboto'（测试环境默认）→ ZCOOL 快乐体：覆盖无 fontFamily 的正文
  await _loadFont('Roboto', ['$base/ZCOOLKuaiLe-Regular.ttf']);
  // 显式 family（aa_design 主题使用）
  await _loadFont('ZCOOLKuaiLe', ['$base/ZCOOLKuaiLe-Regular.ttf']);
  await _loadFont('LongCang', ['$base/LongCang-Regular.ttf']);
  // emoji 家族（系统 emoji 字体），通过 fontFamilyFallback 兜底头像/分类图标
  await _loadFont('Emoji', [r'C:\Windows\Fonts\seguiemj.ttf']);
}

/// 商店截图专用主题：与 App 一致，仅追加 emoji 字体兜底
ThemeData _shotTheme() {
  final base = buildAaTheme();
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: const ['Emoji']),
  );
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _shotTheme(),
        home: RepaintBoundary(key: _shotKey, child: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await expectLater(
    find.byKey(_shotKey),
    matchesGoldenFile('store_screenshots/$name'),
  );
}

void main() {
  setUpAll(_loadAllFonts);

  testWidgets('01 首页总览', (t) async {
    await _pump(t, const HomeScreen());
    await _shot(t, '01_home.png');
  });

  testWidgets('02 群组列表', (t) async {
    await _pump(t, const GroupsScreen());
    await _shot(t, '02_groups.png');
  });

  testWidgets('03 记一笔', (t) async {
    await _pump(t, const AddBillScreen());
    await _shot(t, '03_add_bill.png');
  });

  testWidgets('04 账单详情', (t) async {
    await _pump(t, const BillDetailScreen(billId: 'b1'));
    await _shot(t, '04_bill_detail.png');
  });

  testWidgets('05 结算方案', (t) async {
    await _pump(t, const SettlementScreen(groupId: 'g1'));
    await _shot(t, '05_settlement.png');
  });

  testWidgets('06 消息中心', (t) async {
    await _pump(t, const MessagesScreen());
    await _shot(t, '06_messages.png');
  });

  testWidgets('07 收支统计', (t) async {
    await _pump(t, const StatsScreen());
    await _shot(t, '07_stats.png');
  });

  testWidgets('08 我的', (t) async {
    await _pump(t, const ProfileScreen());
    await _shot(t, '08_profile.png');
  });
}
