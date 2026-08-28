import '../../../models/word.dart';
import '../../../repositories/word_repository.dart';
import '../application/quick_review_word_reader.dart';

/// 基于既有单词仓储的考试速刷词源适配器。
class RepositoryQuickReviewWordReader implements QuickReviewWordReader {
  RepositoryQuickReviewWordReader({required this._repository});

  final WordRepository _repository;

  @override
  Future<List<Word>> loadWords({int limit = 50}) async {
    final words = await _repository.searchWords('');
    words.sort((a, b) => b.id.compareTo(a.id));
    return words.take(limit).toList();
  }
}
