import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/invite_link.dart';
import '../../providers/refresh_provider.dart';
import '../../providers/repositories.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// 邀请链接入群 —— 填写/粘贴群组邀请链接，确认后加入对应群组。
///
/// 兼容输入：`aafen://join/群码`、`https://…/join/群码` 或裸群码；
/// 输入时实时预览识别出的群码，点「确认加入」完成入群。
class LinkJoinScreen extends ConsumerStatefulWidget {
  const LinkJoinScreen({super.key});

  @override
  ConsumerState<LinkJoinScreen> createState() => _LinkJoinScreenState();
}

class _LinkJoinScreenState extends ConsumerState<LinkJoinScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _previewCode => parseInviteCode(_controller.text);

  Future<void> _join() async {
    if (_busy) return;
    final code = parseInviteCode(_controller.text);
    if (code == null) {
      showAaToast(context, '链接格式不对，检查一下再试');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref.read(groupRepositoryProvider).join(code);
      if (!mounted) return;
      ref.read(refreshProvider.notifier).bump();
      showAaToast(context,
          result.alreadyJoined ? '已在「${result.name}」中' : '已加入「${result.name}」🎉');
      context.pushReplacement('/groups/${result.id}');
    } catch (_) {
      if (!mounted) return;
      showAaToast(context, '邀请链接无效，请向群主确认后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _previewCode;
    return AaScaffold(
      appBar: AaAppBar(
        title: '邀请链接入群',
        headIcon: 'assets/icons/link.png',
        iconImage: 'assets/icons/gift.png',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PaperCard(
            withTape: true,
            tapeColor: AATokens.tapeLemon,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('粘贴群主发来的邀请链接',
                    style: TextStyle(
                        fontFamily: AAFonts.title,
                        fontSize: 14,
                        color: AAColors.ink)),
                SizedBox(height: 4),
                Text('也可以直接输入群码，确认后自动加入',
                    style: TextStyle(
                        fontFamily: AAFonts.title,
                        fontSize: 12,
                        color: AAColors.inkSoft)),
                SizedBox(height: 14),
                HandTextField(
                  controller: _controller,
                  hint: 'aafen://join/群码',
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    HandTag(
                      code == null ? '填入邀请链接或群码' : '已识别 群码：$code',
                      color: code == null
                          ? AASemantic.chipOrangeBg
                          : AAColors.mint,
                      textColor:
                          code == null ? AASemantic.chipOrangeText : null,
                      fontSize: 12,
                    ),
                  ],
                ),
                SizedBox(height: 14),
                DoodleButton(
                  label: _busy ? '正在加入…' : '确认加入 →',
                  type: DoodleButtonType.primary,
                  big: true,
                  onPressed: _busy ? null : _join,
                ),
                SizedBox(height: 6),
              ],
            ),
          ),
          SizedBox(height: 16),
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Text(
              '小提示：邀请链接长这样 → aafen://join/群码。'
              '没收到链接？让群主在群组页点「邀请成员」即可。',
              style: TextStyle(
                  fontFamily: AAFonts.title, fontSize: 13, color: AAColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}
