import 'dart:async';
import 'dart:io' show File;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'package:aa_design/aa_design.dart';

import '../../core/utils/format.dart';
import '../../models/bill.dart';
import '../../models/group.dart';
import '../../models/transfer.dart';
import '../../providers/data_providers.dart';
import '../../providers/refresh_provider.dart';
import '../../providers/repositories.dart';
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
  bool _settling = false;

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
    final members = (ref.watch(groupMembersProvider).value ?? {})[widget.groupId] ?? [];
    final bills = ref.watch(billsProvider).value ?? const <Bill>[];
    final hasUnsettled = bills.any(
        (b) => b.groupId == widget.groupId && !b.fullySettled);

    return AaScaffold(
      appBar: AaAppBar(
        title: '一键智能结算',
        headIcon: 'assets/icons/sparkle.png',
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
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: AaIconImage('assets/icons/party.png', size: 24),
                  ),
                  TextSpan(
                      text: '最少 ',
                      style: TextStyle(
                          fontFamily: AAFonts.title, fontSize: 26, color: AAColors.ink)),
                  TextSpan(
                    text: '${transfers.length}',
                    style: TextStyle(
                        fontFamily: AAFonts.hand,
                        fontSize: 30,
                        color: AASemantic.amountNeg),
                  ),
                  TextSpan(
                      text: ' 笔清账！',
                      style: TextStyle(
                          fontFamily: AAFonts.title, fontSize: 26, color: AAColors.ink)),
                ])),
                SizedBox(height: 4),
                Text('团团帮你算好了，按这个转就行',
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
              ],
            ),
          ),
          SizedBox(height: 16),
          if (transfers.isEmpty)
            EmptyState(
              title: '全群已清账，两不相欠啦 🎉',
              subtitle: '这笔不用再转了',
              tag: '已清账 🎉',
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
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DoodleButton(
                  label: '复制转账文案',
                  leadingImage: 'assets/icons/chat.png',
                  type: DoodleButtonType.ghost,
                  mini: true,
                  expand: true,
                  onPressed: () => _copyPlan(transfers),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: DoodleButton(
                  label: '收款卡片',
                  leadingImage: 'assets/icons/phone.png',
                  type: DoodleButtonType.ghost,
                  mini: true,
                  expand: true,
                  onPressed: () => _genCard(transfers),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          DoodleButton(
            label: '开始催款',
            leadingImage: 'assets/icons/broadcast.png',
            big: true,
            onPressed: () => context.push('/groups/${widget.groupId}/remind'),
          ),
          SizedBox(height: 10),
          DoodleButton(
            label: _settling ? '结清中…' : '一键结清（全部标记已付）',
            leadingImage: _settling ? null : 'assets/icons/check.png',
            type: DoodleButtonType.danger,
            big: true,
            onPressed: hasUnsettled && !_settling ? _settleAll : null,
          ),
          SizedBox(height: 10),
          // 模式切换提示（Demo 底部 mini dim 文案）
          InkWell(
            onTap: () => setState(() => _perBill = !_perBill),
            child: Text.rich(TextSpan(
              children: [
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: AaIconImage('assets/icons/swap.png', size: 14),
                ),
                TextSpan(
                  text: _perBill
                      ? ' 已选：逐笔结算模式 · 切换到最少笔数'
                      : ' 已选：最少笔数模式 · 切换到逐笔结算',
                ),
              ],
              style: TextStyle(
                  fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft),
            )),
          ),
          SizedBox(height: 16),
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

  /// 收款卡片：把当前结算方案渲染成图片并保存到手机本地。
  /// 卡片先挂在 Overlay 屏幕外（保证完成布局与绘制），RepaintBoundary 截屏后保存 PNG。
  Future<void> _genCard(List<Transfer> transfers) async {
    if (transfers.isEmpty) {
      showAaToast(context, '全群已清账，没有可生成的结算方案');
      return;
    }
    final groupName = _groupName();
    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -2400,
        top: 0,
        child: RepaintBoundary(
          key: key,
          child: _PaymentCard(
            transfers: transfers,
            groupName: groupName,
            groupId: widget.groupId,
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    await WidgetsBinding.instance.endOfFrame;
    try {
      final boundary = key.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw StateError('图片编码失败');
      // 优先应用专属外部目录（用户可直接看到）；iOS 等回退 Documents
      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/aa-settlement-${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(bytes.buffer.asUint8List());
      if (!mounted) return;
      showAaToast(context, '📱 收款卡片已保存到本地');
      unawaited(OpenFilex.open(path));
    } catch (e) {
      if (mounted) showAaToast(context, '生成收款卡片失败：$e');
    } finally {
      entry.remove();
    }
  }

  String _groupName() {
    for (final g in ref.read(groupsProvider).value ?? const <Group>[]) {
      if (g.id == widget.groupId) return g.name;
    }
    return '';
  }

  /// 一键结清：确认后把群内全部未结清账单标记为已付
  Future<void> _settleAll() async {
    final ok = await showAaConfirm(
      context,
      title: '一键结清全部账单？',
      subtitle: '本群所有未结清账单将统一标记为「已付」，结算方案随之清空',
      confirmLabel: '一键结清',
    );
    if (ok != true || !mounted) return;
    setState(() => _settling = true);
    try {
      final n = await ref.read(billRepositoryProvider).settleAll(widget.groupId);
      if (!mounted) return;
      ref.read(refreshProvider.notifier).bump();
      showAaToast(context, n > 0 ? '🎉 已结清 $n 笔账单' : '本群已清账啦');
    } catch (e) {
      if (mounted) showAaToast(context, '结清失败：$e');
    } finally {
      if (mounted) setState(() => _settling = false);
    }
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
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${transfer.fromName} → ${transfer.toName}',
                    style: TextStyle(
                        fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
                SizedBox(height: 2),
                HandAmount(amountCents: transfer.amountCents, color: AAColors.ink, size: 30),
                Text(
                  _note(),
                  style: TextStyle(
                      fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft),
                ),
              ],
            ),
          ),
          SizedBox(width: 6),
          CustomPaint(
            size: Size(44, 26),
            painter: _ArrowSvgPainter(),
          ),
          SizedBox(width: 8),
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

/// 收款卡片（截屏对象）：手绘纸卡样式，包含结算方案摘要 + 转账明细（不含二维码）。
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.transfers,
    required this.groupName,
    required this.groupId,
  });

  final List<Transfer> transfers;
  final String groupName;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final total = transfers.fold<int>(0, (s, t) => s + t.amountCents);
    final now = Fmt.clock();
    return Container(
      width: 300,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: AAColors.cardWhite,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(14),
        ),
        border: Border.all(color: AAColors.ink, width: 2.5),
        boxShadow: [AATokens.cardShadow],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('收款卡片',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AAFonts.title, fontSize: 20, color: AAColors.ink)),
          SizedBox(height: 2),
          Text('AA分账 · 一键智能结算方案',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AAFonts.title, fontSize: 12, color: AAColors.inkSoft)),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AaIconImage('assets/icons/group.png', size: 16),
              SizedBox(width: 6),
              Flexible(
                child: Text(groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontFamily: AAFonts.title,
                        fontSize: 16,
                        color: AAColors.ink)),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text('共 ${transfers.length} 笔 · 合计 ${Fmt.yuan(total)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AAFonts.title, fontSize: 13, color: AAColors.ink)),
          SizedBox(height: 10),
          ...transfers.take(8).map((t) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Text('${t.fromName} → ${t.toName}',
                        style: TextStyle(
                            fontFamily: AAFonts.title,
                            fontSize: 13,
                            color: AAColors.ink)),
                    Spacer(),
                    Text(Fmt.yuan(t.amountCents, trimZero: true),
                        style: TextStyle(
                            fontFamily: AAFonts.currency,
                            fontSize: 14,
                            color: AASemantic.amountNeg)),
                  ],
                ),
              )),
          if (transfers.length > 8)
            Text('… 等共 ${transfers.length} 笔',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AAFonts.title,
                    fontSize: 11,
                    color: AAColors.inkSoft)),
          SizedBox(height: 10),
          Text('截图/转发给朋友 · 资金请走微信/支付宝',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AAFonts.title,
                  fontSize: 11,
                  color: AAColors.inkSoft)),
          SizedBox(height: 2),
          Text(getFormattedNow(now),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: AAFonts.accent,
                  fontSize: 12,
                  color: AAColors.inkSoft)),
        ],
      ),
    );
  }

  static String getFormattedNow(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')} '
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
}
