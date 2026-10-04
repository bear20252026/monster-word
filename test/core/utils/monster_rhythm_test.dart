// MonsterRhythm 昼夜节律真值表（W4.5 宠物化）。
//
// 关键回归面：窗口与 SfxPlayer 夜间 -6dB（h>=22 || h<6）对齐——
// 改窗口必须两处同步，否则「它睡了但声音没轻」。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/monster_rhythm.dart';

void main() {
  tearDown(MonsterRhythm.resetForTest);

  test('窗口边界：22:00 入睡（含）、6:00 醒来（不含）', () {
    expect(MonsterRhythm.isSleepTime(DateTime(2026, 10, 4, 21, 59)), isFalse);
    expect(MonsterRhythm.isSleepTime(DateTime(2026, 10, 4, 22, 0)), isTrue);
    expect(MonsterRhythm.isSleepTime(DateTime(2026, 10, 4, 23, 30)), isTrue);
    expect(MonsterRhythm.isSleepTime(DateTime(2026, 10, 4, 3, 0)), isTrue);
    expect(MonsterRhythm.isSleepTime(DateTime(2026, 10, 4, 5, 59)), isTrue);
    expect(MonsterRhythm.isSleepTime(DateTime(2026, 10, 4, 6, 0)), isFalse);
    expect(MonsterRhythm.isSleepTime(DateTime(2026, 10, 4, 12, 0)), isFalse);
  });

  test('时钟注入：nowOverride 决定 now() 与 isSleepTime 的默认时刻', () {
    MonsterRhythm.nowOverride = () => DateTime(2026, 10, 4, 23);
    expect(MonsterRhythm.now().hour, 23);
    expect(MonsterRhythm.isSleepTime(), isTrue);

    MonsterRhythm.nowOverride = () => DateTime(2026, 10, 4, 10);
    expect(MonsterRhythm.isSleepTime(), isFalse);
  });

  test('显式传入时刻时不读时钟', () {
    MonsterRhythm.nowOverride = () => DateTime(2026, 10, 4, 23);
    expect(MonsterRhythm.isSleepTime(DateTime(2026, 10, 4, 9)), isFalse);
  });

  test('resetForTest 清除注入（防跨测试文件污染）', () {
    MonsterRhythm.nowOverride = () => DateTime(2026, 1, 1);
    MonsterRhythm.resetForTest();
    final now = MonsterRhythm.now();
    expect(now.year, DateTime.now().year, reason: '清除后回落真实墙钟');
  });
}
