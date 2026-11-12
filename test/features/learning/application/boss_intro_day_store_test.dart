// Boss 入场日戳存储：当日标记读写、未初始化兜底、写失败降级不阻断。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/core/utils/boss_siege.dart';
import 'package:word_app/features/learning/application/boss_intro_day_store.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPreferences().init();
  });

  test('未初始化/无标记：readDay 返回空串（不抛错）', () {
    const store = BossIntroDayStore();
    expect(store.readDay(), '');
  });

  test('markDay 落库后 readDay 读回当日戳', () async {
    const store = BossIntroDayStore();
    final today = bossDayStamp(DateTime(2026, 11, 12));
    await store.markDay(today);
    expect(store.readDay(), today);
  });

  test('跨日：旧日戳不等于今天（入场可再演一次）', () async {
    const store = BossIntroDayStore();
    await store.markDay(bossDayStamp(DateTime(2026, 11, 11)));
    expect(store.readDay(), isNot(bossDayStamp(DateTime(2026, 11, 12))));
  });

  test('重复 markDay 幂等：同日写两次仍是一个日戳', () async {
    const store = BossIntroDayStore();
    final today = bossDayStamp(DateTime(2026, 11, 12));
    await store.markDay(today);
    await store.markDay(today);
    expect(store.readDay(), today);
  });

  test('写失败降级：markDay 不抛错（明天重演也无害）', () async {
    // 未初始化的 AppPreferences 写入会抛错；store 必须吞下并上报，不阻断复习。
    SharedPreferences.setMockInitialValues({});
    // 故意不 init，模拟写入失败现场。
    const store = BossIntroDayStore();
    await expectLater(store.markDay('2026-11-12'), completes);
  });
}
