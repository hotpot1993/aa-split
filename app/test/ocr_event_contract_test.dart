import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/providers/notification_stream_provider.dart';

/// SSE receipt-ocr 事件契约：服务端按 SsePayload 信封推送
/// （type 在顶层、识别结果在 data 内），客户端分流时摊平到顶层，
/// 页面 `_onOcrEvent` 才能直接读取 kind/receiptId/uploadId/amountCents 等。
void main() {
  group('flattenOcrEvent（SSE receipt-ocr 信封摊平）', () {
    test('p33 成功事件：data 内字段提升到顶层，type/ref 保留', () {
      final e = flattenOcrEvent({
        'type': 'receipt-ocr',
        'title': '',
        'body': '',
        'refType': 'bill',
        'refId': 'b1',
        'data': {
          'kind': 'p33',
          'receiptId': 'r1',
          'billId': 'b1',
          'amountCents': 8800,
          'currency': 'CNY',
          'confidence': 0.97,
          'method': 'keyword',
        },
      });
      expect(e['type'], 'receipt-ocr');
      expect(e['refId'], 'b1');
      expect(e['kind'], 'p33');
      expect(e['receiptId'], 'r1');
      expect(e['billId'], 'b1');
      expect(e['amountCents'], 8800);
      expect(e['currency'], 'CNY');
      expect(e['confidence'], 0.97);
    });

    test('preupload 失败事件：uploadId 提升 + ocrStatus=failed', () {
      final e = flattenOcrEvent({
        'type': 'receipt-ocr',
        'title': '',
        'body': '',
        'refType': null,
        'refId': null,
        'data': {
          'kind': 'preupload',
          'uploadId': 'u1',
          'amountCents': null,
          'currency': null,
          'confidence': null,
          'ocrStatus': 'failed',
          'error': 'ocr-worker 502',
        },
      });
      expect(e['type'], 'receipt-ocr');
      expect(e['kind'], 'preupload');
      expect(e['uploadId'], 'u1');
      expect(e['amountCents'], isNull);
      expect(e['ocrStatus'], 'failed');
      expect(e['error'], 'ocr-worker 502');
    });

    test('无 data 的旧事件：原样返回', () {
      final e = flattenOcrEvent({'type': 'remind', 'refId': 'b1'});
      expect(e['type'], 'remind');
      expect(e['refId'], 'b1');
      expect(e['kind'], isNull);
    });
  });
}