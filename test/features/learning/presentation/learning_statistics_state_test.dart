import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/presentation/learning_statistics_state.dart';

void main() {
  group('LearningStatisticsSnapshot', () {
    test('空快照为统计页面提供安全的零值默认值', () {
      final snapshot = LearningStatisticsSnapshot.empty();

      expect(snapshot.currentBook, isNull);
      expect(snapshot.total, 0);
      expect(snapshot.dueCount, 0);
      expect(snapshot.learnedCount, 0);
      expect(snapshot.totalLearnedDays, 0);
      expect(snapshot.memoryStat('due'), 0);
      expect(snapshot.todayStat('learned'), 0);
    });

    test('统计快照按键读取 FSRS 与今日学习数据', () {
      const snapshot = LearningStatisticsSnapshot(
        currentBook: null,
        total: 120,
        dueCount: 8,
        learnedCount: 37,
        totalLearnedDays: 15,
        memoryStats: <String, int>{'new': 12, 'due': 8, 'mature': 37},
        todayStats: <String, int>{'learned': 6},
      );

      expect(snapshot.memoryStat('new'), 12);
      expect(snapshot.memoryStat('mature'), 37);
      expect(snapshot.totalLearnedDays, 15);
      expect(snapshot.todayStat('learned'), 6);
      expect(snapshot.todayStat('missing'), 0);
    });
  });
}
