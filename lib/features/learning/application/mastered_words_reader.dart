import '../../../models/word.dart';
import '../../../repositories/mastered_repository.dart';
import '../../../repositories/word_repository.dart';

/// 已掌握词表的只读应用服务。
///
/// 手动掌握标记使用单词字符串作为身份键；该读取器负责将标记集合解析为
/// 完整 [Word] 模型，避免页面或遗留状态直接拼接存储与数据库访问。
class MasteredWordsReader {
  const MasteredWordsReader({required MasteredRepository masteredRepository, required WordRepository wordRepository})
    : _masteredRepository = masteredRepository,
      _wordRepository = wordRepository;

  final MasteredRepository _masteredRepository;
  final WordRepository _wordRepository;

  Future<List<Word>> loadWords() async {
    final masteredWords = await _masteredRepository.getMasteredWords();
    if (masteredWords.isEmpty) return [];
    return _wordRepository.getWordsByTexts(masteredWords);
  }
}
