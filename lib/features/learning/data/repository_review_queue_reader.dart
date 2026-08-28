import '../../../models/word.dart';
import '../../../repositories/word_repository.dart';
import '../application/review_queue_reader.dart';

/// 基于既有词库仓储的正式复习队列读取适配器。
class RepositoryReviewQueueReader implements ReviewQueueReader {
  const RepositoryReviewQueueReader({required this._wordRepository});

  final WordRepository _wordRepository;

  @override
  Future<List<Word>> loadWords(ReviewQueueSnapshot snapshot) async {
    if (snapshot.dueWords.isNotEmpty) return snapshot.dueWords;
    if (snapshot.queueWords.isNotEmpty) return snapshot.queueWords;

    final primarySample = await _wordRepository.searchWords('a', limit: 20);
    if (primarySample.isNotEmpty) return primarySample;
    return _wordRepository.searchWords('the', limit: 20);
  }
}
