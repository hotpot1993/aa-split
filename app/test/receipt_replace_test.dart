// 回归：凭证图片替换（重新拍照/相册换图）—— Demo 模式
import 'package:flutter_test/flutter_test.dart';

import 'package:aa_split_app/data/mock/mock_store.dart';
import 'package:aa_split_app/data/repositories/bill_repository.dart';

void main() {
  test('replaceReceipt：同 id 换图，其它凭证不受影响', () async {
    final store = MockStore.instance;
    final repo = BillRepository();

    // b2 只有一张凭证 r_b2_0（🧾 占位）
    final before = store.billById('b2')!;
    expect(before.receipts.length, 1);

    final r = await repo.replaceReceipt('b2', 'r_b2_0', r'C:\tmp\new-receipt.jpg');
    expect(r.id, 'r_b2_0');
    expect(r.url, r'C:\tmp\new-receipt.jpg');

    final after = store.billById('b2')!;
    expect(after.receipts.length, 1);
    expect(after.receipts.single.id, 'r_b2_0');
    expect(after.receipts.single.url, r'C:\tmp\new-receipt.jpg');
  });

  test('replaceReceipt：凭证不存在时报错', () async {
    expect(
      () => BillRepository().replaceReceipt('b2', 'nope', 'x.jpg'),
      throwsUnsupportedError,
    );
  });
}
