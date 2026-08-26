// 由 Claude 团队生成 | Monster Word App
// WordRepositoryImpl — 单词数据仓库实现

import '../../data/wordbook_database.dart';
import '../../models/word.dart';
import 'word_repository.dart';

/// 单词数据仓库的具体实现
class WordRepositoryImpl implements WordRepository {
  final WordBookDatabase _database;

  WordRepositoryImpl(this._database);

  @override
  Future<List<Word>> getWordsByBookId(int bookId) async {
    final db = _database.db;
    final maps = await db.query(
      'words',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  @override
  Future<Word?> getWordById(int id) async {
    final db = _database.db;
    final maps = await db.query('words', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Word.fromMap(maps.first);
  }

  @override
  Future<Word?> getWordByText(String text) async {
    final db = _database.db;
    final maps = await db.query(
      'words',
      where: 'word = ?',
      whereArgs: [text],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Word.fromMap(maps.first);
  }

  @override
  Future<List<Word>> searchWords(String query, {int? limit}) async {
    final db = _database.db;
    final maps = await db.query(
      'words',
      where: 'word LIKE ?',
      whereArgs: ['%$query%'],
      limit: limit ?? 50,
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  @override
  Future<Map<String, dynamic>?> getWordDetails(int wordId) async {
    final word = await getWordById(wordId);
    if (word == null) return null;
    return {
      'id': word.id,
      'word': word.word,
      'interpret': word.interpret,
      'ukPron': word.ukPron,
      'usPron': word.usPron,
      'phrase': word.phrase,
      'example': word.example,
      'confuse': word.confuse,
      'audioUrls': word.audioUrls,
      'imageUrls': word.imageUrls,
      'wordRoot': word.wordRoot,
    };
  }

  @override
  Future<List<Word>> getRandomWords(int count, {int? excludeBookId}) async {
    final db = _database.db;
    final where = excludeBookId != null ? 'book_id != ?' : null;
    final whereArgs = excludeBookId != null ? [excludeBookId] : null;
    final maps = await db.query(
      'words',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'RANDOM()',
      limit: count,
    );
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  @override
  Future<int> updateWordStatus(int wordId, Map<String, dynamic> status) async {
    // 使用 SharedPreferences 存储单词状态（与现有 LearningState 保持一致）
    // 此方法暂不实现，状态由 LearningState 管理
    return 0;
  }
}
