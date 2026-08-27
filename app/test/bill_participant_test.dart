import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/models/bill_participant.dart';

void main() {
  group('Receipt OCR 字段（fromJson 兼容旧服务端）', () {
    test('完整字段解析', () {
      final r = Receipt.fromJson({
        'id': 'r1',
        'billId': 'b1',
        'url': '/uploads/a.jpg',
        'amountCents': 8800,
        'confidence': 0.97,
        'currency': 'CNY',
        'ocrStatus': 'success',
      });
      expect(r.id, 'r1');
      expect(r.amountCents, 8800);
      expect(r.confidence, 0.97);
      expect(r.currency, 'CNY');
      expect(r.ocrStatus, 'success');
      expect(r.uploadId, isNull);
    });

    test('旧服务端响应（无 ocr 字段）默认 pending', () {
      final r = Receipt.fromJson({'id': 'r2', 'billId': 'b2', 'url': '🧾'});
      expect(r.ocrStatus, 'pending');
      expect(r.amountCents, isNull);
      expect(r.confidence, isNull);
      expect(r.currency, isNull);
    });

    test('confidence 数值类型（整型/浮点）都可用', () {
      final r = Receipt.fromJson({
        'id': 'r3',
        'billId': 'b3',
        'url': '/uploads/b.jpg',
        'confidence': 1,
      });
      expect(r.confidence, 1.0);
    });

    test('uploadId 预上传草稿字段', () {
      final r = Receipt.fromJson({
        'id': 'r4',
        'billId': '',
        'url': '/uploads/c.jpg',
        'uploadId': 'u-123',
        'ocrStatus': 'processing',
      });
      expect(r.uploadId, 'u-123');
      expect(r.ocrStatus, 'processing');
    });
  });
}
