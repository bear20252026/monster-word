import 'package:flutter/foundation.dart';

import '../../../models/book.dart';
import '../../../models/word.dart';
import 'learning_session_state.dart';

/// 学习队列的只读快照。
///
/// 该快照只描述遗留学习会话当前暴露的队列与进度，不包含评分、候选生成、收藏或
/// 持久化命令。正式复习、学习统计和队列词表页面可依赖它而不再读取遗留外观。
class LearningQueueSnapshot {
  LearningQueueSnapshot({
    required this.currentBook,
    required List<Word> words,
    required this.currentIndex,
    required this.learnedCount,
  }) : words = List.unmodifiable(words);

  const LearningQueueSnapshot.empty()
      : currentBook = null,
        words = const [],
        currentIndex = 0,
        learnedCount = 0;

  factory LearningQueueSnapshot.fromSession(LearningSessionState session) {
    return LearningQueueSnapshot(
      currentBook: session.currentBook,
      words: session.queue,
      currentIndex: session.currentIndex,
      learnedCount: session.learnedNum,
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
/// 专用学习会话写入队列；该类是所有新展示与正式复习读取的唯一适配入口。队列命令
/// 继续迁出时，只有 [synchronizeFrom] 的来源需要替换。
class LearningQueueState extends ChangeNotifier {
  LearningQueueSnapshot _snapshot = const LearningQueueSnapshot.empty();

  LearningQueueSnapshot get snapshot => _snapshot;
  Book? get currentBook => _snapshot.currentBook;
  List<Word> get words => _snapshot.words;
  int get currentIndex => _snapshot.currentIndex;
  int get learnedCount => _snapshot.learnedCount;
  int get total => _snapshot.total;

  void synchronizeFrom(LearningSessionState session) {
    _snapshot = LearningQueueSnapshot.fromSession(session);
    notifyListeners();
  }
}
