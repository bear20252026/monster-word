import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:word_app/features/book/application/book_word_list_reader.dart';

/// 基于 WordBookDatabase 的词书单词列表适配器。
///
/// 实现 [BookWordListReader] 端口，封装指定词书的单词查询逻辑。
/// 全量加载（无分页），按单词字母序 A-Z 排列（COLLATE NOCASE 大小写不敏感）。
class RepositoryBookWordListReader implements BookWordListReader {
  RepositoryBookWordListReader({this._database});

  final WordBookDatabase? _database;

  WordBookDatabase get _db => _database ?? WordBookDatabase.instance;

  @override
  Future<List<Word>> loadWords(int bookId) {
    return _db.getWordsByBook(bookId, lightweight: true);
  }
}
