// MonsterMoodResolver 表驱动：四档全覆盖 + 边界 + 回归优先 + 缺数据降级。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/application/monster_mood.dart';

void main() {
  group('MonsterMoodResolver.resolve', () {
    test('到期积压分级', () {
      expect(MonsterMoodResolver.resolve(dueCount: 1, todayCombo: 0, returnedAfterGap: false), MonsterMood.sleepy);
      expect(
        MonsterMoodResolver.resolve(dueCount: 39, todayCombo: 0, returnedAfterGap: false),
        MonsterMood.sleepy,
        reason: '39 < 40 属 1-2 天级',
      );
      expect(
        MonsterMoodResolver.resolve(dueCount: 40, todayCombo: 0, returnedAfterGap: false),
        MonsterMood.worried,
        reason: '≥40 属 3 天级+积压',
      );
    });

    test('今日连对 ≥5 → excited（无到期时）', () {
      expect(MonsterMoodResolver.resolve(dueCount: 0, todayCombo: 5, returnedAfterGap: false), MonsterMood.excited);
      expect(MonsterMoodResolver.resolve(dueCount: 0, todayCombo: 4, returnedAfterGap: false), MonsterMood.calm);
    });

    test('回归优先：负向数据不出场', () {
      expect(
        MonsterMoodResolver.resolve(dueCount: 100, todayCombo: 0, returnedAfterGap: true),
        MonsterMood.excited,
        reason: '刚回家先开心，worried 不出场',
      );
    });

    test('全默认 → calm', () {
      expect(MonsterMoodResolver.resolve(dueCount: 0, todayCombo: 0, returnedAfterGap: false), MonsterMood.calm);
    });
  });

  group('MonsterMoodResolver.resolveFrom（缺数据降级）', () {
    test('全 reader 缺失 → calm', () async {
      final mood = await MonsterMoodResolver().resolveFrom(
        dueCountReader: null,
        todayComboReader: null,
        checkinDatesReader: null,
      );
      expect(mood, MonsterMood.calm);
    });

    test('reader 抛错 → 按不可得处理（不抛出）', () async {
      final mood = await MonsterMoodResolver().resolveFrom(
        dueCountReader: () => throw StateError('db unavailable'),
        todayComboReader: () => throw StateError('no session'),
        checkinDatesReader: () async => throw StateError('store missing'),
      );
      expect(mood, MonsterMood.calm);
    });

    test('签到 3 天+ 未打开 → 回归 excited', () async {
      final now = DateTime(2026, 10, 3);
      final mood = await MonsterMoodResolver(now: () => now).resolveFrom(
        dueCountReader: () => 50,
        todayComboReader: () => 0,
        checkinDatesReader: () async => {'2026-09-28', '2026-09-29'},
      );
      expect(mood, MonsterMood.excited);
    });
  });
}
