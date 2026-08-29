import '../../../core/di/service_locator.dart';
import '../../../models/word.dart';
import 'package:word_app/core/repositories/word_repository.dart';
import '../application/quick_review_word_reader.dart';

/// 基于既有单词仓储的考试速刷词源适配器。
class RepositoryQuickReviewWordReader implements QuickReviewWordReader {
  /// 从 service_locator 自动解析依赖。
  factory RepositoryQuickReviewWordReader.fromServiceLocator() =>
      RepositoryQuickReviewWordReader._(sl<WordRepository>());

  RepositoryQuickReviewWordReader._(this._repository);

  /// 显式注入（供测试覆盖）。
  RepositoryQuickReviewWordReader(WordRepository repository)
      : _repository = repository;

  final WordRepository _repository;

  @override
  Future<List<Word>> loadWords({int limit = 50}) async {
    final words = await _repository.searchWords('');
    words.sort((a, b) => b.id.compareTo(a.id));
    return words.take(limit).toList();
  }
}
