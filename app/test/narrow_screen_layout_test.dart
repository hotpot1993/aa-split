// 窄屏（360dp）布局守卫：
// v1.0.17 真机 bug —— 邀请页「方式三：直接添加（无需注册）」沿用「标签 + 固定宽输入框 +
// 按钮」的单行布局，在 360dp 窄屏下按钮被挤出屏幕（实测右边界 410 / 屏宽 360），
// 用户填写名称后点击「添加」无任何响应、成员也不会新增。
// 本文件把含可点控件的页面在真机常见窄屏宽度下全部渲染一遍，守住两点：
//   ① 不得出现布局溢出（RenderFlex overflow）
//   ② 可点控件（DoodleButton / HandToggle）必须完整落在屏幕水平范围内
// 新增/改动上述页面的布局后请跑本文件（flutter test test/narrow_screen_layout_test.dart）。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_design/aa_design.dart';
import 'package:aa_split_app/screens/add/add_bill_screen.dart';
import 'package:aa_split_app/screens/add/participants_screen.dart';
import 'package:aa_split_app/screens/add/regular_bill_screen.dart';
import 'package:aa_split_app/screens/groups/create_group_screen.dart';
import 'package:aa_split_app/screens/groups/group_detail_screen.dart';
import 'package:aa_split_app/screens/groups/group_settings_screen.dart';
import 'package:aa_split_app/screens/groups/invite_screen.dart';
import 'package:aa_split_app/screens/groups/members_screen.dart';
import 'package:aa_split_app/screens/groups/remind_screen.dart';
import 'package:aa_split_app/screens/groups/settlement_screen.dart';
import 'package:aa_split_app/screens/home/bill_detail_screen.dart';
import 'package:aa_split_app/screens/home/home_screen.dart';
import 'package:aa_split_app/screens/messages/messages_screen.dart';
import 'package:aa_split_app/screens/messages/reminder_settings_screen.dart';
import 'package:aa_split_app/screens/profile/profile_screen.dart';
import 'package:aa_split_app/screens/search/search_screen.dart';

/// 真机常见窄屏：1080 物理像素 / dpr 3.0 = 360dp 逻辑宽度
const _physical = Size(1080, 2340);
const _dpr = 3.0;
const _screenW = 360.0;

void main() {
  final screens = <String, Widget Function()>{
    '邀请成员（群主）': () => const InviteScreen(groupId: 'g1'),
    '邀请成员（非群主）': () => const InviteScreen(groupId: 'g3'),
    '成员管理': () => const MembersScreen(groupId: 'g1'),
    '群组详情': () => const GroupDetailScreen(groupId: 'g1'),
    '群组设置': () => const GroupSettingsScreen(groupId: 'g1'),
    '首页': () => const HomeScreen(),
    '记一笔': () => const AddBillScreen(),
    '账单详情': () => const BillDetailScreen(billId: 'b1'),
    '结算方案': () => const SettlementScreen(groupId: 'g1'),
    '催款': () => const RemindScreen(groupId: 'g1'),
    '消息中心': () => const MessagesScreen(),
    '搜索': () => const SearchScreen(),
    '我的': () => const ProfileScreen(),
    '创建群组': () => const CreateGroupScreen(),
    '定期账单': () => const RegularBillScreen(),
    '参与人': () => const ParticipantsScreen(billId: 'b1'),
    '提醒设置': () => const ReminderSettingsScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('窄屏 360dp：${entry.key} 无溢出且可点控件在屏内', (tester) async {
      tester.view.physicalSize = _physical;
      tester.view.devicePixelRatio = _dpr;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAaTheme(),
          home: entry.value(),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull,
          reason: '${entry.key} 在 ${_screenW}dp 下出现布局溢出');

      for (final finder in <Finder>[
        find.byType(DoodleButton),
        find.byType(HandToggle),
      ]) {
        for (final el in finder.evaluate()) {
          final rect = tester.getRect(find.byWidget(el.widget));
          expect(rect.left, greaterThanOrEqualTo(0.0),
              reason: '${entry.key}：控件越过屏幕左边界（$rect）');
          expect(rect.right, lessThanOrEqualTo(_screenW),
              reason: '${entry.key}：控件被挤出屏幕右边界（$rect > ${_screenW}dp）');
        }
      }
    });
  }
}
