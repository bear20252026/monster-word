// 由 Claude 团队生成 | 内置字典查询服务
// 封装字典相关查询：搜索单词、获取详情、派生词、词根词缀、近义词、真题例句、收藏管理

import '../data/wordbook_database.dart';
import '../data/user_database.dart';

/// 字典查询服务（单例）
///
/// 提供高级字典查询功能，封装 WordBookDatabase 的复杂查询
class DictionaryService {
  static final DictionaryService instance = DictionaryService._();
  DictionaryService._();

  final WordBookDatabase _db = WordBookDatabase.instance;
  final UserDatabase _userDb = UserDatabase.instance;

  // ============================================================
  // 1. 搜索单词（前缀匹配/模糊匹配）
  // ============================================================

  /// 前缀匹配搜索
  /// [prefix] 单词前缀
  /// [limit] 返回数量限制
  Future<List<Word>> searchByPrefix(String prefix, {int limit = 20}) async {
    if (prefix.isEmpty) return [];
    return _db.searchWords(prefix, limit: limit);
  }

  /// 模糊匹配搜索（包含指定字符）
  /// [keyword] 搜索关键词
  /// [limit] 返回数量限制
  Future<List<Word>> searchByFuzzy(String keyword, {int limit = 20}) async {
    if (keyword.isEmpty) return [];
    final rows = await _db.db.query(
      'words',
      where: 'word LIKE ?',
      whereArgs: ['%$keyword%'],
      orderBy: 'word',
      limit: limit,
    );
    return rows.map(Word.fromMap).toList();
  }

  /// 智能搜索（优先前缀，其次模糊）
  /// [query] 搜索词
  /// [limit] 返回数量限制
  Future<List<Word>> smartSearch(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];

    // 先尝试前缀匹配
    final prefixResults = await searchByPrefix(query, limit: limit);
    if (prefixResults.length >= limit) {
      return prefixResults;
    }

    // 如果前缀匹配不足，补充模糊匹配
    final fuzzyResults = await searchByFuzzy(query, limit: limit);
    final combined = <Word>[];
    final seen = <int>{};

    // 添加前缀匹配结果
    for (final word in prefixResults) {
      if (!seen.contains(word.id)) {
        combined.add(word);
        seen.add(word.id);
      }
    }

    // 补充模糊匹配结果
    for (final word in fuzzyResults) {
      if (!seen.contains(word.id) && combined.length < limit) {
        combined.add(word);
        seen.add(word.id);
      }
    }

