import 'package:flutter/material.dart';

import 'package:aa_design/aa_design.dart';

import 'sheet.dart';

/// 单选弹层选项（[value] 为业务标识，[label]/[subtitle] 为展示文本）
class PickerOption<T> {
  const PickerOption(this.value, this.label, {this.subtitle});

  final T value;
  final String label;
  final String? subtitle;
}

/// 通用单选弹层：标题 + 可选搜索框 + 受限高度可滚动列表。
///
/// 用于替代原生 DropdownButton —— 选项列表将限制在当前屏高约 60% 内
/// 并可滚动（不再整屏下拉、选项过长）；选中项点击后立即返回。
Future<T?> showAaPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<PickerOption<T>> options,
  T? selected,
  bool searchable = false,
  String searchHint = '搜索',
}) {
  return showAaSheet<T>(
    context,
    maxHeight: 0.72,
    child: _PickerSheet<T>(
      title: title,
      options: options,
      selected: selected,
      searchable: searchable,
      searchHint: searchHint,
    ),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchable,
    required this.searchHint,
  });

  final String title;
  final List<PickerOption<T>> options;
  final T? selected;
  final bool searchable;
  final String searchHint;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PickerOption<T>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((o) =>
            o.label.toLowerCase().contains(q) ||
            (o.subtitle ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final opts = _filtered;
    // 列表高度：按项数自适应，但限制在弹层可用高度的 ~60% 内（避免选项过多整屏铺满）
    final screenH = MediaQuery.sizeOf(context).height;
    final maxList = screenH * 0.55;
    final listH = (opts.length * 52.0).clamp(80.0, maxList);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.title,
            style: TextStyle(fontFamily: AAFonts.title, fontSize: 18, color: AAColors.ink)),
        if (widget.searchable) ...[
          SizedBox(height: 12),
          HandTextField(
            controller: _search,
            hint: widget.searchHint,
            hintPrefixImage: 'assets/icons/search.png',
            onChanged: (v) => setState(() => _query = v),
          ),
        ],
        SizedBox(height: 10),
        if (opts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text('没有匹配的选项',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AAFonts.title, fontSize: 14, color: AAColors.inkSoft)),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AAColors.cardWhite,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AAColors.ink, width: 2),
            ),
            child: SizedBox(
              height: listH,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                itemCount: opts.length,
                itemBuilder: (context, i) {
                  final o = opts[i];
                  final on = o.value == widget.selected;
                  return GestureDetector(
                    onTap: () => Navigator.of(context).pop(o.value),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(o.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontFamily: AAFonts.title,
                                        fontSize: 15,
                                        color: on ? AAColors.ink : AAColors.ink)),
                                if (o.subtitle != null) ...[
                                  SizedBox(height: 2),
                                  Text(o.subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontFamily: AAFonts.title,
                                          fontSize: 12,
                                          color: AAColors.inkSoft)),
                                ],
                              ],
                            ),
                          ),
                          if (on) ...[
                            SizedBox(width: 8),
                            HandTag('✓', fontSize: 12, variant: ChipVariant.green),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        SizedBox(height: 4),
      ],
    );
  }
}
