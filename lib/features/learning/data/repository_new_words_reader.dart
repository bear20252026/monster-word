import '../../../models/new_word_record.dart';
import '../../../models/word.dart';
import '../../../repositories/new_word_repository.dart';
import '../../../repositories/word_repository.dart';
import '../application/new_words_reader.dart';

/// 基于既有仓储的生词本读取适配器。
class RepositoryNewWordsReader implements NewWordsReader {
  const RepositoryNewWordsReader({required NewWordRepository newWordRepository, required WordRepository wordRepository})
    : _newWordRepository = newWordRepository,
      _wordRepository = wordRepository;

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
        if (wordsById[record.wordId] case final word?) word,
    ];
  }
}
