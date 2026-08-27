import '../../../models/word.dart';
import '../../../repositories/new_word_repository.dart';
import '../../../repositories/word_repository.dart';

/// 将用户生词本记录解析为可展示词条的应用层读取器。
class NewWordsReader {
  NewWordsReader({required NewWordRepository newWordRepository, required WordRepository wordRepository})
    : _newWordRepository = newWordRepository,
      _wordRepository = wordRepository;

  final NewWordRepository _newWordRepository;
  final WordRepository _wordRepository;

  /// 按加入生词本的时间倒序加载仍可从词库解析的单词。
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
