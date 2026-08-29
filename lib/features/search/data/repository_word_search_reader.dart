import '../../../core/di/service_locator.dart';
import '../../../models/word.dart';
import 'package:word_app/core/repositories/word_repository.dart';
import '../application/word_search_reader.dart';

/// 基于既有词库仓储的搜索适配器。
class RepositoryWordSearchReader implements WordSearchReader {
  /// 从 service_locator 自动解析依赖。
  factory RepositoryWordSearchReader.fromServiceLocator() =>
      RepositoryWordSearchReader._(sl<WordRepository>());

  RepositoryWordSearchReader._(this._repository);

  /// 显式注入（供测试覆盖）。
  RepositoryWordSearchReader(WordRepository repository)
      : _repository = repository;

  final WordRepository _repository;

  @override
  Future<List<Word>> search(String query, {int? limit}) {
    return _repository.searchWords(query, limit: limit);
  }
}
