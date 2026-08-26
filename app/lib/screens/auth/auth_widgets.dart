import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

/// 预设安全问题（注册设置 / 账号安全「修改安全问题」共用）
const securityQuestions = [
  '你第一个朋友的名字？',
  '你妈妈的姓氏？',
  '你最喜欢的城市？',
  '你的小学名字？',
];

/// 行内红章错误提示（Demo 异常态：小印章，不弹窗打断）
class FieldError extends StatelessWidget {
  const FieldError({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StampBadge(text: '!', color: AAColors.berry, rotate: -8),
          SizedBox(width: 6),
          Text(
            message!,
            style: TextStyle(
              fontFamily: AAFonts.title,
              fontSize: 12,
              color: AAColors.berry,
            ),
          ),
        ],
      ),
    );
  }
}

/// 接入层页面公共骨架（纸米底 + 点阵纸 + 内容列）
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, this.children = const []});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AAColors.paper,
      body: SketchPaper(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
