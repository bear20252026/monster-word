import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:word_app/features/book/application/book_word_list_reader.dart';

/// 基于 WordBookDatabase 的词书单词列表适配器。
///
/// 实现 [BookWordListReader] 端口，封装指定词书的单词查询逻辑。
/// 按单词字母序 A-Z 排列（COLLATE NOCASE 大小写不敏感）。
///
/// MEM/F2：列表浏览走 [loadWordPage] LIMIT/OFFSET 真分页（lightweight 列），
/// 总量走 [countWords] 单值 COUNT；[loadWords] 全量加载保留给导出等场景。
class RepositoryBookWordListReader implements BookWordListReader {
  RepositoryBookWordListReader({required this.database});

  final WordBookDatabase database;

  @override
  Future<List<Word>> loadWords(int bookId) {
    // MW-44：导出契约必须给全量列——原 lightweight:true 让 example/phrase
    // 恒为空串，「包含例句/短语」勾选后导出内容永远为空（端口注释承诺
    // 「全量加载仅供导出」与实现直接矛盾）。导出是低频操作，可接受大字段。
    return database.getWordsByBook(bookId, lightweight: false);
  }

  @override
  Future<int> countWords(int bookId) => database.countWordsByBook(bookId);

  @override
  Future<List<Word>> loadWordPage(int bookId, {required int offset, required int limit}) {
    return database.getWordsByBook(bookId, lightweight: true, limit: limit, offset: offset);
  }

  @override
  Future<List<String>> loadWordTexts(int bookId) => database.getWordTextsByBook(bookId);
}
