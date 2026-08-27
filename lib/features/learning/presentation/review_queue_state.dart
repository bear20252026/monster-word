import 'package:flutter/foundation.dart';

import '../application/review_queue_reader.dart';
import '../data/review_schedule_repository.dart';
import '../../../models/word.dart';

/// 正式复习队列的展示快照。
///
/// FSRS 卡片、到期判断和评分均来自 [ReviewScheduleRepository]。兼容期内仅由
/// [queue] 提供遗留学习会话维护的当前词表；页面与正式复习会话不再读取
/// `LearningState`。
class ReviewQueueState extends ChangeNotifier {
  ReviewQueueSnapshot _snapshot = const ReviewQueueSnapshot.empty();

  ReviewQueueSnapshot get snapshot => _snapshot;

  void synchronize({required Iterable<Word> queue, required ReviewScheduleRepository schedule}) {
    final queueWords = List<Word>.unmodifiable(queue);
    _snapshot = ReviewQueueSnapshot(
      dueWords: List.unmodifiable(schedule.dueWordsFor(queueWords)),
      queueWords: queueWords,
    );
    notifyListeners();
  }
}
