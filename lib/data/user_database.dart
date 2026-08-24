// 由 Claude 团队生成 | 用户数据数据库
// 管理用户收藏、学习记录等数据
// 与 wordbook_database.dart（只读词库）分离

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

  Database get db {
    if (_db == null) {
      throw StateError('用户数据库尚未初始化，请先调用 initialize()');
    }
    return _db!;
  }

  /// 初始化用户数据库
  Future<void> initialize() async {
    if (_initialized) return;

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'user_data.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: _onCreate,
    );
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
  }

  // ============================================================
  // 收藏管理
  // ============================================================

  /// 添加收藏
  /// [wordId] 单词ID（来自 wordbook.db 的 words 表）
  Future<void> addFavorite(int wordId) async {
    await db.insert(
      'favorites',
      {
        'word_id': wordId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// 删除收藏
  /// [wordId] 单词ID
  Future<void> removeFavorite(int wordId) async {
    await db.delete(
      'favorites',
      where: 'word_id = ?',
      whereArgs: [wordId],
    );
  }

  /// 检查是否已收藏
  /// [wordId] 单词ID
  Future<bool> isFavorite(int wordId) async {
    final result = await db.query(
      'favorites',
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
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
    return rows.map((row) => row['word_id'] as int).toList();
  }

  /// 获取收藏数量
  Future<int> getFavoriteCount() async {
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM favorites');
    return result.first['count'] as int;
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

    final favoriteIds = rows.map((row) => row['word_id'] as int).toSet();
    return Map.fromEntries(
      wordIds.map((id) => MapEntry(id, favoriteIds.contains(id))),
    );
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
