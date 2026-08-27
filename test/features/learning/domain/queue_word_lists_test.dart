import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/learning/domain/queue_word_lists.dart';
import 'package:word_app/models/word.dart';

void main() {
  test('按卡片存在性和既有难度判断对队列词表分类并保持原顺序', () {
    final apple = Word(word: 'apple');
    final banana = Word(word: 'banana');
    final cherry = Word(word: 'cherry');

    final lists = QueueWordLists.fromQueue(
      queue: [apple, banana, cherry],
      isLearned: (word) => word.word != 'apple',
      isReviewing: (word) => word.word == 'banana',
    );

    expect(lists.learnedWords.map((word) => word.word), ['banana', 'cherry']);
    expect(lists.notLearnedWords.map((word) => word.word), ['apple']);
    expect(lists.reviewingWords.map((word) => word.word), ['banana']);
  });

  test('空队列产生空的分类词表', () {
    final lists = QueueWordLists.fromQueue(queue: const <Word>[], isLearned: (_) => false, isReviewing: (_) => false);

    expect(lists.learnedWords, isEmpty);
    expect(lists.notLearnedWords, isEmpty);
    expect(lists.reviewingWords, isEmpty);
  });
}
