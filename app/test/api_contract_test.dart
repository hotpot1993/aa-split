import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aa_split_app/core/api/api_client.dart';
import 'package:aa_split_app/core/config.dart';
import 'package:aa_split_app/data/repositories/auth_repository.dart';
import 'package:aa_split_app/data/repositories/bill_repository.dart';
import 'package:aa_split_app/data/repositories/group_repository.dart';
import 'package:aa_split_app/data/repositories/notification_repository.dart';
import 'package:aa_split_app/data/repositories/settlement_repository.dart';
import 'package:aa_split_app/models/bill.dart';
import 'package:aa_split_app/models/bill_participant.dart';
import 'package:aa_split_app/models/notification_item.dart';

/// 仓库层契约测试（AA_USE_MOCK=false 下运行）：
/// 运行方式：flutter test --dart-define=AA_USE_MOCK=false test/api_contract_test.dart
///
/// 用内嵌 MockAdapter 完整模拟服务端 {code,message,data} 信封，
/// 校验各仓库：① 请求路径/方法/载荷正确 ② 服务端响应正确解析为客户端模型。

class MockAdapter implements HttpClientAdapter {
  MockAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;

  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(Object body) => ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Object ok(dynamic data) => {'code': 0, 'message': 'ok', 'data': data};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Demo 模式下不执行（本文件真实模式契约测试：
  // 需 flutter test --dart-define=AA_USE_MOCK=false 运行）
  if (AppConfig.useMock) {
    test('契约测试（AA_USE_MOCK=false 时执行）', () {},
        skip: '当前为 Demo 模式；请用 --dart-define=AA_USE_MOCK=false 运行');
    return;
  }

