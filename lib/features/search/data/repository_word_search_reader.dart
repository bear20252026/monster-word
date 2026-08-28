import '../../../models/word.dart';
import '../../../repositories/word_repository.dart';
import '../application/word_search_reader.dart';

/// 基于既有词库仓储的搜索适配器。
class RepositoryWordSearchReader implements WordSearchReader {
  RepositoryWordSearchReader({required WordRepository repository}) : _repository = repository;

  final WordRepository _repository;

  @override
  Future<List<Word>> search(String query, {int? limit}) {
    return _repository.searchWords(query, limit: limit);
  }
}