    return combined;
  }

  // ============================================================
  // 2. 获取单词详情（释义/音标/例句）
  // ============================================================

  /// 获取单词详情
  /// [word] 单词
  Future<Word?> getWordDetail(String word) async {
    return _db.getWord(word);
  }

  /// 获取单词释义（按词性分行，优先结构化释义）
  /// [word] 单词
  Future<List<String>> getWordInterpretations(String word) async {
    final wordData = await _db.getWord(word);
    if (wordData == null) return [];
    if (wordData.hasStructuredDefinitions) {
      return wordData.formattedDefinitions.split('\n').where((l) => l.trim().isNotEmpty).toList();
    }
    return wordData.interpretLines;
  }

  /// 获取单词音标
  /// [word] 单词
  Future<Map<String, String>> getWordPhonetics(String word) async {
    final wordData = await _db.getWord(word);
    if (wordData == null) return {};
    return {'uk': wordData.ukPron, 'us': wordData.usPron};
  }

  /// 获取单词例句
  /// [word] 单词
  Future<String> getWordExample(String word) async {
    final wordData = await _db.getWord(word);
    if (wordData == null) return '';
    return wordData.example;
  }

  /// 获取单词短语
  /// [word] 单词
  Future<String> getWordPhrase(String word) async {
    final wordData = await _db.getWord(word);
    if (wordData == null) return '';
    return wordData.phrase;
  }

  // ============================================================
  // 3. 获取派生词
  // ============================================================

  /// 获取派生词（通过 main_word 字段关联）
  /// [word] 原词
  Future<List<Word>> getDerivedWords(String word) async {
    final rows = await _db.db.query(
      'words',
      where: 'main_word = ? AND word != ?',
      whereArgs: [word, word],
      orderBy: 'word',
    );
    return rows.map(Word.fromMap).toList();
  }

  /// 获取单词的所有形式（原词 + 派生词）
  /// [word] 原词
  Future<List<Word>> getWordForms(String word) async {
    final rows = await _db.db.query(
      'words',
      where: 'main_word = ? OR word = ?',
      whereArgs: [word, word],
      orderBy: 'word',
    );
    return rows.map(Word.fromMap).toList();
  }

  // ============================================================
  // 4. 获取词根词缀
  // ============================================================

  /// 获取词根词缀信息
  /// [word] 单词
  Future<String> getWordRoot(String word) async {
    final wordData = await _db.getWord(word);
    if (wordData == null) return '';
    return wordData.wordRoot;
  }

  /// 获取包含指定词根的单词
  /// [root] 词根
  /// [limit] 返回数量限制
  Future<List<Word>> getWordsByRoot(String root, {int limit = 20}) async {
    final rows = await _db.db.query(
      'words',
      where: 'word_root LIKE ?',
      whereArgs: ['%$root%'],
      orderBy: 'word',
      limit: limit,
    );
    return rows.map(Word.fromMap).toList();
  }

  // ============================================================
  // 5. 获取近义词
  // ============================================================

  /// 获取近义词（通过 confuse 字段）
  /// [word] 单词
  Future<List<Word>> getSynonyms(String word) async {
    final wordData = await _db.getWord(word);
    if (wordData == null || wordData.confuse.isEmpty) return [];

    // confuse 字段包含近义词列表（逗号分隔）
    final synonyms = wordData.confuse.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    if (synonyms.isEmpty) return [];

    // 查询近义词详情
    final results = <Word>[];
    for (final synonym in synonyms) {
      final synonymWord = await _db.getWord(synonym);
      if (synonymWord != null) {
        results.add(synonymWord);
      }
    }

    return results;
  }

  /// 获取易混淆词
  /// [word] 单词
  Future<List<String>> getConfusingWords(String word) async {
    final wordData = await _db.getWord(word);
    if (wordData == null || wordData.confuse.isEmpty) return [];
    return wordData.confuse.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  // ============================================================
  // 6. 获取真题例句
  // ============================================================

  /// 获取单词的真题例句
  /// [word] 单词
  Future<List<Map<String, String>>> getExamExamples(String word) async {
    final wordData = await _db.getWord(word);
    if (wordData == null || wordData.example.isEmpty) return [];

    // 解析例句（格式：例句1\n例句2\n...）
    final examples = wordData.example.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    return examples
        .map(
          (example) => {
            'sentence': example,
            'translation': '', // 翻译需要额外数据源
          },
        )
        .toList();
  }

  /// 获取单词的音频URL
  /// [word] 单词
  Future<Map<String, String>> getAudioUrls(String word) async {
    final wordData = await _db.getWord(word);
    if (wordData == null || wordData.audioUrls.isEmpty) return {};

    // 解析音频URL（格式：uk:url,us:url）
    final urls = <String, String>{};
    final parts = wordData.audioUrls.split(',');
    for (final part in parts) {
      final colonIndex = part.indexOf(':');
      if (colonIndex > 0) {
        final key = part.substring(0, colonIndex).trim();
        final value = part.substring(colonIndex + 1).trim();
        urls[key] = value;
      }
    }

    return urls;
  }

  // ============================================================
  // 7. 收藏管理（添加/删除/查询）
  // ============================================================

  /// 添加收藏
  /// [wordId] 单词ID
  Future<void> addFavorite(int wordId) async {
    await _userDb.addFavorite(wordId);
  }

  /// 删除收藏
  /// [wordId] 单词ID
  Future<void> removeFavorite(int wordId) async {
    await _userDb.removeFavorite(wordId);
  }

  /// 检查是否已收藏
  /// [wordId] 单词ID
  Future<bool> isFavorite(int wordId) async {
    return _userDb.isFavorite(wordId);
  }

  /// 获取所有收藏的单词
  /// [limit] 返回数量限制
  /// [offset] 偏移量
  Future<List<Word>> getFavoriteWords({int limit = 50, int offset = 0}) async {
    // 获取收藏的单词ID
    final wordIds = await _userDb.getFavoriteWordIds(limit: limit, offset: offset);
    if (wordIds.isEmpty) return [];

    // 批量查询单词详情
    final words = <Word>[];
    for (final wordId in wordIds) {
      // 通过ID查询单词
      final rows = await _db.db.query('words', where: 'id = ?', whereArgs: [wordId], limit: 1);
      if (rows.isNotEmpty) {
        words.add(Word.fromMap(rows.first));
      }
    }

    return words;
  }

  /// 获取收藏数量
  Future<int> getFavoriteCount() async {
    return _userDb.getFavoriteCount();
  }

  /// 切换收藏状态
  /// [wordId] 单词ID
  Future<bool> toggleFavorite(int wordId) async {
    return _userDb.toggleFavorite(wordId);
  }

  /// 批量检查收藏状态
  /// [wordIds] 单词ID列表
  Future<Map<int, bool>> checkFavoritesBatch(List<int> wordIds) async {
    return _userDb.checkFavoritesBatch(wordIds);
  }

  // ============================================================
  // 辅助方法
  // ============================================================

  /// 获取单词统计信息
  Future<Map<String, int>> getWordStats() async {
    final totalWords = await _db.db.rawQuery('SELECT COUNT(*) as count FROM words');
    final totalBooks = await _db.db.rawQuery('SELECT COUNT(*) as count FROM books');
    final totalFavorites = await _db.db.rawQuery('SELECT COUNT(*) as count FROM favorites');

    return {
      'totalWords': totalWords.first['count'] as int,
      'totalBooks': totalBooks.first['count'] as int,
      'totalFavorites': totalFavorites.first['count'] as int,
    };
  }

  /// 批量获取单词
  /// [words] 单词列表
  Future<List<Word>> getWordsBatch(List<String> words) async {
    if (words.isEmpty) return [];

    final placeholders = words.map((_) => '?').join(',');
    final rows = await _db.db.query('words', where: 'word IN ($placeholders)', whereArgs: words, orderBy: 'word');
    return rows.map(Word.fromMap).toList();
  }

  /// 获取随机单词
  /// [count] 数量
  Future<List<Word>> getRandomWords({int count = 10}) async {
    final rows = await _db.db.rawQuery(
      '''
      SELECT * FROM words
      ORDER BY RANDOM()
      LIMIT ?
    ''',
      [count],
    );
    return rows.map(Word.fromMap).toList();
  }
}
