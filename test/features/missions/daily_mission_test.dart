import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/missions/domain/daily_mission.dart';

void main() {
  group('复习任务目标（当日到期不足 20 按实际数）', () {
    test('到期 5 个 → 目标 5', () {
      expect(reviewMissionTarget(reviewedToday: 0, dueNow: 5), 5);
    });

    test('到期 30 个 → 封顶 20', () {
      expect(reviewMissionTarget(reviewedToday: 0, dueNow: 30), 20);
    });

    test('已复习 10 + 未到期 10 → 目标仍是 20（今天到期总量）', () {
      expect(reviewMissionTarget(reviewedToday: 10, dueNow: 10), 20);
    });

    test('全部复习完后目标保持（已复习 5 + 未到期 0 → 5）', () {
      expect(reviewMissionTarget(reviewedToday: 5, dueNow: 0), 5);
    });

    test('0 到期且未复习 → 目标不可得（不判定完成，避免误发币）', () {
      expect(reviewMissionTarget(reviewedToday: 0, dueNow: 0), isNull);
    });
  });

  group('完成判定', () {
    test('达到目标即完成，差一个不算', () {
      expect(isDailyMissionComplete(progress: 9, target: 10), isFalse);
      expect(isDailyMissionComplete(progress: 10, target: 10), isTrue);
    });

    test('目标不可得时一律未完成', () {
      expect(isDailyMissionComplete(progress: 100, target: null), isFalse);
    });

    test('正确率 80 是完成边界（79 未完成）', () {
      expect(isDailyMissionComplete(progress: 79, target: dailyAccuracyTargetPercent), isFalse);
      expect(isDailyMissionComplete(progress: 80, target: dailyAccuracyTargetPercent), isTrue);
    });
  });

  group('会话正确率', () {
    test('没答题时返回 null，不参与任务', () {
      expect(sessionAccuracyPercent(answered: 0, correct: 0), isNull);
    });

    test('向下取整到整数百分比（2026-11-14：round 改 floor，防 79.5% 抬到 80）', () {
      expect(sessionAccuracyPercent(answered: 3, correct: 2), 66);
      expect(sessionAccuracyPercent(answered: 5, correct: 4), 80);
      expect(sessionAccuracyPercent(answered: 200, correct: 159), 79, reason: '79.5% 不得抬到 80');
    });

    test('全对 = 100', () {
      expect(sessionAccuracyPercent(answered: 10, correct: 10), 100);
    });
  });

  group('日期键与任务定义', () {
    test('日期键按本地时区补零', () {
      expect(dailyMissionDayKey(DateTime(2026, 3, 7)), '2026-03-07');
    });

    test('三条任务顺序固定，标题随复习目标变化', () {
      final defs = dailyMissionDefinitions(reviewTarget: 5);
      expect(defs.map((d) => d.id), [
        DailyMissionId.learnNew,
        DailyMissionId.reviewDue,
        DailyMissionId.sessionAccuracy,
      ]);
      expect(defs[1].title, contains('5'));
      expect(dailyMissionDefinitions(reviewTarget: null)[1].title, '复习到期词');
    });

    test('存储键可双向解析', () {
      for (final id in DailyMissionId.values) {
        expect(DailyMissionId.fromKey(id.key), id);
      }
      expect(DailyMissionId.fromKey('legacy_task'), isNull);
    });
  });
}
