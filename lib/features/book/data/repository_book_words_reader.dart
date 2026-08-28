import '../../../data/wordbook_database.dart';
import '../application/book_words_reader.dart';

/// 基于 WordBookDatabase 的词书单词列表适配器。
///
/// 实现 [BookWordsReader] 端口，封装指定词书的单词查询逻辑。
class RepositoryBookWordsReader implements BookWordsReader {
  RepositoryBookWordsReader({this._database});

  final WordBookDatabase? _database;

  WordBookDatabase get _db => _database ?? WordBookDatabase.instance;

  @override
  Future<List<Word>> loadWords(int bookId, {int limit = 50, int offset = 0}) {
    return _db.getWordsByBook(bookId, limit: limit, offset: offset);
  }
}
