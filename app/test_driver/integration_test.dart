// flutter drive 驱动：接收真机 integration_test 的逐屏截图并落盘。
//
// 截图目录：环境变量 SCREENSHOT_DIR（未设置时回退到当前目录下 screenshots/）。
import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final dir = Platform.environment['SCREENSHOT_DIR'] ?? 'screenshots';
  stdout.writeln('[driver] screenshot dir = $dir');
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('$dir/$name.png');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      return true;
    },
  );
}
