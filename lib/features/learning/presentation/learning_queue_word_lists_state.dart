import 'package:flutter/foundation.dart';

import '../../../models/word.dart';
import '../data/review_schedule_repository.dart';
import '../domain/queue_word_lists.dart';
import 'learning_queue_state.dart';

/// 学习队列分类词表的不可变展示快照。
class LearningQueueWordListsSnapshot {
  const LearningQueueWordListsSnapshot({
    required this.learnedWords,
    required this.notLearnedWords,
    required this.reviewingWords,
  });

  const LearningQueueWordListsSnapshot.empty()
    : learnedWords = const [],
      notLearnedWords = const [],
      reviewingWords = const [];

  factory LearningQueueWordListsSnapshot.fromSources({
    required LearningQueueState queue,
    required ReviewScheduleRepository schedule,
  }) {
    final lists = QueueWordLists.fromQueue(
      queue: queue.words,
      isLearned: (word) => schedule.cardFor(word.word) != null,
      isReviewing: (word) {
        final card = schedule.cardFor(word.word);
        return card != null && card.difficulty <= 5.0;
      },
    );
    return LearningQueueWordListsSnapshot(
      learnedWords: List.unmodifiable(lists.learnedWords),
      notLearnedWords: List.unmodifiable(lists.notLearnedWords),
      reviewingWords: List.unmodifiable(lists.reviewingWords),
    );
  }

  final List<Word> learnedWords;
  final List<Word> notLearnedWords;
  final List<Word> reviewingWords;
}

/// 队列分类词表的过渡展示状态。
///
/// 筛选组合 [LearningQueueState] 的当前队列与 [ReviewScheduleRepository] 的 FSRS
/// 卡片；页面通过该适配器读取快照，后续替换队列存储时无需重新引入遗留状态。
class LearningQueueWordListsState extends ChangeNotifier {
  LearningQueueWordListsSnapshot _snapshot = const LearningQueueWordListsSnapshot.empty();

  List<Word> get learnedWords => _snapshot.learnedWords;
  List<Word> get notLearnedWords => _snapshot.notLearnedWords;
  List<Word> get reviewingWords => _snapshot.reviewingWords;

  void synchronize({required LearningQueueState queue, required ReviewScheduleRepository schedule}) {
    _snapshot = LearningQueueWordListsSnapshot.fromSources(queue: queue, schedule: schedule);
    notifyListeners();
  }
}
