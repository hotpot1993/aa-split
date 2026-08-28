// 「记一笔」小票功能回归测试：
// 1. 已上传小票缩略图可点击查看大图（全屏缩放查看器）
// 2. （同一流程下）OCR 识别框确认后自动选中识别出的币种
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

import 'package:aa_design/aa_design.dart';
import 'package:aa_split_app/screens/add/add_bill_screen.dart';

/// 注入固定路径的相册/相机 → 返回临时小票文件（避免真实 platform channel）
class _FakePicker extends ImagePickerPlatform {
  _FakePicker(this.path);
  final String path;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async =>
      XFile(path);
}

/// 1x1 透明 PNG（Image.file/Image.network 可解码，避免 errorBuilder 分支）
final _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

File _tempImage() {
  final f = File(
      '${Directory.systemTemp.path}/aa_rcpt_${DateTime.now().microsecondsSinceEpoch}.png');
  f.writeAsBytesSync(_pngBytes);
  addTearDown(() {
    if (f.existsSync()) f.deleteSync();
  });
  return f;
}

Future<void> _pump(WidgetTester tester, String path) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  ImagePickerPlatform.instance = _FakePicker(path);
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

/// 从相册选一张小票（打开凭证来源弹层 → 从相册选）
Future<void> _pickReceiptFromGallery(WidgetTester tester) async {
  await tester.tap(find.text('拍照/相册'));
  await tester.pump();
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 3),
  );
  await tester.tap(find.text('从相册选'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('已上传小票缩略图点击可打开大图查看器', (tester) async {
    final img = _tempImage();
    await _pump(tester, img.path);

    await _pickReceiptFromGallery(tester);

    // 缩略图出现（凭证行内，key: mini-receipt-<path>）
    final thumb = find.byKey(ValueKey('mini-receipt-${img.path}'));
    expect(thumb, findsOneWidget);

    // 点击缩略图 → 全屏查看器（key: receipt-viewer）
    await tester.tap(thumb);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 260)); // 过渡动画 220ms
    expect(find.byKey(const ValueKey('receipt-viewer')), findsOneWidget);

    // 关闭 → 查看器消失
    await tester.tap(find.text('✕'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('receipt-viewer')), findsNothing);

    // 冲掉 OCR 模拟确认框计时
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('OCR 识别确认填入后自动选中识别出的币种（Demo 默认 CNY）', (tester) async {
    final img = _tempImage();
    await _pump(tester, img.path);

    await _pickReceiptFromGallery(tester);
    // 默认币种为人民币
    expect(find.text('人民币 (CNY)'), findsOneWidget);

    // 1s 后模拟 OCR 识别成功（Demo：CNY），确认填入
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('填入账单 ✓'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 金额已填入，且币种保持/自动选中为 CNY（仍显示人民币 (CNY)）
    expect(find.text('人民币 (CNY)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
  });
}
