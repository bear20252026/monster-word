import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/book/domain/book_statistics.dart';

void main() {
  group('BookStatistics', () {
    test('构造和字段访问', () {
      const stats = BookStatistics(totalWords: 100, learnedWords: 42);

      expect(stats.totalWords, 100);
      expect(stats.learnedWords, 42);
      expect(stats.unlearnWords, 58);
    });

    test('progress 计算正确', () {
      const stats = BookStatistics(totalWords: 100, learnedWords: 42);

      expect(stats.progress, 0.42);
      expect(stats.progressText, '42%');
    });

    test('progress 边界 - 全完成', () {
      const stats = BookStatistics(totalWords: 100, learnedWords: 100);

      expect(stats.progress, 1.0);
      expect(stats.progressText, '100%');
      expect(stats.isCompleted, isTrue);
    });

    test('progress 边界 - 零学习', () {
      const stats = BookStatistics(totalWords: 100, learnedWords: 0);

      expect(stats.progress, 0.0);
      expect(stats.progressText, '0%');
      expect(stats.isCompleted, isFalse);
    });

    test('progress 边界 - 空词书', () {
      const stats = BookStatistics(totalWords: 0, learnedWords: 0);

      expect(stats.progress, 0.0);
      expect(stats.progressText, '0%');
      expect(stats.isCompleted, isFalse);
    });

    test('unlearnWords 不会为负', () {
      const stats = BookStatistics(totalWords: 100, learnedWords: 150);

      expect(stats.unlearnWords, 0);
      expect(stats.progress, 1.0);
    });
  });
}
