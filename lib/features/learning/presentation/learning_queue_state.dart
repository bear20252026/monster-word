import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../data/wordbook_database.dart' show Book;
import '../../../models/word.dart';
import '../../../state/learning_state.dart';

/// 学习队列的只读快照。
///
/// 该快照只描述遗留学习会话当前暴露的队列与进度，不包含评分、候选生成、收藏或
/// 持久化命令。正式复习、学习统计和队列词表页面可依赖它而不再读取 [LearningState]。
class LearningQueueSnapshot {
  const LearningQueueSnapshot({
    required this.currentBook,
    required this.words,
    required this.currentIndex,
    required this.learnedCount,
  });

  const LearningQueueSnapshot.empty() : currentBook = null, words = const [], currentIndex = 0, learnedCount = 0;

  factory LearningQueueSnapshot.fromLegacy(LearningState legacy) {
    return LearningQueueSnapshot(
      currentBook: legacy.currentBook,
      words: UnmodifiableListView(List<Word>.from(legacy.queue)),
      currentIndex: legacy.currentIndex,
      learnedCount: legacy.learnedNum,
    );
  }

  final Book? currentBook;
  final List<Word> words;
  final int currentIndex;
  final int learnedCount;

  int get total => words.length;
}

/// 当前学习队列的过渡读取状态。
///
/// 学习会话仍由 [LearningState] 写入队列；该类是所有新展示与正式复习读取的唯一
/// 适配入口。队列命令迁出后，只有 [synchronizeFrom] 的来源需要替换。
class LearningQueueState extends ChangeNotifier {
  LearningQueueSnapshot _snapshot = const LearningQueueSnapshot.empty();

  LearningQueueSnapshot get snapshot => _snapshot;
  Book? get currentBook => _snapshot.currentBook;
  List<Word> get words => _snapshot.words;
  int get currentIndex => _snapshot.currentIndex;
  int get learnedCount => _snapshot.learnedCount;
  int get total => _snapshot.total;

  void synchronizeFrom(LearningState legacy) {
    _snapshot = LearningQueueSnapshot.fromLegacy(legacy);
    notifyListeners();
  }
}
