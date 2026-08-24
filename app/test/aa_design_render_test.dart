import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_design/aa_design.dart';

void main() {
  testWidgets('aa_design core components render', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: aaTheme,
        home: SketchPaper(
          child: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  PaperCard(withTape: true, tiltSeed: 't', child: Text('卡片文本')),
                  HandAmount(amountCents: -8650, showSign: true, size: 40),
                  HandAmountWithLabel(amountCents: 12000, label: '应收'),
                  DoodleButton(label: '记一笔'),
                  StampBadge(text: '已结清'),
                  HandTag(label: '餐饮', icon: Icons.restaurant),
                  TuanTuan(emotion: TuanTuanEmotion.happy, size: 90),
                  CheckDraw(size: 60),
                  HighlightText('重点'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('卡片文本'), findsOneWidget);
    expect(find.text('记一笔'), findsOneWidget);
    expect(find.text('已结清'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('重点'), findsOneWidget);
  });
}
