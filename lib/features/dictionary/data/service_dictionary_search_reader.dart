import '../../../data/wordbook_database.dart';
import '../application/dictionary_search_reader.dart';

/// 基于 WordBookDatabase 的词典搜索适配器。
///
/// 实现 [DictionarySearchReader] 端口，封装数据库查询逻辑。
/// 使用 [WordBookDatabase.searchWords] 做前缀匹配，
/// 名称子串匹配通过 SQL LIKE 实现模糊搜索。
class ServiceDictionarySearchReader implements DictionarySearchReader {
  ServiceDictionarySearchReader({this._database});

  final WordBookDatabase? _database;

  WordBookDatabase get _db => _database ?? WordBookDatabase.instance;

  @override
  Future<List<Word>> searchByPrefix(String prefix) async {
    if (prefix.trim().isEmpty) return [];
    return _db.searchWords(prefix.trim(), limit: 20);
  }

  @override
  Future<List<Word>> searchFuzzy(String query) async {
    if (query.trim().isEmpty) return [];
    // 子串匹配：%query%
    final rows = await _db.db.query(
      'words',
      where: 'word LIKE ?',
      whereArgs: ['%${query.trim()}%'],
      orderBy: 'word',
      limit: 40,
    );
    return rows.map(Word.fromMap).toList();
  }

  @override
  Future<List<Word>> searchSmart(String query) async {
    if (query.trim().isEmpty) return [];
    final prefixResults = await searchByPrefix(query);
    if (prefixResults.length >= 20) return prefixResults;
    final existingWords = prefixResults.map((w) => w.word).toSet();
    final fuzzyResults = await searchFuzzy(query);
    final merged = List<Word>.from(prefixResults);
    for (final w in fuzzyResults) {
      if (!existingWords.contains(w.word)) {
        merged.add(w);
        if (merged.length >= 40) break;
      }
    }
    return merged;
  }
}
