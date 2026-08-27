import '../../../models/word.dart';
import '../../../repositories/word_repository.dart';

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

/// 正式复习词队列读取器。
///
/// 读取优先级与迁移前 [ReviewPage] 保持一致：
/// 1. 已到期的 FSRS 词；
/// 2. 当前学习队列；
/// 3. 词库中的有限样本，保证空队列时页面仍可进入。
class ReviewQueueReader {
  const ReviewQueueReader({required WordRepository wordRepository}) : _wordRepository = wordRepository;

  final WordRepository _wordRepository;

  Future<List<Word>> loadWords(ReviewQueueSnapshot snapshot) async {
    if (snapshot.dueWords.isNotEmpty) return snapshot.dueWords;
    if (snapshot.queueWords.isNotEmpty) return snapshot.queueWords;

    final primarySample = await _wordRepository.searchWords('a', limit: 20);
    if (primarySample.isNotEmpty) return primarySample;
    return _wordRepository.searchWords('the', limit: 20);
  }
}
