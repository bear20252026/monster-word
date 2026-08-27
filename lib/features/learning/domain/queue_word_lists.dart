import '../../../models/word.dart';

/// 当前学习队列按学习卡片状态划分后的只读词表快照。
class QueueWordLists {
  const QueueWordLists({required this.learnedWords, required this.notLearnedWords, required this.reviewingWords});

  const QueueWordLists.empty() : learnedWords = const [], notLearnedWords = const [], reviewingWords = const [];

  final List<Word> learnedWords;
  final List<Word> notLearnedWords;
  final List<Word> reviewingWords;

  /// 保持遗留筛选语义：
  ///
  /// * 已学：队列单词存在学习卡片；
  /// * 未学习：队列单词不存在学习卡片；
  /// * 复习中：队列单词存在卡片，且其难度不高于既有阈值。
  factory QueueWordLists.fromQueue({
    required Iterable<Word> queue,
    required bool Function(Word word) isLearned,
    required bool Function(Word word) isReviewing,
  }) {
    final learned = <Word>[];
    final notLearned = <Word>[];
    final reviewing = <Word>[];

    for (final word in queue) {
      if (isLearned(word)) {
        learned.add(word);
      } else {
        notLearned.add(word);
      }
      if (isReviewing(word)) {
        reviewing.add(word);
      }
    }

    return QueueWordLists(
      learnedWords: List.unmodifiable(learned),
      notLearnedWords: List.unmodifiable(notLearned),
      reviewingWords: List.unmodifiable(reviewing),
    );
  }
}
