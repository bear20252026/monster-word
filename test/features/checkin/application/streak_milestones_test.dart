// 连胜里程碑：7/14/30/50 的跨档边界、只正向、封顶与「距下一档」口径。
import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/checkin/application/streak_milestones.dart';

void main() {
  group('crossedStreakMilestone', () {
    test('四个档位的正向跨档各返回本档', () {
      expect(crossedStreakMilestone(6, 7), 7);
      expect(crossedStreakMilestone(13, 14), 14);
      expect(crossedStreakMilestone(29, 30), 30);
      expect(crossedStreakMilestone(49, 50), 50);
    });

    test('多档连跨只取最大档（一次庆祝）', () {
      expect(crossedStreakMilestone(6, 15), 14);
      expect(crossedStreakMilestone(6, 60), 50);
      expect(crossedStreakMilestone(0, 31), 30);
    });

    test('已在档上/未到档位：null', () {
      expect(crossedStreakMilestone(7, 8), isNull);
      expect(crossedStreakMilestone(50, 80), isNull, reason: '封顶后不再有新档');
      expect(crossedStreakMilestone(0, 6), isNull);
      expect(crossedStreakMilestone(14, 14), isNull);
    });

    test('断签回落：不庆祝、不惩罚', () {
      expect(crossedStreakMilestone(30, 1), isNull);
      expect(crossedStreakMilestone(50, 0), isNull);
    });
  });

  group('下一档与天数', () {
    test('nextStreakMilestone 取严格大于当前值的档位', () {
      expect(nextStreakMilestone(0), 7);
      expect(nextStreakMilestone(6), 7);
      expect(nextStreakMilestone(7), 14);
      expect(nextStreakMilestone(13), 14);
      expect(nextStreakMilestone(49), 50);
      expect(nextStreakMilestone(50), isNull);
      expect(nextStreakMilestone(120), isNull);
    });

    test('daysToNextStreakMilestone 返回还差几天，封顶为 null', () {
      expect(daysToNextStreakMilestone(0), 7);
      expect(daysToNextStreakMilestone(6), 1);
      expect(daysToNextStreakMilestone(7), 7);
      expect(daysToNextStreakMilestone(29), 1);
      expect(daysToNextStreakMilestone(49), 1);
      expect(daysToNextStreakMilestone(50), isNull);
      expect(daysToNextStreakMilestone(-3), 7, reason: '脏数据按 0 处理');
    });

    test('庆祝文案简短且只含正向信息', () {
      expect(streakMilestonePhrase(14), '连续签到 14 天！');
    });
  });

  group('completionStreakLine（结算页连胜一行）', () {
    test('无连胜不显示', () {
      expect(completionStreakLine(streakDays: 0, checkedToday: true), isNull);
      expect(completionStreakLine(streakDays: 0, checkedToday: false), isNull);
    });

    test('未签到：只陈述现状，不催不吓唬', () {
      expect(completionStreakLine(streakDays: 6, checkedToday: false), '连胜 6 天 · 今天签到可续上');
      expect(completionStreakLine(streakDays: 50, checkedToday: false), '连胜 50 天 · 今天签到可续上');
    });

    test('已签到且明天正好跨档', () {
      expect(completionStreakLine(streakDays: 6, checkedToday: true), '连胜 6 天 · 明天就是第 7 天');
      expect(completionStreakLine(streakDays: 29, checkedToday: true), '连胜 29 天 · 明天就是第 30 天');
    });

    test('已签到且距离下一档不止一天', () {
      expect(completionStreakLine(streakDays: 1, checkedToday: true), '连胜 1 天 · 再坚持 6 天解锁下一档');
      expect(completionStreakLine(streakDays: 8, checkedToday: true), '连胜 8 天 · 再坚持 6 天解锁下一档');
    });

    test('已封顶只鼓励保持', () {
      expect(completionStreakLine(streakDays: 50, checkedToday: true), '连胜 50 天 · 保持住');
      expect(completionStreakLine(streakDays: 80, checkedToday: true), '连胜 80 天 · 保持住');
    });
  });
}