  late MockAdapter adapter;
  late Dio dio;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adapter = MockAdapter((_) async => json(ok(const <Object>[])));
    dio = ApiClient.instance.dio;
    dio.httpClientAdapter = adapter;
    ApiClient.instance.setToken(null);
  });

  group('AuthRepository（真实模式）', () {
    test('login：POST /auth/login，解析用户并持久化会话', () async {
      adapter = MockAdapter((options) async {
        expect(options.method, 'POST');
        expect(options.path, '/auth/login');
        final body = options.data;
        expect(body['accountName'], 'tuanzi');
        expect(body['password'], 'abc123ABC');
        return json(ok({
          'accessToken': 'tok_1',
          'refreshToken': 'ref_1',
          'user': {
            'id': 'u1',
            'accountName': 'tuanzi',
            'nickname': '团子酱',
            'avatarUrl': null,
            'bio': null,
          },
        }));
      });
      dio.httpClientAdapter = adapter;

      final user = await AuthRepository().login('tuanzi', 'abc123ABC');
      expect(user.id, 'u1');
      expect(user.nickname, '团子酱');
      expect(user.avatarUrl, '🐼'); // null 兜底
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('aa.token'), 'tok_1');
    });

    test('restoreSession：带 token 调 /auth/me；失败则清理', () async {
      SharedPreferences.setMockInitialValues({
        'aa.token': 'tok_stale',
        'aa.user': '{"id":"u1","accountName":"tuanzi","nickname":"团子酱"}',
      });
      adapter = MockAdapter((options) async {
        expect(options.headers['Authorization'], 'Bearer tok_stale');
        return json(ok({
          'id': 'u1',
          'accountName': 'tuanzi',
          'nickname': '团子酱',
          'avatarUrl': null,
          'bio': null,
          'createdAt': '2026-08-01T00:00:00.000Z',
        }));
      });
      dio.httpClientAdapter = adapter;

      final user = await AuthRepository().restoreSession();
      expect(user?.accountName, 'tuanzi');

      // 401 → 清理本地会话并返回 null
      adapter = MockAdapter((_) async => ResponseBody.fromString(
            jsonEncode({'code': 401, 'message': '登录过期'}),
            401,
          ));
      dio.httpClientAdapter = adapter;
      expect(await AuthRepository().restoreSession(), isNull);
    });

    test('securityQuestionOf：GET /auth/security-question 解析问题文本', () async {
      adapter = MockAdapter((options) async {
        expect(options.method, 'GET');
        expect(options.path, '/auth/security-question');
        expect(options.queryParameters['accountName'], 'tuanzi');
        return json(ok({'question': '你第一个朋友的名字？'}));
      });
      dio.httpClientAdapter = adapter;

      final q = await AuthRepository().securityQuestionOf('tuanzi');
      expect(q, '你第一个朋友的名字？');
    });

    test('login：请求体携带真实设备快照 deviceInfo', () async {
      adapter = MockAdapter((options) async {
        expect(options.method, 'POST');
        expect(options.path, '/auth/login');
        final di = (options.data as Map)['deviceInfo'] as Map;
        expect(di['deviceId'], isNotEmpty); // 持久化设备标识
        expect(di['deviceName'], isNotEmpty); // 机型（测试环境回退为平台名）
        expect(di['platform'], isNotEmpty);
        expect(di['osVersion'], isNotEmpty);
        return json(ok({
          'accessToken': 'tok_dev',
          'user': {
            'id': 'u1',
            'accountName': 'tuanzi',
            'nickname': '团子酱',
          },
        }));
      });
      dio.httpClientAdapter = adapter;

      final user = await AuthRepository().login('tuanzi', 'abc123ABC');
      expect(user.id, 'u1');
    });

    test('listDevices：上报后拉取解析；上报接口失败不阻塞列表', () async {
      // ① 正常链路：POST /auth/devices（上报）→ GET /auth/devices（解析）
      adapter = MockAdapter((options) async {
        if (options.method == 'POST') {
          expect(options.path, '/auth/devices');
          return json(ok({'success': true}));
        }
        expect(options.path, '/auth/devices');
        return json(ok([
          {
            'id': 'd1',
            'deviceId': 'dev-a',
            'deviceName': 'Xiaomi 2509FPN0BC',
            'platform': 'android',
            'osVersion': '17',
            'ip': '1.2.3.4',
            'lastLoginAt': '2026-08-25T16:06:07.000Z',
          },
          {
            'id': 'd2',
            'deviceId': 'dev-b',
            'deviceName': '旧手机',
            'platform': 'ios',
            'osVersion': '18',
            'ip': null,
            'lastLoginAt': null,
          },
        ]));
      });
      dio.httpClientAdapter = adapter;

      final list = await AuthRepository().listDevices();
      expect(list, hasLength(2));
      expect(list[0].deviceName, 'Xiaomi 2509FPN0BC');
      expect(list[0].lastLoginAt, isNotNull);
      expect(list[1].lastLoginAt, isNull);

      // ② 上报接口 500 → 列表仍正常返回（容错，不出现「暂无」假象）
      adapter = MockAdapter((options) async {
        if (options.method == 'POST') {
          return ResponseBody.fromString(
            jsonEncode({'code': 500, 'message': 'boom'}),
            500,
          );
        }
        return json(ok([
          {
            'id': 'd1',
            'deviceId': 'dev-a',
            'deviceName': 'Xiaomi 2509FPN0BC',
            'platform': 'android',
            'osVersion': '17',
            'lastLoginAt': '2026-08-25T16:06:07.000Z',
          },
        ]));
      });
      dio.httpClientAdapter = adapter;

      final list2 = await AuthRepository().listDevices();
      expect(list2, hasLength(1));
      expect(list2[0].deviceName, 'Xiaomi 2509FPN0BC');
    });

    test('updateProfile：PATCH /auth/me 载荷正确并同步本地会话', () async {
      adapter = MockAdapter((options) async {
        expect(options.method, 'PATCH');
        expect(options.path, '/auth/me');
        final body = options.data as Map;
        expect(body['nickname'], '新团子');
        expect(body['bio'], '');
        expect(body.containsKey('avatarUrl'), false); // 未传则不发送
        return json(ok({
          'id': 'u1',
          'accountName': 'tuanzi',
          'nickname': '新团子',
          'avatarUrl': null,
          'bio': null,
        }));
      });
      dio.httpClientAdapter = adapter;
      // 已有会话（token 存在）→ 更新后同步回本地存储
      SharedPreferences.setMockInitialValues({'aa.token': 'tok_1'});

      final user = await AuthRepository().updateProfile(nickname: '新团子', bio: '');
      expect(user.nickname, '新团子');
      expect(user.bio, '');
      // 本地会话已同步（token 仍在 → _saveSession 写回新资料）
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('aa.user'), contains('新团子'));
    });
  });

  group('GroupRepository（真实模式）', () {
    test('list：GET /groups + 每群账单派生统计', () async {
      adapter = MockAdapter((options) async {
        if (options.path == '/groups') {
          return json(ok([
            {
              'id': 'g1',
              'name': '饭友群',
              'avatarUrl': null,
              'intro': null,
              'ownerId': 'u1',
              'defaultSplitType': 'even',
              'inviteCode': '',
              'memberCount': 2,
              'joinedAt': '2026-08-01T00:00:00.000Z',
            },
          ]));
        }
        if (options.path == '/groups/g1/bills') {
          return json(ok({
            'list': [
              {
                'id': 'b1',
                'groupId': 'g1',
                'title': '火锅',
                'location': null,
                'amountCents': 22000,
                'billDate': '2026-08-20',
                'category': 'food',
                'splitType': 'even',
                'settleStatus': 'partial',
                'isRegular': false,
                'creator': {'id': 'u1', 'accountName': 'tuanzi', 'nickname': '团子酱', 'avatarUrl': null},
                'payer': {'id': 'u1', 'accountName': 'tuanzi', 'nickname': '团子酱', 'avatarUrl': null},
                'participants': [
                  {'userId': 'u1', 'shareAmountCents': 11000, 'exempt': false, 'paid': true, 'remindCount': 0, 'user': {'id': 'u1', 'nickname': '团子酱'}},
                  {'userId': 'u2', 'shareAmountCents': 11000, 'exempt': false, 'paid': false, 'remindCount': 1, 'user': {'id': 'u2', 'nickname': '阿虎'}},
                ],
                'createdAt': '2026-08-20T12:00:00.000Z',
              },
            ],
            'total': 1,
            'page': 1,
            'pageSize': 100,
          }));
        }
        fail('意外请求: ${options.method} ${options.path}');
      });
      dio.httpClientAdapter = adapter;

      final groups = await GroupRepository().list();
      expect(groups, hasLength(1));
      expect(groups.first.name, '饭友群');
      expect(groups.first.pendingBillCount, 1);
      expect(groups.first.totalCents, 22000);
      expect(groups.first.recentBillTitle, '火锅');
    });
  });

  group('BillRepository（真实模式）', () {
    test('create：POST /bills 载荷含参与人分摊；markPaid/remind 正确路径', () async {
      adapter = MockAdapter((options) async {
        if (options.method == 'POST' && options.path == '/bills') {
          final body = options.data;
          expect(body['amountCents'], 22000);
          expect(body['participants'], hasLength(2));
          expect(body['splitType'], 'even');
          return json(ok({
            'id': 'b2',
            'groupId': body['groupId'],
            'title': body['title'],
            'amountCents': body['amountCents'],
            'billDate': body['billDate'],
            'category': body['category'],
            'splitType': body['splitType'],
            'settleStatus': 'partial',
            'creator': {'id': 'u1', 'nickname': '团子酱'},
            'payer': {'id': 'u1', 'nickname': '团子酱'},
            'participants': [],
            'isRegular': false,
          }));
        }
        if (options.method == 'POST' && options.path.endsWith('/mark-paid')) {
          final body = options.data;
          expect(body['userId'], 'u2');
          expect(body['paid'], true);
          return json(ok({'success': true, 'paid': true, 'paidAt': null}));
        }
        if (options.method == 'POST' && options.path.endsWith('/remind')) {
          return json(ok({'success': true, 'remindedCount': 1}));
        }
        fail('意外请求: ${options.method} ${options.path}');
      });
      dio.httpClientAdapter = adapter;

      final repo = BillRepository();
      final bill = await repo.create(
        groupId: 'g1',
        groupName: '饭友群',
        title: '火锅',
        amountCents: 22000,
        billDate: DateTime(2026, 8, 20),
        category: BillCategory.food,
        payerId: 'u1',
        payerName: '团子酱',
        participants: [
          BillParticipant(userId: 'u1', nickname: '团子酱', shareAmountCents: 11000, paid: true),
          BillParticipant(userId: 'u2', nickname: '阿虎', shareAmountCents: 11000, paid: false),
        ],
      );
      expect(bill.id, 'b2');
      expect(bill.groupName, '饭友群');

      await repo.markPaid('b2', 'u2', true);
      await repo.remind('b2', ['u2'], '快还钱');
    });
  });

  group('SettlementRepository（真实模式）', () {
    test('compute：解析服务端方案并用成员名补全姓名', () async {
      adapter = MockAdapter((options) async {
        if (options.path == '/groups/g1/settlement') {
          return json(ok({
            'transferCount': 1,
            'transfers': [
              {
                'fromUserId': 'u2',
                'toUserId': 'u1',
                'amountCents': 11000,
                'billIds': ['b1'],
              },
            ],
            'settlementIds': ['s1'],
          }));
        }
        if (options.path == '/groups/g1') {
          return json(ok({
            'id': 'g1',
            'name': '饭友群',
            'ownerId': 'u1',
            'defaultSplitType': 'even',
            'inviteCode': 'ABCDEF123456',
            'memberCount': 2,
            'members': [
              {'userId': 'u1', 'accountName': 'tuanzi', 'nickname': '团子酱', 'status': 'active'},
              {'userId': 'u2', 'accountName': 'ahu', 'nickname': '阿虎', 'status': 'active'},
            ],
          }));
        }
        fail('意外请求: ${options.method} ${options.path}');
      });
      dio.httpClientAdapter = adapter;

      final plan = await SettlementRepository().compute('g1');
      expect(plan.transferCount, 1);
      expect(plan.transfers.single.fromName, '阿虎');
      expect(plan.transfers.single.toName, '团子酱');
      expect(plan.transfers.single.amountCents, 11000);
    });
  });

  group('NotificationRepository（真实模式）', () {
    test('list/unreadCount/markAllRead 路径与解析', () async {
      adapter = MockAdapter((options) async {
        switch (options.path) {
          case '/notifications':
            return json(ok({
              'list': [
                {
                  'id': 'n1',
                  'type': 'remind',
                  'title': '催款提醒',
                  'body': '快还钱',
                  'refType': 'bill',
                  'refId': 'b1',
                  'isRead': false,
                  'createdAt': '2026-08-24T08:00:00.000Z',
                },
              ],
              'total': 1,
              'page': 1,
              'pageSize': 100,
            }));
          case '/notifications/unread-count':
            return json(ok({'count': 1}));
          case '/notifications/read-all':
            return json(ok({'updated': 1}));
          default:
            fail('意外请求: ${options.method} ${options.path}');
        }
      });
      dio.httpClientAdapter = adapter;

      final repo = NotificationRepository();
      final items = await repo.list();
      expect(items.single.type, NotifyType.remind);
      expect(items.single.title, '催款提醒');
      expect(await repo.unreadCount(), 1);
      await repo.markAllRead();
    });

    test('sseEvents：GET /notifications/stream 解析 data: 帧，断流后自动重连', () async {
      var calls = 0;
      adapter = MockAdapter((options) async {
        expect(options.path, '/notifications/stream');
        expect(options.headers['Accept'], 'text/event-stream');
        calls++;
        if (calls == 1) {
          final payload = jsonEncode({
            'type': 'remind',
            'title': '催款提醒',
            'body': '快还钱呀',
            'refType': 'bill',
            'refId': 'b1',
          });
          final frame = 'data: $payload\n\n: ping\n\n';
          return ResponseBody(
            Stream.value(Uint8List.fromList(utf8.encode(frame))),
            200,
            headers: {Headers.contentTypeHeader: ['text/event-stream']},
          );
        }
        // 第二次连接返回空流（模拟服务端断开）→ 循环继续等待重连
        return ResponseBody(Stream<Uint8List>.empty(), 200);
      });
      dio.httpClientAdapter = adapter;

      final repo = NotificationRepository();
      final done = Completer<void>();
      final sub = repo.sseEvents().listen((e) {
        expect(e['type'], 'remind');
        expect(e['title'], '催款提醒');
        expect(e['refId'], 'b1');
        if (!done.isCompleted) done.complete();
      }, onError: (_) {});
      await done.future.timeout(const Duration(seconds: 5));
      await sub.cancel();
      expect(calls, greaterThanOrEqualTo(1));
    });
  });
}
