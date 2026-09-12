import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/api/api_client.dart';
import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../models/group_member.dart';
import '../../providers/data_providers.dart';
import '../../providers/repositories.dart';
import '../../providers/refresh_provider.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/picker_sheet.dart';
import '../../widgets/sheet.dart';

/// P24 成员管理 —— 对齐 docs/ui-demo/index.html
///
/// 两类成员（见 CONTEXT.md）：注册成员（可登录）与**非注册成员**（群主代加，
/// 灰色「未注册」标签、不显示 @账户名，可改名、可被「认领」绑定到真实账号）。
class MembersScreen extends ConsumerWidget {
  const MembersScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 成员管理页要展示「已退出」状态，因此用完整成员列表（active 口径见 groupMembersProvider）
    final members = ref.watch(groupAllMembersProvider(groupId)).value ?? const [];
    final bills = ref.watch(billsProvider).value ?? const <Bill>[];
    final me = ref.watch(currentUserProvider)?.id ?? 'me';
    final isOwner = members.any((m) => m.isOwner && m.userId == me);

    // 疑似同一人：非注册成员群内禁止重名，因此与非注册成员同名的注册成员即可精确判定
    final registeredNames = {
      for (final m in members.where((m) => !m.isPlaceholder && m.isActive))
        m.displayName,
    };

