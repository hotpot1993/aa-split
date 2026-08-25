// 邀请链接解析 + 扫一扫/链接入群（Demo 模式）单元测试
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/core/api/api_client.dart';
import 'package:aa_split_app/core/invite_link.dart';
import 'package:aa_split_app/data/repositories/group_repository.dart';

void main() {
  group('parseInviteCode（邀请链接 → 群码）', () {
    test('深链标准格式 aafen://join/群码', () {
      expect(parseInviteCode('aafen://join/FAN12345'), 'FAN12345');
    });

    test('https 分享页', () {
      expect(parseInviteCode('https://aafen.com/join/HEZU8888'), 'HEZU8888');
    });

    test('带查询参数/锚点', () {
      expect(
        parseInviteCode('https://aafen.com/join/HEZU8888?from=share#x'),
        'HEZU8888',
      );
    });

    test('invite 前缀 + 域名', () {
      expect(parseInviteCode('https://aafen.cn/invite/HEZU8888'), 'HEZU8888');
    });

    test('裸群码直接可用', () {
      expect(parseInviteCode('CAMP0001'), 'CAMP0001');
    });

    test('大小写宽容（解析阶段保留原样，由仓库层归一化）', () {
      expect(parseInviteCode('aafen://join/fan12345'), 'fan12345');
    });

    test('首尾空格/换行容忍', () {
      expect(parseInviteCode('  aafen://join/FAN12345 \n'), 'FAN12345');
    });

    test('尾部斜杠容忍', () {
      expect(parseInviteCode('aafen://join/FAN12345/'), 'FAN12345');
    });

    test('空输入 / 纯空白返回 null', () {
      expect(parseInviteCode(''), isNull);
      expect(parseInviteCode('   '), isNull);
      expect(parseInviteCode(null), isNull);
    });

    test('非法字符 / 超长 token 返回 null', () {
      expect(parseInviteCode('不是链接也非群码'), isNull);
      expect(parseInviteCode('aafen://join/CODE_WITH_下划线'), isNull);
      expect(parseInviteCode('aafen://join/ABCDEF1234567'), isNull);
    });
  });

  group('GroupRepository.join（Demo 模式）', () {
    test('群码匹配返回群组信息（已在群中）', () async {
      // 与页面流程一致：先解析链接得到群码，再入群
      final code = parseInviteCode('aafen://join/FAN12345')!;
      final r = await GroupRepository().join(code);
      expect(r.id, 'g1');
      expect(r.name, '饭友群');
      expect(r.alreadyJoined, isTrue);
    });

    test('大小写宽容：小写群码同样可加入', () async {
      final r = await GroupRepository().join('fan12345');
      expect(r.id, 'g1');
    });

    test('无效群码抛出 ApiException', () async {
      expect(
        () => GroupRepository().join('NOPE0000'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}
