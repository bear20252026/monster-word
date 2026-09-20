import 'package:word_app/core/application/word_lookup_reader.dart';
import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/models/word.dart';

/// [WordLookupReader] 适配器：委托既有 [WordRepository]。
class RepositoryWordLookupReader implements WordLookupReader {
  RepositoryWordLookupReader(this._repository);

  final WordRepository _repository;

  @override
  Future<Word?> getWordByText(String text) => _repository.getWordByText(text);
}
