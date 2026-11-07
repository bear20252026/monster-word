import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/domain/weekly_comparison.dart';

void main() {
  Map<String, int> Function(String day) statsFrom(Map<String, Map<String, int>> data) =>
      (day) => data[day] ?? const {};

  test('两周数据：本周/上周词次与学习天数聚合正确，窗口外数据忽略', () {
    final data = {
      // 本周（含今天，往前 6 天）
      '2026-11-08': {'learn': 5},
      '2026-11-07': {'review': 3},
      '2026-11-03': {'learn': 2, 'review': 1},
      // 上周（再往前 7 天）
      '2026-11-01': {'learn': 10},
      '2026-10-27': {'review': 4},
      // 窗口外，不参与统计
      '2026-10-25': {'learn': 7, 'review': 7},
    };

    final cmp = WeeklyComparison.compute(statsFor: statsFrom(data), today: DateTime(2026, 11, 8));

    expect(cmp.thisWeekWords, 11);
    expect(cmp.thisWeekStudyDays, 3);
    expect(cmp.lastWeekWords, 14);
    expect(cmp.lastWeekStudyDays, 2);
    expect(cmp.wordsDelta, -3);
    expect(cmp.studyDaysDelta, 1);
    expect(cmp.hasLastWeekData, isTrue);
  });

  test('只有本周数据：汇总本周，且标记上周无数据', () {
    final data = {
      '2026-11-08': {'learn': 2},
      '2026-11-06': {'review': 1},
    };

    final cmp = WeeklyComparison.compute(statsFor: statsFrom(data), today: DateTime(2026, 11, 8));

    expect(cmp.thisWeekWords, 3);
    expect(cmp.thisWeekStudyDays, 2);
    expect(cmp.lastWeekWords, 0);
    expect(cmp.lastWeekStudyDays, 0);
    expect(cmp.hasLastWeekData, isFalse);
  });

  test('窗口边界：第 8 天前的日期计入上周，第 15 天前忽略', () {
    final data = {
      '2026-11-02': {'learn': 1}, // 本周第 7 天（含今天往前 6 天）
      '2026-11-01': {'learn': 1}, // 上周第 1 天
      '2026-10-26': {'learn': 1}, // 上周第 7 天
      '2026-10-25': {'learn': 1}, // 两周窗口之外
    };

    final cmp = WeeklyComparison.compute(statsFor: statsFrom(data), today: DateTime(2026, 11, 8));

    expect(cmp.thisWeekWords, 1);
    expect(cmp.lastWeekWords, 2);
    expect(cmp.thisWeekStudyDays, 1);
    expect(cmp.lastWeekStudyDays, 2);
  });

  test('没有任何记录：全 0，且上周无数据', () {
    final cmp = WeeklyComparison.compute(statsFor: (_) => const {}, today: DateTime(2026, 11, 8));

    expect(cmp.thisWeekWords, 0);
    expect(cmp.lastWeekWords, 0);
    expect(cmp.thisWeekStudyDays, 0);
    expect(cmp.lastWeekStudyDays, 0);
    expect(cmp.wordsDelta, 0);
    expect(cmp.hasLastWeekData, isFalse);
  });
}
