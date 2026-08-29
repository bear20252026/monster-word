import 'package:word_app/models/word.dart';
import 'package:word_app/core/repositories/new_word_repository.dart';
import 'package:word_app/core/repositories/word_repository.dart';
import 'package:word_app/features/learning/application/new_words_reader.dart';

/// 基于既有仓储的生词本读取适配器。
class RepositoryNewWordsReader implements NewWordsReader {
  const RepositoryNewWordsReader({required this._newWordRepository, required this._wordRepository});

  final NewWordRepository _newWordRepository;
  final WordRepository _wordRepository;

  @override
  Future<List<Word>> loadWords({int? limit, int? offset}) async {
    final records = await _newWordRepository.getNewWords(limit: limit, offset: offset);
    if (records.isEmpty) return [];

    final words = await _wordRepository.getWordsByIds(records.map((record) => record.wordId));
    final wordsById = {for (final word in words) word.id: word};
    return [
      for (final record in records)
        wordsById[record.wordId],
    ].whereType<Word>().toList();
  }
}
