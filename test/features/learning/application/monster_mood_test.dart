// MonsterMoodResolver 表驱动：四档全覆盖 + 边界 + 回归优先 + 缺数据降级。
import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/core/utils/monster_speech.dart';
import 'package:word_app/features/learning/application/monster_mood.dart';

void main() {
  group('pickMonsterNeed（W4.5 需求气泡）', () {
    test('到期 ≥20：给 needReview 槽，due 为真实数字', () {
      final need = pickMonsterNeed(dueCount: 25, daysSinceLastCheckin: 0);
      expect(need, isNotNull);
      expect(need!.slot, SpeechSlot.needReview);
      expect(need.vars['due'], 25);
    });

    test('到期不足但 ≥2 天没签到：给 needCheckin', () {
      final need = pickMonsterNeed(dueCount: 3, daysSinceLastCheckin: 2);
      expect(need!.slot, SpeechSlot.needCheckin);
    });

    test('复习优先于签到（学习是主语）', () {
      final need = pickMonsterNeed(dueCount: 40, daysSinceLastCheckin: 5);
      expect(need!.slot, SpeechSlot.needReview);
    });

    test('无需求：返回 null（不硬凑气泡）', () {
      expect(pickMonsterNeed(dueCount: 5, daysSinceLastCheckin: 0), isNull);
      // 从未签到（-1 哨兵）：不催新用户
      expect(pickMonsterNeed(dueCount: 5, daysSinceLastCheckin: -1), isNull);
    });
  });

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
