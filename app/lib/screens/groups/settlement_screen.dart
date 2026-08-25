import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/transfer.dart';
import '../../providers/data_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P25 群组结算页 —— 对齐 docs/ui-demo/index.html
class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  bool _perBill = false;

  static const _tints = [
    Color(0xFFF0F6FB),
    Color(0xFFEDF7EE),
    Color(0xFFFFF1EA),
    Color(0xFFF7F0FB),
  ];

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(settlementPlanProvider(widget.groupId)).value;
    final perBillTransfers =
        ref.watch(perBillTransfersProvider(widget.groupId)).value ??
            const <Transfer>[];

    final transfers = _perBill ? perBillTransfers : (plan?.transfers ?? const <Transfer>[]);
    final members = (ref.watch(groupMembersProvider).value ?? const {})[widget.groupId] ?? [];

    return AaScaffold(
      appBar: AaAppBar(
        title: '✨ 一键智能结算',
        iconImage: 'assets/icons/abacus.png',
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 头部贴纸卡：Demo `.card` + `background:var(--marker)` + `.tape.sky`
          PaperCard(
            color: AAColors.marker,
            withTape: true,
            tapeColor: AATokens.tapeSky,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text.rich(TextSpan(children: [
                  const TextSpan(
                      text: '🎉 最少 ',
                      style: TextStyle(
                          fontFamily: 'ZCOOLKuaiLe', fontSize: 26, color: AAColors.ink)),
                  TextSpan(
                    text: '${transfers.length}',
                    style: const TextStyle(
                        fontFamily: 'LongCang',
                        fontSize: 30,
                        color: AASemantic.amountNeg),
                  ),
                  const TextSpan(
                      text: ' 笔清账！',
                      style: TextStyle(
                          fontFamily: 'ZCOOLKuaiLe', fontSize: 26, color: AAColors.ink)),
                ])),
                const SizedBox(height: 4),
                const Text('团团帮你算好了，按这个转就行',
                    style: TextStyle(
                        fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (transfers.isEmpty)
            const EmptyState(
              title: '全群已清账，两不相欠啦 🎉',
              subtitle: '这笔不用再转了',
              tag: 'P23/P25 已清账 🎉',
              art: '🎉🌸',
            )
          else
            ...transfers.asMap().entries.map((e) {
              String avat(String uid) {
                for (final m in members) {
                  if (m.userId == uid) return m.avatarUrl;
                }
                return '🐼';
              }

              return _TransferCard(
                transfer: e.value,
                index: e.key,
                tint: _tints[e.key % _tints.length],
                fromAvatar: avat(e.value.fromUserId),
                toAvatar: avat(e.value.toUserId),
              );
            }),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DoodleButton(
                  label: '💬 复制转账文案',
                  type: DoodleButtonType.ghost,
                  mini: true,
                  expand: true,
                  onPressed: () => _copyPlan(transfers),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DoodleButton(
                  label: '📱 收款码卡片',
                  type: DoodleButtonType.ghost,
                  mini: true,
                  expand: true,
                  onPressed: () => showAaToast(context, '收款码卡片已生成'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DoodleButton(
            label: '📢 开始催款',
            big: true,
            onPressed: () => context.push('/groups/${widget.groupId}/remind'),
          ),
          const SizedBox(height: 10),
          // 模式切换提示（Demo 底部 mini dim 文案）
          InkWell(
            onTap: () => setState(() => _perBill = !_perBill),
            child: Text(
              _perBill
                  ? '🔀 已选：逐笔结算模式 · 切换到最少笔数'
                  : '🔀 已选：最少笔数模式 · 切换到逐笔结算',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _copyPlan(List<Transfer> transfers) {
    final sb = StringBuffer();
    var i = 0;
    for (final t in transfers) {
      i++;
      sb.writeln('$i. ${t.fromName} → ${t.toName}  ${Fmt.yuan(t.amountCents, trimZero: true)}');
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    showAaToast(context, '💬 转账文案已复制');
  }
}

/// 转账卡 —— Demo：`[头像][mini 王五→我 / 金额30px / mini 备注][手绘箭头][chip 待付]`
class _TransferCard extends StatelessWidget {
  const _TransferCard({
    required this.transfer,
    required this.index,
    required this.tint,
    required this.fromAvatar,
    required this.toAvatar,
  });
  final Transfer transfer;
  final int index;
  final Color tint;
  final String fromAvatar;
  final String toAvatar;

  @override
  Widget build(BuildContext context) {
    return PaperCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: null,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SketchAvatar(emoji: fromAvatar, size: 44, name: transfer.fromName, background: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${transfer.fromName} → ${transfer.toName}',
                    style: const TextStyle(
                        fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft)),
                const SizedBox(height: 2),
                HandAmount(amountCents: transfer.amountCents, color: AAColors.ink, size: 30),
                Text(
                  _note(),
                  style: const TextStyle(
                      fontFamily: 'ZCOOLKuaiLe', fontSize: 12, color: AAColors.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          CustomPaint(
            size: const Size(44, 26),
            painter: _ArrowSvgPainter(),
          ),
          const SizedBox(width: 8),
          HandTag(
            transfer.fromUserId == 'me' ? '我去付' : '待付',
            fontSize: 12,
            variant: transfer.fromUserId == 'me'
                ? ChipVariant.green
                : ChipVariant.orange,
          ),
        ],
      ),
    );
  }

  String _note() {
    if (transfer.billIds.length <= 1) return '今晚聚餐';
    return '${transfer.billIds.length} 笔账单';
  }
}

/// 手绘箭头 —— Demo SVG `viewBox="0 0 40 24"`：
/// `M3 14 Q16 4 30 11` + `M24 8 L33 11.4 L26 16`
class _ArrowSvgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 40;
    canvas.save();
    canvas.scale(s);
    final p = Paint()
      ..color = AAColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(3, 14)
      ..quadraticBezierTo(16, 4, 30, 11)
      ..moveTo(24, 8)
      ..lineTo(33, 11.4)
      ..lineTo(26, 16);
    canvas.drawPath(path, p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
