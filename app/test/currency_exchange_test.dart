// 回归：记一笔 —— 旅行常用货币选择 + 按当日汇率换算成人民币入账（Demo 参考汇率）
import 'package:aa_design/aa_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/core/currency.dart';
import 'package:aa_split_app/data/mock/mock_store.dart';
import 'package:aa_split_app/models/group_member.dart';
import 'package:aa_split_app/screens/add/add_bill_screen.dart';
import 'package:aa_split_app/screens/add/bill_draft.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildAaTheme(),
        home: const AddBillScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('旅行货币表与参考汇率', () {
    test('CNY 为默认首项，代码唯一', () {
      expect(travelCurrencies.first.code, 'CNY');
      expect(travelCurrencies.first.isCny, isTrue);
      expect(
        travelCurrencies.map((c) => c.code).toSet().length,
        travelCurrencies.length,
      );
    });

    test('demoRateOf：常见外币参考汇率', () {
      expect(demoRateOf('CNY'), 1);
      expect(demoRateOf('USD'), 7.25);
      expect(demoRateOf('EUR'), 7.85);
      expect(demoRateOf('THB'), 0.21);
      expect(demoRateOf('XXX'), 1); // 未知币种回退 1
    });

    test('matchTravelCurrency：OCR 币种 → 旅行货币匹配（未知/空返回 null）', () {
      expect(matchTravelCurrency('USD')?.code, 'USD');
      expect(matchTravelCurrency('CNY')?.code, 'CNY');
      expect(matchTravelCurrency('hkd')?.code, isNull); // 大小写敏感，非标准代码不计
      expect(matchTravelCurrency('XXX'), isNull);
      expect(matchTravelCurrency(null), isNull);
      expect(matchTravelCurrency(''), isNull);
    });

    test('外币金额换算为人民币（分）', () {
      // 10.00 USD = 1000 分 × 7.25 = 7250 分
      expect((1000 * demoRateOf('USD')).round(), 7250);
      // 5.00 THB = 500 分 × 0.21 = 105 分
      expect((500 * demoRateOf('THB')).round(), 105);
    });

    test('computeEven 余数逐人 1 分分配，合计恒等于总额', () {
      const members = [
        GroupMember(id: 'a', userId: 'a', nickname: 'A', accountName: 'a', isOwner: false),
        GroupMember(id: 'b', userId: 'b', nickname: 'B', accountName: 'b', isOwner: false),
        GroupMember(id: 'c', userId: 'c', nickname: 'C', accountName: 'c', isOwner: false),
        GroupMember(id: 'd', userId: 'd', nickname: 'D', accountName: 'd', isOwner: false),
      ];
      // 7250 分 4 人：base 1812 余 2 → [1813,1813,1812,1812]
      final lines = computeEven(7250, members, {});
      expect(lines.fold<int>(0, (s, l) => s + l.amountCents), 7250);
      expect(lines.map((l) => l.amountCents), containsAllInOrder([1813, 1813, 1812, 1812]));
      // 100 元 3 人：3334+3333+3333 = 10000
      final three = computeEven(10000, members.take(3).toList(), {});
      expect(three.fold<int>(0, (s, l) => s + l.amountCents), 10000);
    });
  });

  testWidgets('记一笔：选美元 → 实时折算提示 → 保存的账单为人民币金额', (tester) async {
    await _pump(tester);

    // 选择「美元」
    await tester.tap(find.text('人民币 (CNY)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('美元 (USD)').last);
    await tester.pumpAndSettle();

    // 输入 10（美元）
    await tester.enterText(find.byType(TextField).first, '10');
    await tester.pump();

    // 折算提示：≈ ¥72.50 · 今日汇率 1 USD ≈ 7.2500
    expect(find.textContaining('≈ ¥72.50'), findsOneWidget);
    expect(find.textContaining('今日汇率 1 USD ≈ 7.2500'), findsOneWidget);

    // 保存 → 入账金额为人民币
    await tester.tap(find.text('收下这张小票！✓'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final saved = MockStore.instance.bills.last;
    expect(saved.amountCents, 7250, reason: '10 USD 应按当日汇率折算为 ¥72.50 入账');
    // 参与人份额合计 = 人民币金额（computeEven 余数逐人 1 分分配）
    expect(saved.participants.fold<int>(0, (s, p) => s + p.shareAmountCents), 7250);

    await tester.pump(const Duration(seconds: 2));
  });
}
