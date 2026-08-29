// 由 Claude 团队生成 | Monster Word App
// WordRepositoryImpl — 单词数据仓库实现

import '../../data/wordbook_database.dart';
import 'word_repository.dart';

/// 单词数据仓库的具体实现
class WordRepositoryImpl implements WordRepository {
  final WordBookDatabase _database;

  WordRepositoryImpl(this._database);

  @override
  Future<List<Word>> getWordsByBookId(int bookId, {int? limit, int? offset}) async {
    final maps = await _database.db.rawQuery(
      '''
      SELECT w.* FROM words w
      JOIN word_books wb ON wb.word_id = w.id
      WHERE wb.book_id = ?
      ORDER BY wb.rowid
      LIMIT ? OFFSET ?
      ''',
      [bookId, limit ?? 50, offset ?? 0],
    );
    return maps.map(Word.fromMap).toList();
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
    final maps = await db.query('words', where: 'word = ?', whereArgs: [text], limit: 1);
    if (maps.isEmpty) return null;
    return Word.fromMap(maps.first);
  }

  @override
  Future<List<Word>> getWordsByTexts(Iterable<String> texts) async {
    final uniqueTexts = texts.where((text) => text.isNotEmpty).toSet().toList(growable: false);
    if (uniqueTexts.isEmpty) return [];

    final db = _database.db;
    final words = <Word>[];
    const chunkSize = 900;
    for (var start = 0; start < uniqueTexts.length; start += chunkSize) {
      final end = start + chunkSize < uniqueTexts.length ? start + chunkSize : uniqueTexts.length;
      final chunk = uniqueTexts.sublist(start, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final maps = await db.query('words', where: 'word IN ($placeholders)', whereArgs: chunk);
      words.addAll(maps.map(Word.fromMap));
    }
    return words;
  }

  @override
  Future<List<Word>> getWordsByIds(Iterable<int> ids) async {
    final uniqueIds = ids.where((id) => id > 0).toSet().toList(growable: false);
    if (uniqueIds.isEmpty) return [];

    final db = _database.db;
    final words = <Word>[];
    const chunkSize = 900;
    for (var start = 0; start < uniqueIds.length; start += chunkSize) {
      final end = start + chunkSize < uniqueIds.length ? start + chunkSize : uniqueIds.length;
      final chunk = uniqueIds.sublist(start, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final maps = await db.query('words', where: 'id IN ($placeholders)', whereArgs: chunk);
      words.addAll(maps.map(Word.fromMap));
    }
    return words;
  }

  @override
  Future<List<Word>> searchWords(String query, {int? limit}) async {
    final db = _database.db;
    final maps = await db.query('words', where: 'word LIKE ?', whereArgs: ['%$query%'], limit: limit ?? 50);
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
    final maps = await db.query('words', where: where, whereArgs: whereArgs, orderBy: 'RANDOM()', limit: count);
    return maps.map((m) => Word.fromMap(m)).toList();
  }

  @override
  Future<int> updateWordStatus(int wordId, Map<String, dynamic> status) async {
    // 此兼容接口尚未实现；学习状态由学习域的专用仓储与状态管理。
    return 0;
  }
}
