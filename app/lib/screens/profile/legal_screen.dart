import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

import '../../widgets/common.dart';

/// 法律条款单页内容（用户协议 / 隐私政策 / 开源声明 共用结构）
class LegalDocSpec {
  const LegalDocSpec({
    required this.title,
    required this.headIcon,
    required this.icon,
    required this.meta,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String headIcon;
  final String icon;

  /// 顶部信息行（生效日期 / 版本 / 更新说明）
  final List<String> meta;

  /// 开头欢迎/说明段（胶带便签卡）
  final String intro;
  final List<LegalSection> sections;
}

class LegalSection {
  const LegalSection(this.heading, this.items);

  final String heading;
  final List<String> items;
}

/// 法律条款页面骨架：速写纸 + 涂鸦导航 + 胶带便签引言 + 分节卡片正文
class LegalDocScreen extends StatelessWidget {
  const LegalDocScreen({super.key, required this.spec});

  final LegalDocSpec spec;

  static final _metaStyle = TextStyle(
    fontFamily: AAFonts.title,
    fontSize: 12.5,
    color: AAColors.inkSoft,
    height: 1.6,
  );

  static final _introStyle = TextStyle(
    fontFamily: AAFonts.title,
    fontSize: 13.5,
    color: AAColors.ink,
    height: 1.8,
  );

  static final _itemStyle = TextStyle(
    fontFamily: AAFonts.title,
    fontSize: 13,
    color: AAColors.ink,
    height: 1.8,
  );

  @override
  Widget build(BuildContext context) {
    return AaScaffold(
      appBar: AaAppBar(
        title: spec.title,
        headIcon: spec.headIcon,
        icon: spec.icon,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < spec.meta.length; i++) ...[
                  Text(spec.meta[i], style: _metaStyle),
                  if (i != spec.meta.length - 1) const SizedBox(height: 2),
                ],
              ],
            ),
          ),
          SizedBox(height: 10),
          PaperCard(
            withTape: true,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Text(spec.intro, style: _introStyle),
          ),
          for (final section in spec.sections) ...[
            SectionTitle(section.heading),
            PaperCard(
              padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < section.items.length; i++) ...[
                    Text(section.items[i], style: _itemStyle),
                    if (i != section.items.length - 1)
                      const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
