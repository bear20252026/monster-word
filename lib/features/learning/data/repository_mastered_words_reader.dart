import '../../../models/word.dart';
import '../../../repositories/mastered_repository.dart';
import '../../../repositories/word_repository.dart';
import '../application/mastered_words_reader.dart';

/// 基于既有仓储的已掌握词读取适配器。
class RepositoryMasteredWordsReader implements MasteredWordsReader {
  const RepositoryMasteredWordsReader({
    required this._masteredRepository,
    required this._wordRepository,
  });

  final MasteredRepository _masteredRepository;
  final WordRepository _wordRepository;

  @override
  Future<List<String>> loadTexts() async => (await _masteredRepository.getMasteredWords()).toList();

  @override
  Future<List<Word>> loadWords() async {
    final masteredWords = await _masteredRepository.getMasteredWords();
    if (masteredWords.isEmpty) return [];
    return _wordRepository.getWordsByTexts(masteredWords);
  }
}