    return AaScaffold(
      appBar: AaAppBar(
        title: '成员管理',
        headIcon: 'assets/icons/crown.png',
        iconImage: 'assets/icons/plus.png',
        onIconTap: () => context.push('/groups/$groupId/invite'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PaperCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
            child: Column(
              children: [
                for (var i = 0; i < members.length; i++)
                  _MemberLine(
                    member: members[i],
                    isMe: members[i].userId == me,
                    showBorder: i != members.length - 1,
                    isOwnerView: isOwner,
                    suspiciousSameName: members[i].isPlaceholder &&
                        registeredNames.contains(members[i].displayName),
                    unpaidCents: _unpaidCents(bills, members[i].userId),
                    onRemove: () => _remove(ref, context, members[i]),
                    onRename: () => _rename(ref, context, members[i]),
                    onClaim: (targetId) =>
                        _claim(ref, context, members[i], targetId),
                    sameNameTargetId: members[i].isPlaceholder
                        ? _sameNameRegisteredId(members, members[i])
                        : null,
                  ),
              ],
            ),
          ),
          SizedBox(height: 16),
          DoodleButton(
            label: '＋ 添加成员',
            big: true,
            onPressed: () => context.push('/groups/$groupId/invite'),
          ),
          SizedBox(height: 10),
          DoodleButton(
            label: '退出群组（账单仍保留）',
            type: DoodleButtonType.danger,
            big: true,
            onPressed: () => _leave(ref, context, me),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 与非注册成员同名的注册成员（群内禁止重名 → 同名即可精确判定「疑似同一人」）
  String? _sameNameRegisteredId(List<GroupMember> members, GroupMember placeholder) {
    for (final m in members) {
      if (!m.isPlaceholder && m.isActive && m.displayName == placeholder.displayName) {
        return m.userId;
      }
    }
    return null;
  }

  /// 该成员在本群的未结清金额（本人应付未付部分）
  int _unpaidCents(List<Bill> bills, String userId) {
    var sum = 0;
    for (final b in bills) {
      if (b.groupId != groupId || b.fullySettled) continue;
      for (final p in b.participants) {
        if (p.userId == userId && !p.paid && !p.exempt) {
          sum += p.shareAmountCents;
        }
      }
    }
    return sum;
  }

  Future<void> _remove(WidgetRef ref, BuildContext context, GroupMember m) async {
    final unpaid = _unpaidCents(
      ref.read(billsProvider).value ?? const <Bill>[],
      m.userId,
    );
    // 非注册成员没有账号可追讨，移除前必须把未结清金额摆明（产品原型 P24）
    final subtitle = unpaid > 0
        ? 'TA 还有 ${Fmt.yuan(unpaid, trimZero: true)} 未结清，移除后账单仍会保留在群里'
        : 'TA的未结清账单仍会保留在群里';
    final ok = await showAaConfirm(
      context,
      title: '把「${m.displayName}」移出群？',
      subtitle: subtitle,
      confirmLabel: '移除',
    );
    if (ok == true) {
      if (!context.mounted) return;
      await ref.read(groupRepositoryProvider).removeMember(groupId, m.userId);
      if (!context.mounted) return;
      ref.read(refreshProvider.notifier).bump();
      showAaToast(context, '已移除 ${m.displayName}');
    }
  }

  /// 非注册成员改名（群内不可重名）
  Future<void> _rename(WidgetRef ref, BuildContext context, GroupMember m) async {
    final name = await showAaSheet<String>(
      context,
      child: _RenameSheet(initial: m.nickname),
    );
    if (name == null || !context.mounted) return;
    try {
      await ref
          .read(groupRepositoryProvider)
          .renamePlaceholderMember(groupId, m.userId, name);
      if (!context.mounted) return;
      ref.read(refreshProvider.notifier).bump();
      showAaToast(context, '已改名为 $name');
    } catch (e) {
      if (!context.mounted) return;
      showAaToast(context, e is ApiException ? e.message : '改名失败');
    }
  }

  /// 认领：把非注册成员绑定到某个真实账号（不可撤销）
  Future<void> _claim(
    WidgetRef ref,
    BuildContext context,
    GroupMember m,
    String? presetTargetId,
  ) async {
    final all =
        ref.read(groupAllMembersProvider(groupId)).value ?? const <GroupMember>[];
    final candidates =
        all.where((x) => !x.isPlaceholder && x.userId != m.userId).toList();
    if (candidates.isEmpty) {
      showAaToast(context, '群里还没有可绑定的注册成员');
      return;
    }
    String? targetId = presetTargetId;
    targetId ??= await showAaPickerSheet<String>(
      context,
      title: '把「${m.displayName}」绑定到哪个账户？',
      searchable: true,
      searchHint: '搜索昵称 / 账户名',
      options: [
        for (final c in candidates)
          PickerOption(
            c.userId,
            c.displayName,
            subtitle: c.isActive ? '@${c.accountName}' : '已退出群组',
          ),
      ],
    );
    if (targetId == null || !context.mounted) return;
    final target = candidates.firstWhere((c) => c.userId == targetId);

    final repo = ref.read(groupRepositoryProvider);
    ClaimPreview preview;
    try {
      preview = await repo.claimPreview(groupId, m.userId, targetId);
    } catch (e) {
      if (!context.mounted) return;
      showAaToast(context, e is ApiException ? e.message : '无法认领');
      return;
    }
    if (!context.mounted) return;

    final parts = <String>[
      '将合并 ${preview.billCount} 笔账单、${preview.settlementCount} 条历史结算',
      if (!preview.targetInGroup) '目标账号不在群里，认领后会自动加入',
      '认领不可撤销',
    ];
    final ok = await showAaConfirm(
      context,
      title: '把「${m.displayName}」绑定到「${target.displayName}」？',
      subtitle: parts.join('；'),
      confirmLabel: '确认认领',
    );
    if (ok != true || !context.mounted) return;
    try {
      await repo.claimPlaceholderMember(groupId, m.userId, targetId);
      if (!context.mounted) return;
      ref.read(refreshProvider.notifier).bump();
      showAaToast(context, '已认领，历史账单归到「${target.displayName}」名下');
    } catch (e) {
      if (!context.mounted) return;
      showAaToast(context, e is ApiException ? e.message : '认领失败');
    }
  }

  Future<void> _leave(WidgetRef ref, BuildContext context, String me) async {
    final members =
        ref.read(groupAllMembersProvider(groupId)).value ?? const <GroupMember>[];
    final isOwner = members.any((x) => x.isOwner && x.userId == me);
    if (isOwner) {
      showAaToast(context, '你是群主，先转让群主或解散群组');
      return;
    }
    final ok = await showAaConfirm(
      context,
      title: '要退出这个群吗？',
      subtitle: '退出不影响账单结算',
      confirmLabel: '退出',
    );
    if (ok == true) {
      if (!context.mounted) return;
      await ref.read(groupRepositoryProvider).removeMember(groupId, me);
      if (!context.mounted) return;
      ref.read(refreshProvider.notifier).bump();
      showAaToast(context, '👋 已退出群组');
      if (context.mounted) context.pop();
    }
  }
}

/// 非注册成员改名弹层
class _RenameSheet extends StatefulWidget {
  const _RenameSheet({required this.initial});
  final String initial;

  @override
  State<_RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<_RenameSheet> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('改名称',
            style: TextStyle(
                fontFamily: AAFonts.title, fontSize: 18, color: AAColors.ink)),
        SizedBox(height: 12),
        HandTextField(
          controller: _c,
          hint: '1–32 个字符',
        ),
        SizedBox(height: 14),
        DoodleButton(
          label: '保存',
          big: true,
          expand: true,
          onPressed: () {
            final name = _c.text.replaceAll(RegExp(r'[\u0000-\u001f\u007f]'), '').trim();
            if (name.isEmpty || name.length > 32) {
              showAaToast(context, '名称长度需为 1–32 个字符');
              return;
            }
            Navigator.of(context).pop(name);
          },
        ),
        SizedBox(height: 4),
      ],
    );
  }
}

