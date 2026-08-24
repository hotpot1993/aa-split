import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:aa_design/aa_design.dart';

import '../../models/transfer.dart';
import '../../providers/data_providers.dart';
import '../../widgets/avatar.dart';
import '../../widgets/common.dart';
import '../../widgets/sheet.dart';

/// P25 群组结算页（核心）
class SettlementScreen extends ConsumerStatefulWidget {
  const SettlementScreen({super.key, required this.groupId});
  final String groupId;
  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  bool _perBill = false;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(settlementPlanProvider(widget.groupId)).value;
    final perBillTransfers =
        ref.watch(perBillTransfersProvider(widget.groupId)).value ??
            const <Transfer>[];
    final text = Theme.of(context).textTheme;

    final transfers = _perBill ? perBillTransfers : (plan?.transfers ?? const <Transfer>[]);
    final title = _perBill ? '逐笔结算' : '最少 ${plan?.transferCount ?? 0} 笔清账！';
    final members = (ref.watch(groupMembersProvider).value ?? const {})[widget.groupId] ?? [];

    return AaScaffold(
      appBar: AppBar(title: const Text('一键智能结算')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // 顶部贴纸
          Transform.rotate(
            angle: -0.06,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: AAColors.lemon.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AAColors.coral, width: 2),
                ),
                child: Text(
                  '🎉 $title',
                  style: const TextStyle(
                    fontFamily: 'ZCOOLKuaiLe',
                    fontSize: 18,
                    color: AAColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (transfers.isEmpty)
            const EmptyState(
              title: '全群已清账，两不相欠啦 🎉',
              emotion: TuanTuanEmotion.celebrate,
              subtitle: '这笔不用再转了',
            )
          else
            ...transfers.map((t) {
              String avat(String uid) {
                for (final m in members) {
                  if (m.userId == uid) return m.avatarUrl;
                }
                return '🐼';
              }

              return _TransferCard(
                transfer: t,
                index: transfers.indexOf(t),
                fromAvatar: avat(t.fromUserId),
                toAvatar: avat(t.toUserId),
              );
            }),
          const SizedBox(height: 18),
          Row(
            children: [
              if (!_perBill)
                Expanded(
                  child: DoodleButton(
                    label: '💬 复制文案',
                    type: DoodleButtonType.secondary,
                    expand: true,
                    onPressed: () => _copyPlan(transfers),
                  ),
                ),
              if (!_perBill) const SizedBox(width: 12),
              Expanded(
                child: DoodleButton(
                  label: '📱 开始催款',
                  expand: true,
                  onPressed: () => context.push('/groups/${widget.groupId}/remind'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 逐笔结算开关
          PaperCard(
            child: Row(
              children: [
                const Icon(Icons.swap_horiz, color: AAColors.inkSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _perBill ? '已切到逐笔明细模式' : '逐笔结算（按账单逐人）',
                    style: text.titleSmall,
                  ),
                ),
                HandToggle(
                  value: _perBill,
                  activeColor: AAColors.mint,
                  onChanged: (v) => setState(() => _perBill = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('按最少转账笔数智能规划，也可切换到“逐笔结算”',
              textAlign: TextAlign.center, style: text.bodySmall),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _copyPlan(List<Transfer> transfers) {
    final sb = StringBuffer();
    var i = 0;
    for (final t in transfers) {
      i++;
      sb.writeln('$i. ${t.fromName} → ${t.toName}  ${'¥${(t.amountCents ~/ 100)}.${(t.amountCents % 100).toString().padLeft(2, '0')}'}');
    }
    Clipboard.setData(ClipboardData(text: sb.toString()));
    showAaToast(context, '转账文案已复制');
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({
    required this.transfer,
    required this.index,
    required this.fromAvatar,
    required this.toAvatar,
  });
  final Transfer transfer;
  final int index;
  final String fromAvatar;
  final String toAvatar;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PaperCard(
      margin: const EdgeInsets.only(bottom: 14),
      tiltSeed: 'transfer-$index',
      child: Column(
        children: [
          Row(
            children: [
              Column(
                children: [
                  SketchAvatar(emoji: fromAvatar, size: 42, name: transfer.fromName),
                  const SizedBox(height: 2),
                  Text(transfer.fromName, style: text.bodySmall),
                ],
              ),
              const Expanded(child: _ArrowPainter()),
              Column(
                children: [
                  SketchAvatar(emoji: toAvatar, size: 42, name: transfer.toName),
                  const SizedBox(height: 2),
                  Text(transfer.toName, style: text.bodySmall),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          HandAmount(amountCents: transfer.amountCents, color: AAColors.coral, size: 30),
        ],
      ),
    );
  }
}

class _ArrowPainter extends StatelessWidget {
  const _ArrowPainter();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: CustomPaint(
        size: const Size(double.infinity, 24),
        painter: _ArrowLinePainter(),
      ),
    );
  }
}

class _ArrowLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ink = Paint()
      ..color = AAColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    final start = Offset(2, size.height * 0.35);
    final end = Offset(size.width - 2, size.height * 0.7);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(size.width / 2, y - 8, end.dx, end.dy);
    canvas.drawPath(path, ink);
    // 起点圆点
    canvas.drawCircle(start, 3.5, Paint()..color = AAColors.ink);
    // 箭头
    final angle = atan2(end.dy - y, end.dx - size.width / 2);
    canvas.drawLine(end, Offset(end.dx - 8 * cos(angle - 0.5), end.dy - 8 * sin(angle - 0.5)), ink);
    canvas.drawLine(end, Offset(end.dx - 8 * cos(angle + 0.5), end.dy - 8 * sin(angle + 0.5)), ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
