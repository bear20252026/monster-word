import 'package:flutter/foundation.dart';

import '../../../models/word.dart';
import '../../../state/learning_state.dart';

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

  factory LearningQueueWordListsSnapshot.fromLegacy(LearningState legacy) {
    final lists = legacy.queueWordLists;
    return LearningQueueWordListsSnapshot(
      learnedWords: lists.learnedWords,
      notLearnedWords: lists.notLearnedWords,
      reviewingWords: lists.reviewingWords,
    );
  }

  final List<Word> learnedWords;
  final List<Word> notLearnedWords;
  final List<Word> reviewingWords;
}

/// 队列分类词表的过渡展示状态。
///
/// 筛选仍以当前学习队列及 FSRS 卡片为事实来源；页面通过该适配器读取快照，
/// 后续替换队列存储时无需重新引入对 [LearningState] 的直接依赖。
class LearningQueueWordListsState extends ChangeNotifier {
  LearningQueueWordListsSnapshot _snapshot = const LearningQueueWordListsSnapshot.empty();

  List<Word> get learnedWords => _snapshot.learnedWords;
  List<Word> get notLearnedWords => _snapshot.notLearnedWords;
  List<Word> get reviewingWords => _snapshot.reviewingWords;

  void synchronizeFrom(LearningState legacy) {
    _snapshot = LearningQueueWordListsSnapshot.fromLegacy(legacy);
    notifyListeners();
  }
}
