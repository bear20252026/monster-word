import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/domain/weekly_report.dart';

void main() {
  test('近 7 天聚合：天数/词次/正确率正确，窗口外忽略', () {
    final stats = {
      '2026-11-08': {'learn': 5, 'review': 2},
      '2026-11-07': {'review': 3},
      '2026-11-02': {'learn': 1},
      // 第 8 天前（窗口外）
      '2026-11-01': {'learn': 10},
    };
    final correct = {'2026-11-08': 6, '2026-11-07': 3, '2026-11-02': 0};

    final report = WeeklyReport.compute(
      statsFor: (day) => stats[day] ?? const {},
      correctFor: (day) => correct[day] ?? 0,
      today: DateTime(2026, 11, 8),
    );

    expect(report.studyDays, 3);
    expect(report.words, 11);
    expect(report.correctWords, 9);
    expect(report.accuracyPercent, 82);
    expect(report.accuracyText, '82%');
    expect(report.isEmpty, isFalse);
  });

  test('空数据周：isEmpty 为真，正确率不展示为 0%', () {
    final report = WeeklyReport.compute(statsFor: (_) => const {}, correctFor: (_) => 0, today: DateTime(2026, 11, 8));

    expect(report.isEmpty, isTrue);
    expect(report.studyDays, 0);
    expect(report.words, 0);
    expect(report.accuracyPercent, isNull);
    expect(report.accuracyText, '—');
  });

  test('答对数为 0 时正确率为 0%，但不算空周', () {
    final report = WeeklyReport.compute(
      statsFor: (day) => day == '2026-11-08' ? {'learn': 3, 'review': 2} : const {},
      correctFor: (_) => 0,
      today: DateTime(2026, 11, 8),
    );

    expect(report.isEmpty, isFalse);
    expect(report.words, 5);
    expect(report.accuracyPercent, 0);
    expect(report.accuracyText, '0%');
  });

  test('正确率四舍五入到整数百分比', () {
    final report = WeeklyReport.compute(
      statsFor: (day) => day == '2026-11-08' ? {'learn': 3, 'review': 0} : const {},
      correctFor: (day) => day == '2026-11-08' ? 2 : 0,
      today: DateTime(2026, 11, 8),
    );

    expect(report.accuracyPercent, 67);
  });
}
