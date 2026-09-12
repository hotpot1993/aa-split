// 真机逐屏截图（Demo 版：AA_MOCK_AUTO_LOGIN=true，与手机上 Demo 版一致：
// 启动 → 自动登录进入首页；登录/注册/忘记密码/重设密码经「退出登录」流程采集）
//
// 运行方式（先构建含测试入口的 APK，再 drive，保证可在安装后 adb 预授权相机等权限）：
//   1) flutter build apk --debug --target=integration_test/screenshots_all_screens_test.dart
//   2) adb install -r build/app/outputs/flutter-apk/app-debug.apk
//      adb shell pm grant com.aasplit.app android.permission.CAMERA
//   3) $env:SCREENSHOT_DIR = "<截图输出目录>"
//      flutter drive --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk \
//        --driver=test_driver/integration_test.dart \
//        --target=integration_test/screenshots_all_screens_test.dart -d <device>
//
// 说明：
//  - Demo 数据（mock_store）：登录账户 tuanzi（昵称 团子酱）；群 g1/g2/g3；账单 b1~b10；
//  - 每个界面通过 go_router 路由进入（与真机点击同一渲染结果），截图命名 NN_界面名。
//  - 启动页（耗时 5s 自动跳转）在 5s 定时器触发前抓帧。
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';

import 'package:aa_design/aa_design.dart';
import 'package:aa_split_app/providers/notification_stream_provider.dart';
import 'package:aa_split_app/providers/settings_provider.dart';
import 'package:aa_split_app/router/app_router.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('真机逐屏截图：35 个界面', (tester) async {
    // 实时帧策略：真机截图/滚动需要真实帧
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    await FontStyleStore.init();

    // 与 main.dart 等价的挂载方式，但把 router 句柄暴露给测试
    GoRouter? router;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            router ??= buildRouter(ref);
            ref.watch(notificationStreamProvider);
            final fontStyle = ref.watch(fontStyleProvider);
            AAFonts.useStyle(fontStyle);
            return MaterialApp.router(
              key: ValueKey(fontStyle),
              theme: buildAaTheme(),
              routerConfig: router!,
              debugShowCheckedModeBanner: false,
            );
          },
        ),
      ),
    );

    // 等待过渡/加载完成；个别页面（如“我的”吉祥物挥手动画）永不停帧，
    // 超时则改为固定等待后照常截图。
    Future<void> settle() async {
      try {
        await tester.pumpAndSettle(
          const Duration(milliseconds: 200),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 15),
        );
      } catch (_) {
        await tester.pump(const Duration(milliseconds: 900));
      }
    }

    Future<void> shot(String name) async {
      await settle();
      await tester.pump(const Duration(milliseconds: 130));
      await binding.takeScreenshot(name);
    }

    Future<void> goTo(String path, String name) async {
      router!.go(path);
      await shot(name);
    }

    // ---------- P01 启动页（5s 定时器之前抓帧） ----------
    await tester.pump(const Duration(milliseconds: 250));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump(const Duration(milliseconds: 550));
    await shot('01_启动页');

    // Demo 版（AA_MOCK_AUTO_LOGIN=true）：5s 后自动进入主框架首页
    await tester.pump(const Duration(seconds: 6));
    await settle();

    // ---------- 从「我的」退出登录 → 登录页（Demo 版真实入口） ----------
    router!.go('/profile');
    await settle();
    await tester.tap(find.textContaining('退出登录'));
    await settle();
    await tester.tap(find.text('退出'));
    await settle();
    await shot('02_登录页');

    // ---------- P03 注册页 ----------
    await goTo('/register', '03_注册页');

    // ---------- P04 忘记密码（查询安全问题后截图，展示完整表单） ----------
    router!.go('/forgot');
    await settle();
    await tester.enterText(find.byType(HandTextField).first, 'tuanzi');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('查询安全问题'));
    await shot('04_忘记密码');

    // ---------- P05 重设密码（回答问题 → 进入重置页） ----------
    await tester.enterText(find.byType(HandTextField).last, '小虎');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('下一步：验证答案 →'));
    await shot('05_重置密码');

    // ---------- 重新登录（Demo：tuanzi / 任意非空密码） ----------
    router!.go('/login');
    await settle();
    await tester.enterText(find.byType(TextField).at(0), 'tuanzi');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byType(TextField).at(1), '123456');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.tap(find.byType(DoodleButton).first);
    await shot('06_首页');

    // ---------- 群组体系 ----------
    await goTo('/groups', '07_群组列表');
    await goTo('/groups/g1', '08_群组详情');
    await goTo('/groups/g1/invite', '09_邀请成员');
    await goTo('/groups/g1/members', '10_群成员');
    await goTo('/groups/g1/settlement', '11_结算方案');
    await goTo('/groups/g1/remind', '12_催款');
    await goTo('/groups/g1/settings', '13_群组设置');
    await goTo('/groups/create', '14_创建群组');
    // 扫码页：等相机预览启动后再截图（约 2.5s 预热）
    router!.go('/groups/scan');
    await settle();
    await tester.pump(const Duration(milliseconds: 2500));
    await shot('15_扫码入群');
    await goTo('/groups/join-link', '16_链接入群');

    // ---------- 账单体系 ----------
    await goTo('/bills', '17_账单列表');
    await goTo('/bills/b1', '18_账单详情');
    await goTo('/bills/b1/split', '19_分摊明细');
    await goTo('/bills/b1/participants', '20_参与人');
    await goTo('/bills/b1/receipt', '21_凭证拍照');
    await goTo('/bills/b2/receipt/preview?receipt=r_b2_0', '22_凭证预览');
    await goTo('/regular-bills', '23_定期账单');
    await goTo('/stats', '24_统计');
    await goTo('/add?group=g1', '25_记一笔');

    // ---------- 消息 / 设置 / 搜索 ----------
    await goTo('/messages', '26_消息中心');
    await goTo('/messages/settings', '27_提醒设置');
    await goTo('/search', '28_搜索');

    // ---------- 我的 ----------
    await goTo('/profile', '29_我的');
    await goTo('/security', '30_账号安全');
    await goTo('/export', '31_数据导出');
    await goTo('/about', '32_关于');
    await goTo('/about/agreement', '33_用户协议');
    await goTo('/about/privacy', '34_隐私政策');
    await goTo('/about/oss', '35_开源许可');

    // 触发 widget 树稳定（避免测试收尾时断言崩溃）
    await settle();
  });
}
