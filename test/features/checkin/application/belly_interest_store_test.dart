// 肚皮计息存储：单键 JSON、同日结算闸门、损坏兜底、时间注入。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/checkin/application/belly_interest_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();
  });

  test('首次：无在场记录、未结算', () {
    final store = BellyInterestStore(now: () => DateTime(2026, 11, 12, 9));
    expect(store.lastSeen(), isNull);
    expect(store.settledToday(), isFalse);
  });

  test('markSeen 落标后可读回在场时刻', () async {
    final store = BellyInterestStore(now: () => DateTime(2026, 11, 12, 9));
    expect(await store.markSeen(), isTrue);
    expect(store.lastSeen(), DateTime(2026, 11, 12, 9));
    // markSeen 不动结算闸门。
    expect(store.settledToday(), isFalse);
  });

  test('markSettled：当日闸门生效，跨日自动放开', () async {
    var clock = DateTime(2026, 11, 12, 9);
    final store = BellyInterestStore(now: () => clock);
    await store.markSettled();
    expect(store.settledToday(), isTrue);
    expect(store.eventKeyForToday(), 'belly_interest:2026-11-12');
    // 同日重进页面仍被闸门拦住。
    clock = DateTime(2026, 11, 12, 21);
    expect(store.settledToday(), isTrue);
    // 次日闸门放开，幂等键换新。
    clock = DateTime(2026, 11, 13, 8);
    expect(store.settledToday(), isFalse);
    expect(store.eventKeyForToday(), 'belly_interest:2026-11-13');
  });

  test('值损坏整段丢弃按首次处理（宁可少发不可错发）', () async {
    SharedPreferences.setMockInitialValues({BellyInterestStore.stateKey: '{broken json'});
    await AppPreferences().init();
    final store = BellyInterestStore(now: () => DateTime(2026, 11, 12, 9));
    expect(store.lastSeen(), isNull);
    expect(store.settledToday(), isFalse);
  });

  test('非 Map 的合法 JSON 同样按首次处理', () async {
    SharedPreferences.setMockInitialValues({BellyInterestStore.stateKey: '[1,2,3]'});
    await AppPreferences().init();
    final store = BellyInterestStore(now: () => DateTime(2026, 11, 12, 9));
    expect(store.lastSeen(), isNull);
  });
}
