import 'package:word_app/models/word.dart';
import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/features/learning/application/book_words_reader.dart';

/// 基于既有单词仓储的词书单词读取适配器。
class RepositoryBookWordsReader implements BookWordsReader {
  RepositoryBookWordsReader({required this._repository});

  final WordRepository _repository;

  @override
  Future<List<Word>> loadWords(int bookId) => _repository.getWordsByBookId(bookId);
}
