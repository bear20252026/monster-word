// 第四轮审计 M18（2026-11-17）：恢复后缓存复位总线测试。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/application/restore_cache_reset.dart';

void main() {
  setUp(RestoreCacheResetBus.clearForTest);
  tearDown(RestoreCacheResetBus.clearForTest);

  test('登记幂等：同一回调不重复执行', () async {
    var calls = 0;
    Future<void> cb() async => calls++;
    RestoreCacheResetBus.register(cb);
    RestoreCacheResetBus.register(cb);
    await RestoreCacheResetBus.runAll();
    expect(calls, 1);
  });

  test('逆序执行：后登记的先复位', () async {
    final order = <int>[];
    RestoreCacheResetBus.register(() async => order.add(1));
    RestoreCacheResetBus.register(() async => order.add(2));
    await RestoreCacheResetBus.runAll();
    expect(order, [2, 1]);
  });

  test('单个回调抛错不中断其余（尽力通知）', () async {
    var ran = false;
    RestoreCacheResetBus.register(() async => ran = true);
    RestoreCacheResetBus.register(() async => throw StateError('boom'));
    await RestoreCacheResetBus.runAll();
    expect(ran, isTrue);
  });

  test('退订后不再执行', () async {
    var calls = 0;
    Future<void> cb() async => calls++;
    RestoreCacheResetBus.register(cb);
    RestoreCacheResetBus.unregister(cb);
    await RestoreCacheResetBus.runAll();
    expect(calls, 0);
  });
}
