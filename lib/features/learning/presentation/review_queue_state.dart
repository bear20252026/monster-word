import 'package:flutter/foundation.dart';

import '../application/review_queue_reader.dart';
import '../../../state/learning_state.dart';

/// 正式复习队列的过渡展示状态。
///
/// FSRS 到期判断与当前学习队列仍以 [LearningState] 为事实来源；页面仅
/// 读取此处提供的不可变快照。待调度数据迁出后，只需替换同步来源，
/// 无需重新让页面耦合旧状态。
class ReviewQueueState extends ChangeNotifier {
  ReviewQueueSnapshot _snapshot = const ReviewQueueSnapshot.empty();

  ReviewQueueSnapshot get snapshot => _snapshot;

  void synchronizeFrom(LearningState legacy) {
    _snapshot = ReviewQueueSnapshot(
      dueWords: List.unmodifiable(legacy.dueWords),
      queueWords: List.unmodifiable(legacy.queue),
    );
    notifyListeners();
  }
}
