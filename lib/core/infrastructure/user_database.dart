// 由 Claude 团队生成 | 用户数据数据库
// 管理用户收藏、学习记录等数据
// 与 wordbook_database.dart（只读词库）分离

import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 用户数据库管理器（单例）
///
/// 管理用户收藏、学习记录等可写数据
/// 与只读词库 wordbook_database 分离
class UserDatabase {
  static final UserDatabase instance = UserDatabase._();
  UserDatabase._();

  Database? _db;
  bool _initialized = false;
  Completer<void>? _initCompleter;

  Database get db {
    if (_db == null) {
      throw StateError('用户数据库尚未初始化，请先调用 initialize()');
    }
    return _db!;
  }

  /// 初始化用户数据库
  Future<void> initialize() {
    if (_initialized) return Future.value();
    final inflight = _initCompleter;
    if (inflight != null) return inflight.future;
    final completer = Completer<void>();
    _initCompleter = completer;
    completer.future.ignore();
    _initializeInner().then(
      (_) => completer.complete(),
      onError: (Object e, StackTrace st) {
        if (identical(_initCompleter, completer)) _initCompleter = null;
        completer.completeError(e, st);
      },
    );
    return completer.future;
  }

  Future<void> _initializeInner() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'user_data.db');

    _db = await openDatabase(dbPath, version: 3, onCreate: _onCreate, onUpgrade: _onUpgrade);
    _initialized = true;
  }

  /// 创建数据库表
  Future<void> _onCreate(Database db, int version) async {
    // 收藏表
    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        UNIQUE(word_id)
      )
    ''');

    // 创建索引
    await db.execute('CREATE INDEX idx_favorites_word_id ON favorites(word_id)');
    await db.execute('CREATE INDEX idx_favorites_created_at ON favorites(created_at)');
    await _createNewWordsTable(db);
    await _createFavoriteTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createNewWordsTable(db);
    }
    // MEM/U3+U6：收藏迁 SQLite（ FavoriteWordsDao / FavSentenceDao 的事实来源）
    if (oldVersion < 3) {
      await _createFavoriteTables(db);
    }
  }

  /// MEM/U3+U6：收藏持久化表。
  ///
  /// 单词收藏以【单词文本】为主键——与 mastered/mastered_words_v1 一致，
  /// 文本身份在词库重建/资产更新后仍稳定（自增 word_id 不保证跨版本稳定）。
  /// 例句收藏以 (word_id, sentence_id) 复合主键，data_json 原样保存
  /// FavSentenceData.toJson()，保证新增列外的历史字段无损往返。
  Future<void> _createFavoriteTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_words (
        word TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_favorite_words_created ON favorite_words(created_at)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorite_sentences (
        word_id INTEGER NOT NULL,
        sentence_id TEXT NOT NULL,
        word TEXT NOT NULL DEFAULT '',
        update_time TEXT NOT NULL,
        data_json TEXT NOT NULL,
        PRIMARY KEY(word_id, sentence_id)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_favorite_sentences_time ON favorite_sentences(update_time DESC)');
  }

  Future<void> _createNewWordsTable(Database db) async {
    await db.execute('''
      CREATE TABLE new_words (
        word_id INTEGER PRIMARY KEY,
        word_text TEXT NOT NULL,
        source TEXT NOT NULL,
        operation_code TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        synced_at INTEGER
      )
    ''');
    await db.execute('CREATE INDEX idx_new_words_operation_updated ON new_words(operation_code, updated_at DESC)');
  }

  // ============================================================
  // 收藏管理
  // ============================================================

  /// 添加收藏
  /// [wordId] 单词ID（来自 wordbook.db 的 words 表）
  Future<void> addFavorite(int wordId) async {
    await db.insert('favorites', {
      'word_id': wordId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// 删除收藏
  /// [wordId] 单词ID
  Future<void> removeFavorite(int wordId) async {
    await db.delete('favorites', where: 'word_id = ?', whereArgs: [wordId]);
  }

  /// 检查是否已收藏
  /// [wordId] 单词ID
  Future<bool> isFavorite(int wordId) async {
    final result = await db.query('favorites', where: 'word_id = ?', whereArgs: [wordId], limit: 1);
    return result.isNotEmpty;
  }

  /// 获取所有收藏的单词ID
  /// [limit] 返回数量限制
  /// [offset] 偏移量
  Future<List<int>> getFavoriteWordIds({int limit = 50, int offset = 0}) async {
    final rows = await db.query(
      'favorites',
      columns: ['word_id'],
      orderBy: 'created_at DESC',
      limit: limit,
      offset: offset,
    );
    return rows.map((row) => (row['word_id'] as int?) ?? 0).toList();
  }

  /// 获取收藏数量
  Future<int> getFavoriteCount() async {
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM favorites');
    return (result.isNotEmpty ? (result.first['count'] as int?) ?? 0 : 0);
  }

  /// 切换收藏状态
  /// [wordId] 单词ID
  /// 返回 true 表示已收藏，false 表示取消收藏
  Future<bool> toggleFavorite(int wordId) async {
    final isFav = await isFavorite(wordId);
    if (isFav) {
      await removeFavorite(wordId);
      return false;
    } else {
      await addFavorite(wordId);
      return true;
    }
  }

  /// 批量检查收藏状态
  /// [wordIds] 单词ID列表
  Future<Map<int, bool>> checkFavoritesBatch(List<int> wordIds) async {
    if (wordIds.isEmpty) return {};

    final placeholders = wordIds.map((_) => '?').join(',');
    final rows = await db.query(
      'favorites',
      columns: ['word_id'],
      where: 'word_id IN ($placeholders)',
      whereArgs: wordIds,
    );

    final favoriteIds = rows.map((row) => (row['word_id'] as int?) ?? 0).toSet();
    return Map.fromEntries(wordIds.map((id) => MapEntry(id, favoriteIds.contains(id))));
  }

  /// 清空所有收藏
  Future<void> clearAllFavorites() async {
    await db.delete('favorites');
  }

  /// 关闭数据库
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _initialized = false;
  }
}
