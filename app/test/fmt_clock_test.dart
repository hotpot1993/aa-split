// 可注入时钟（Fmt.clock）回归测试：
// 商店截图 golden 的「问候语/相对时间」依赖运行时刻（早上好/下午好/晚上好 跨小时漂移），
// 该缝让测试固定当前时刻，使 golden 跨时段稳定；此处验证缝本身按预期工作。
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/core/utils/format.dart';

void main() {
  tearDown(() {
    Fmt.clock = DateTime.now;
  });

  test('问候语：随注入时钟的时段变化', () {
    Fmt.clock = () => DateTime(2026, 8, 26, 3, 0);
    expect(Fmt.greeting(), '夜深啦');
    Fmt.clock = () => DateTime(2026, 8, 26, 9, 0);
    expect(Fmt.greeting(), '早上好');
    Fmt.clock = () => DateTime(2026, 8, 26, 12, 0);
    expect(Fmt.greeting(), '中午好');
    Fmt.clock = () => DateTime(2026, 8, 26, 15, 0);
    expect(Fmt.greeting(), '下午好');
    Fmt.clock = () => DateTime(2026, 8, 26, 21, 0);
    expect(Fmt.greeting(), '晚上好');
  });

  test('相对时间：以注入时钟为基准计算', () {
    Fmt.clock = () => DateTime(2026, 8, 26, 10, 30);
    expect(Fmt.relative(DateTime(2026, 8, 26, 10, 29, 30)), '刚刚');
    expect(Fmt.relative(DateTime(2026, 8, 26, 10, 0)), '30分钟前');
    expect(Fmt.relative(DateTime(2026, 8, 26, 9, 30)), '1小时前');
    expect(Fmt.relative(DateTime(2026, 8, 25, 10, 0)), '昨天');
    expect(Fmt.relative(DateTime(2026, 8, 24, 10, 0)), '2天前');
  });
}
