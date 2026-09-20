import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/application/review_queue_reader.dart';

/// 基于复习快照的正式复习队列读取适配器。
///
/// M7：due/queue 为空时返回空列表（真实空态），禁止塞入词库抽样假队列。
class RepositoryReviewQueueReader implements ReviewQueueReader {
  const RepositoryReviewQueueReader();

  @override
  Future<List<Word>> loadWords(ReviewQueueSnapshot snapshot) async {
    if (snapshot.dueWords.isNotEmpty) return snapshot.dueWords;
    if (snapshot.queueWords.isNotEmpty) return snapshot.queueWords;
    return const <Word>[];
  }
}
