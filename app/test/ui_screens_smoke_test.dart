// 全页面视觉巡检：渲染未进商店截图的页面（接入层/搜索/设置系等），
// 断言无异常/溢出。样式基准：docs/ui-demo/index.html
import 'dart:io';

import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aa_split_app/core/config.dart';
import 'package:aa_split_app/screens/add/participants_screen.dart';
import 'package:aa_split_app/screens/add/regular_bill_screen.dart';
import 'package:aa_split_app/screens/auth/forgot_screen.dart';
import 'package:aa_split_app/screens/auth/login_screen.dart';
import 'package:aa_split_app/screens/auth/register_screen.dart';
import 'package:aa_split_app/screens/auth/reset_screen.dart';
import 'package:aa_split_app/screens/groups/create_group_screen.dart';
import 'package:aa_split_app/screens/groups/group_settings_screen.dart';
import 'package:aa_split_app/screens/groups/invite_screen.dart';
import 'package:aa_split_app/screens/groups/link_join_screen.dart';
import 'package:aa_split_app/screens/groups/members_screen.dart';
import 'package:aa_split_app/screens/messages/reminder_settings_screen.dart';
import 'package:aa_split_app/screens/profile/about_screen.dart';
import 'package:aa_split_app/screens/profile/export_screen.dart';
import 'package:aa_split_app/screens/profile/legal_content.dart';
import 'package:aa_split_app/screens/profile/legal_screen.dart';
import 'package:aa_split_app/screens/profile/profile_screen.dart';
import 'package:aa_split_app/screens/profile/security_screen.dart';
import 'package:aa_split_app/screens/search/search_screen.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  var added = 0;
  for (final f in files) {
    final file = File(f);
    if (!file.existsSync()) continue; // 跨平台(如 Linux CI)缺失字体自动跳过
    final bytes = file.readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    added++;
  }
  if (added == 0) return;
  await loader.load();
}

void main() {
  setUpAll(() async {
    const base = 'packages/aa_design/assets/fonts';
    await _loadFont('Roboto', ['$base/ZCOOLKuaiLe-Regular.ttf']);
    await _loadFont('ZCOOLKuaiLe', ['$base/ZCOOLKuaiLe-Regular.ttf']);
    await _loadFont('LongCang', ['$base/LongCang-Regular.ttf']);
    await _loadFont('ZhiMangXing', ['$base/ZhiMangXing-Regular.ttf']);
    await _loadFont('Caveat', ['$base/Caveat-VariableFont_wght.ttf']);
    // 货币符号 ¥ 统一 JetBrains Mono（与 store_screenshots 一致加载）
    await _loadFont('JetBrainsMono', ['$base/JetBrainsMono-Variable.ttf']);
    await _loadFont('NotoSansSC', ['$base/NotoSansSC-Variable.ttf']);
    await _loadFont('Emoji', [r'C:\Windows\Fonts\seguiemj.ttf']);
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = buildAaTheme();
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: base.copyWith(
            textTheme: base.textTheme.apply(
              fontFamilyFallback: const ['Emoji'],
            ),
          ),
          home: screen,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  }

  testWidgets('login', (t) async => pump(t, const LoginScreen()));
  testWidgets('register', (t) async => pump(t, const RegisterScreen()));
  testWidgets('forgot', (t) async => pump(t, const ForgotScreen()));
  testWidgets('reset', (t) async => pump(t, const ResetScreen()));
  testWidgets('create group', (t) async => pump(t, const CreateGroupScreen()));
  testWidgets(
    'invite',
    (t) async => pump(t, const InviteScreen(groupId: 'g1')),
  );
  testWidgets('join link', (t) async => pump(t, const LinkJoinScreen()));
  testWidgets(
    'members',
    (t) async => pump(t, const MembersScreen(groupId: 'g1')),
  );
  testWidgets(
    'group settings',
    (t) async => pump(t, const GroupSettingsScreen(groupId: 'g1')),
  );
  testWidgets(
    'reminder settings',
    (t) async => pump(t, const ReminderSettingsScreen()),
  );
  // 「设置」已迁入「我的」主页（二级设置页已删除），巡检我的页
  testWidgets('profile', (t) async => pump(t, const ProfileScreen()));
  testWidgets('security', (t) async => pump(t, const SecurityScreen()));
  testWidgets('export', (t) async => pump(t, const ExportScreen()));
  testWidgets('about', (t) async {
    await pump(t, const AboutScreen());
    // 版本号与 AppConfig 完全一致（单一来源，防硬编码漂移）；
    // 「构建号/作者」文案已按需求移除
    expect(find.textContaining('v${AppConfig.appVersion}'), findsWidgets);
    expect(find.textContaining('构建'), findsNothing);
    expect(find.textContaining('程序员们'), findsNothing);
  });
  testWidgets(
    'user agreement',
    (t) async => pump(t, const LegalDocScreen(spec: userAgreementSpec)),
  );
  testWidgets(
    'privacy policy',
    (t) async => pump(t, const LegalDocScreen(spec: privacyPolicySpec)),
  );
  testWidgets(
    'open source',
    (t) async => pump(t, const LegalDocScreen(spec: openSourceSpec)),
  );
  testWidgets('search', (t) async => pump(t, const SearchScreen()));
  testWidgets(
    'participants',
    (t) async => pump(t, const ParticipantsScreen(billId: 'b1')),
  );
  testWidgets('regular', (t) async => pump(t, const RegularBillScreen()));
}