class _MemberLine extends StatelessWidget {
  const _MemberLine({
    required this.member,
    required this.isMe,
    required this.showBorder,
    required this.isOwnerView,
    required this.suspiciousSameName,
    required this.unpaidCents,
    required this.onRemove,
    required this.onRename,
    required this.onClaim,
    this.sameNameTargetId,
  });

  final GroupMember member;
  final bool isMe;
  final bool showBorder;
  final bool isOwnerView;
  final bool suspiciousSameName;
  final int unpaidCents;
  final VoidCallback onRemove;
  final VoidCallback onRename;

  /// 认领（绑定到账户）：可带一个「同名疑似对象」直达，否则打开选择弹层
  final void Function(String? targetUserId) onClaim;
  final String? sameNameTargetId;

  bool get _canManage => isOwnerView && !isMe;

  @override
  Widget build(BuildContext context) {
    final statusTag = member.isPlaceholder
        // 非注册成员：灰色「未注册」标签，且不显示 @账户名（它没有可用账户名）
        ? const HandTag('未注册',
            dense: true, variant: ChipVariant.plain, textColor: _gray)
        : member.isActive
            ? const HandTag('正常', dense: true, variant: ChipVariant.blue)
            : const HandTag('已退出',
                dense: true, variant: ChipVariant.plain, textColor: _gray);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        // 头像：emoji / 本地文件 / 网络图统一 SketchAvatar 渲染，
                        // 换头像后随成员数据刷新同步显示新头像
                        SketchAvatar(
                          emoji: member.avatarUrl,
                          size: 34,
                          name: member.displayName,
                          background: Color(0xFFFFF1EA),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text:
                                    '${member.displayName}${isMe ? '（我）' : ''} ',
                                style: TextStyle(
                                    fontFamily: AAFonts.title,
                                    fontSize: 15,
                                    color: AAColors.ink),
                              ),
                              if (!member.isPlaceholder)
                                TextSpan(
                                  text: '@${member.accountName}',
                                  style: TextStyle(
                                      fontFamily: AAFonts.title,
                                      fontSize: 12,
                                      color: AAColors.inkSoft),
                                ),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (member.isOwner)
                    Row(
                      children: [
                        AaIconImage('assets/icons/crown.png', size: 16),
                        SizedBox(width: 4),
                        Text('群主',
                            style: TextStyle(
                                fontFamily: AAFonts.title,
                                fontSize: 15,
                                color: AAColors.ink)),
                      ],
                    )
                  else
                    Row(
                      children: [
                        statusTag,
                        if (_canManage) ...[
                          SizedBox(width: 6),
                          InkWell(
                            onTap: onRemove,
                            child: Row(
                              children: [
                                AaIconImage('assets/icons/cross.png', size: 13),
                                SizedBox(width: 2),
                                Text('移除',
                                    style: TextStyle(
                                        fontFamily: AAFonts.title,
                                        fontSize: 12,
                                        color: AAColors.inkSoft)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
              // 非注册成员：改名 / 绑定到账户（认领），仅群主可见
              if (member.isPlaceholder && _canManage) ...[
                SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (unpaidCents > 0)
                        Text('未结清 ${Fmt.yuan(unpaidCents, trimZero: true)}',
                            style: TextStyle(
                                fontFamily: AAFonts.title,
                                fontSize: 12,
                                color: AAColors.berry)),
                      _ActionLink(label: '改名', onTap: onRename),
                      _ActionLink(
                        label: '绑定到账户',
                        onTap: () => onClaim(null),
                      ),
                    ],
                  ),
                ),
                if (suspiciousSameName && sameNameTargetId != null) ...[
                  SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _ActionLink(
                      label: '疑似同一人，去认领 →',
                      onTap: () => onClaim(sameNameTargetId),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
        if (showBorder)
          CustomPaint(size: Size(double.infinity, 2.5), painter: _MemberDash()),
      ],
    );
  }

  static const _gray = AAColors.inkSoft;
}

/// 行内文字动作（手绘风格：无边框，仅文字 + 下划线感）
class _ActionLink extends StatelessWidget {
  const _ActionLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AAFonts.title,
          fontSize: 12,
          color: AASemantic.chipBlueText,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

class _MemberDash extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AAColors.ink
      ..strokeWidth = 2.5;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 1.25), Offset(x + 7, 1.25), p);
      x += 14;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
