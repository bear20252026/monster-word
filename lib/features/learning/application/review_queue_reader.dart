import '../../../models/word.dart';

/// 正式复习流程的候选词快照。
///
/// 到期词与当前学习队列仍由上游学习调度维护；该合同只固定正式复习
/// 的读取优先级，避免页面自行混合状态读取和词库回退查询。
class ReviewQueueSnapshot {
  const ReviewQueueSnapshot({required this.dueWords, required this.queueWords});

  const ReviewQueueSnapshot.empty() : dueWords = const [], queueWords = const [];

  final List<Word> dueWords;
  final List<Word> queueWords;
}

/// 正式复习词队列读取端口。
abstract interface class ReviewQueueReader {
  /// 按到期词、当前队列、有限词库样本的顺序返回候选词。
  Future<List<Word>> loadWords(ReviewQueueSnapshot snapshot);
}
