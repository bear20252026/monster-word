import 'package:flutter/foundation.dart';

import '../application/review_queue_reader.dart';
import '../application/review_schedule_reader.dart';
import 'learning_queue_state.dart';

/// 正式复习队列的展示快照。
///
/// FSRS 卡片、到期判断和评分均来自 [ReviewScheduleReader]；当前词表由
/// [LearningQueueSnapshot] 提供。页面与正式复习会话只读取这一专用队列快照。
class ReviewQueueState extends ChangeNotifier {
  ReviewQueueSnapshot _snapshot = const ReviewQueueSnapshot.empty();

  ReviewQueueSnapshot get snapshot => _snapshot;

  void synchronize({required LearningQueueSnapshot queue, required ReviewScheduleReader schedule}) {
    _snapshot = ReviewQueueSnapshot(
      dueWords: List.unmodifiable(schedule.dueWordsFor(queue.words)),
      queueWords: queue.words,
    );
    notifyListeners();
  }
}
