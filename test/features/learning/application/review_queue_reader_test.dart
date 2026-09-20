import 'package:flutter_test/flutter_test.dart';

import 'package:word_app/features/learning/application/review_queue_reader.dart';
import 'package:word_app/features/learning/data/repository_review_queue_reader.dart';
import 'package:word_app/models/word.dart';

void main() {
  group('ReviewQueueReader（M7：真实空态）', () {
    test('优先返回 FSRS 到期词', () async {
      final dueWord = Word(id: 1, word: 'due');
      const reader = RepositoryReviewQueueReader();

      final words = await reader.loadWords(
        ReviewQueueSnapshot(
          dueWords: [dueWord],
          queueWords: [Word(id: 2, word: 'queued')],
        ),
      );

      expect(words, equals([dueWord]));
    });

    test('没有到期词时返回当前学习队列', () async {
      final queuedWord = Word(id: 2, word: 'queued');
      const reader = RepositoryReviewQueueReader();

      final words = await reader.loadWords(ReviewQueueSnapshot(dueWords: const [], queueWords: [queuedWord]));

      expect(words, equals([queuedWord]));
    });

    test('空状态返回空列表，禁止词库抽样假队列', () async {
      const reader = RepositoryReviewQueueReader();
      final words = await reader.loadWords(const ReviewQueueSnapshot.empty());
      expect(words, isEmpty);
    });
  });
}
