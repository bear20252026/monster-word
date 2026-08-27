import '../../../models/word.dart';
import '../../../repositories/word_repository.dart';

/// 词书单词列表的只读应用服务。
class BookWordsReader {
  const BookWordsReader({required WordRepository wordRepository}) : _wordRepository = wordRepository;

  final WordRepository _wordRepository;

  Future<List<Word>> loadWords(int bookId) {
    return _wordRepository.getWordsByBookId(bookId, limit: 1000);
  }
}
