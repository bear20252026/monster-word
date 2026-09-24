import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/application/review_schedule_reader.dart';
import 'package:word_app/features/learning/domain/queue_word_lists.dart';
import 'package:word_app/features/learning/presentation/learning_queue_state.dart';

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

  /// MEM/异步化：卡片判定来自 [cards] 批量异步查询结果（SQL 真相）。
  factory LearningQueueWordListsSnapshot.fromCards({
    required LearningQueueSnapshot queue,
    required Map<String, FsrsCard?> cards,
  }) {
    final lists = QueueWordLists.fromQueue(
      queue: queue.words,
      isLearned: (word) => cards[word.word] != null,
      isReviewing: (word) {
        final card = cards[word.word];
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
/// 筛选组合 [LearningQueueSnapshot] 的当前队列与 [ReviewScheduleReader] 的 FSRS
/// 卡片；页面通过该适配器读取快照，后续替换队列存储时无需重新引入遗留状态。
class LearningQueueWordListsState extends ChangeNotifier {
  LearningQueueWordListsSnapshot _snapshot = const LearningQueueWordListsSnapshot.empty();
  int _seq = 0;

  List<Word> get learnedWords => _snapshot.learnedWords;
  List<Word> get notLearnedWords => _snapshot.notLearnedWords;
  List<Word> get reviewingWords => _snapshot.reviewingWords;

  /// MEM/异步化：入口保持同步（Provider update 闭包可直呼），
  /// 分类改由批量取卡后异步重建，序号防旧请求晚到覆盖新词表。
  void synchronize({required LearningQueueSnapshot queue, required ReviewScheduleReader schedule}) {
    final seq = ++_seq;
    unawaited(_rebuild(seq, queue, schedule));
  }

  Future<void> _rebuild(int seq, LearningQueueSnapshot queue, ReviewScheduleReader schedule) async {
    try {
      final cards = await schedule.cardsForWords(queue.words.map((word) => word.word));
      if (seq != _seq) return; // 词表已切换，丢弃过期重建
      _snapshot = LearningQueueWordListsSnapshot.fromCards(queue: queue, cards: cards);
      notifyListeners();
    } catch (_) {
      // 读取失败保留原快照，等下一次 synchronize 重试
    }
  }
}
