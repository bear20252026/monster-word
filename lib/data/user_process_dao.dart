// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 数据库层：翻译自 database/BBWordProcessDBHelper.java + BBWordProcessDao.java（v3.2 源码 1:1）
// 用户学习进度表（user_process_history）+ 核心 DAO 操作

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/bb_word_process.dart';

/// 用户进度数据库（翻译自 BBWordProcessDBHelper 表结构）
class UserProcessDatabase {
  static const String tableName = 'user_process_history';

  /// 建表 SQL（原版 1:1，去掉 user_id 外的差异字段）
  static const String createTableSql = '''
    CREATE TABLE IF NOT EXISTS user_process_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id VARCHAR NOT NULL,
      word VARCHAR NOT NULL,
      state INTEGER,
      level INTEGER,
      position INTEGER,
      reviewdate VARCHAR,
      process INTEGER,
      success INTEGER,
      fail INTEGER,
      duration INTEGER,
      efactor DOUBLE,
      r1 INTEGER,
      r2 INTEGER,
      reFail INTEGER,
      reSuccess INTEGER,
      comeFrom INTEGER,
      updatetime DATETIME DEFAULT (DATETIME('now','localtime')),
      learnFrom INTEGER DEFAULT 0,
      zpk VARCHAR DEFAULT NULL,
      word_id INTEGER DEFAULT 0
    )
  ''';

  /// 同步表（原版 user_sync_v3）
  static const String syncTableSql = '''
    CREATE TABLE IF NOT EXISTS user_sync_v3 (
      synTime VARCHAR,
      userId VARCHAR(10) NOT NULL UNIQUE
    )
  ''';
}

/// 用户进度 DAO（翻译自 BBWordProcessDao.java 核心方法）
class BBWordProcessDao {
  final Database db;
  final String userId;
  final String tableName;

  BBWordProcessDao(this.db, this.userId) : tableName = UserProcessDatabase.tableName;

  /// 插入用户进度（原版 insertUserProcess）
  Future<void> insertUserProcess(BBWordProcess w) async {
    await db.insert(tableName, {
      'user_id': userId,
      'word': w.word,
      'state': w.state,
      'level': w.level,
      'position': w.position,
      'reviewdate': w.reviewDate,
      'process': w.process,
      'success': w.success,
      'fail': w.fail,
      'duration': w.duration,
      'efactor': w.eFactor,
      'r1': w.r1,
      'r2': w.r2,
      'reFail': w.reFail,
      'reSuccess': w.reSuccess,
      'comeFrom': w.comeFrom,
      'learnFrom': w.learnFrom,
      'zpk': w.zpk,
      'word_id': w.wordId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// 更新进度（原版 processUpdate）
  Future<void> processUpdate(BBWordProcess w) async {
    await db.update(
      tableName,
      {
        'state': w.state,
        'level': w.level,
        'position': w.position,
        'reviewdate': w.reviewDate,
        'process': w.process,
        'success': w.success,
        'fail': w.fail,
        'duration': w.duration,
        'efactor': w.eFactor,
        'reFail': w.reFail,
        'reSuccess': w.reSuccess,
        'updatetime': DateTime.now().toIso8601String(),
      },
      where: 'word = ? AND user_id = ?',
      whereArgs: [w.word, userId],
    );
  }

  /// 批量更新（原版 processUpdateByArray）
  Future<void> processUpdateByArray(List<BBWordProcess> list) async {
    final batch = db.batch();
    for (final w in list) {
      batch.update(
        tableName,
        {
          'state': w.state,
          'level': w.level,
          'reviewdate': w.reviewDate,
          'success': w.success,
          'fail': w.fail,
          'efactor': w.eFactor,
        },
        where: 'word = ? AND user_id = ?',
        whereArgs: [w.word, userId],
      );
    }
    await batch.commit(noResult: true);
  }

  /// 今日应复习数量（原版 todayReviewCount）
  Future<int> todayReviewCount() async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $tableName '
      'WHERE user_id = ? AND reviewdate IS NOT NULL AND reviewdate != "" '
      'AND date(reviewdate) <= date(?)',
      [userId, today],
    );
    return rows.first['cnt'] as int? ?? 0;
  }

  /// 按等级取词（原版 arrayForLevel）
  Future<List<BBWordProcess>> arrayForLevel(int level) async {
    final rows = await db.query(
      tableName,
      where: 'user_id = ? AND level = ?',
      whereArgs: [userId, level],
      orderBy: 'position ASC',
    );
    return rows.map(BBWordProcess.fromMap).toList();
  }

  /// 待复习词（原版 arrayForReview）
  Future<List<BBWordProcess>> arrayForReview(int num) async {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final rows = await db.query(
      tableName,
      where:
          'user_id = ? AND reviewdate IS NOT NULL AND reviewdate != "" '
          'AND date(reviewdate) <= date(?)',
      whereArgs: [userId, today],
      orderBy: 'reviewdate ASC',
      limit: num,
    );
    return rows.map(BBWordProcess.fromMap).toList();
  }

  /// 某词书的所有进度（按词书表过滤）
  /// ✅ 安全修复：bookCode 是白名单表名，需验证防止 SQL 注入
  Future<List<BBWordProcess>> arrayForBook(String bookCode) async {
    // 白名单验证：只允许字母数字下划线
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(bookCode)) {
      throw ArgumentError('Invalid bookCode: $bookCode');
    }
    final rows = await db.rawQuery(
      'SELECT p.* FROM $tableName p '
      'JOIN $bookCode b ON b.word = p.word '
      'WHERE p.user_id = ? ORDER BY p.position ASC',
      [userId],
    );
    return rows.map(BBWordProcess.fromMap).toList();
  }

  /// 学习中的词（原版 updateWordsInLearning 相关）
  Future<List<BBWordProcess>> arrayForLearning() async {
    final rows = await db.query(
      tableName,
      where: 'user_id = ? AND state = 1',
      whereArgs: [userId],
      orderBy: 'position ASC',
    );
    return rows.map(BBWordProcess.fromMap).toList();
  }

  /// 已掌握词（state = 2）
  Future<List<BBWordProcess>> arrayForMastered() async {
    final rows = await db.query(
      tableName,
      where: 'user_id = ? AND state = 2',
      whereArgs: [userId],
      orderBy: 'position ASC',
    );
    return rows.map(BBWordProcess.fromMap).toList();
  }

  /// 重置学习等级（原版 resetLearningWordLevel）
  Future<void> resetLearningWordLevel() async {
    await db.rawUpdate('UPDATE $tableName SET level = 0 WHERE user_id = ?', [userId]);
  }

  /// 删除单词进度
  Future<void> deleteWord(String word) async {
    await db.delete(tableName, where: 'user_id = ? AND word = ?', whereArgs: [userId, word]);
  }
}
