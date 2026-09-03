// FSRS 学习记录 SQLite 持久化层（批次 E1，2026-09-04）。
//
// 独立库文件 review_schedule.db，与 wordbook.db / user_data.db 物理隔离：
// wordbook_database 有"检测坏库 → 删文件重建"逻辑，学习记录绝不能被词库
// 重建误伤，故不复用其库文件。
//
// 取代旧 SharedPreferences blob 方案（fsrs6_cards_v1 等三个 key 每次评分
// 全量 jsonEncode 重写）：写路径收敛为单事务 3 条语句，O(1)。
// 旧 SP key 本批保留为只读回滚快照，清理另列 E2 小批。
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';

/// 复习调度 SQLite 存储层。
///
/// 只负责行读写，不做业务判断；迁移编排（SP → SQLite）在
/// [ReviewScheduleRepository] 中完成，因为标记与旧数据都在 SP。
class ReviewScheduleStore {
  static const String defaultDbFileName = 'review_schedule.db';

  final Database _db;

  ReviewScheduleStore._(this._db);

  /// 仅供测试：注入既有 Database（推荐 sqflite_common_ffi 内存库），并确保建表。
  @visibleForTesting
  static Future<ReviewScheduleStore> forTest(Database db) async {
    await _createSchema(db);
    return ReviewScheduleStore._(db);
  }

  /// 打开默认位置的 review_schedule.db（不存在则建表）。
  ///
  /// 跨平台策略与词库一致：Windows/Linux 走 FFI，Android/iOS 走原生 sqflite。
  /// 有意不 import wordbook_database 复用其 ensurePlatform——学习数据层
  /// 与词库重建逻辑保持零耦合（独立库文件就是为防词库重建误伤）。
  static Future<ReviewScheduleStore> open({String? directoryPath}) async {
    // flutter test 的 widget 测试跑在 TestWidgetsFlutterBinding（FakeAsync）里，
    // 未 mock 的平台通道（path_provider）会永远挂起而非抛错，导致
    // repository.initialize() 死锁、pumpAndSettle 超时。测试环境下 fail-fast，
    // 让上层降级 SP 模式；需要真实存储的测试请用 forTest 注入内存库。
    // （integration_test 在真机上同样会设置 FLUTTER_TEST，若需真库同样走注入。）
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
      throw UnsupportedError('ReviewScheduleStore.open 不可用于 flutter test 环境');
    }
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dirPath = directoryPath ?? (await getApplicationSupportDirectory()).path;
    final db = await openDatabase(
      p.join(dirPath, defaultDbFileName),
      version: 1,
      onCreate: (db, _) => _createSchema(db),
    );
    // 防御旧文件缺表（理论上 onCreate 已覆盖，双保险成本为零）。
    await _createSchema(db);
    return ReviewScheduleStore._(db);
  }

  static Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fsrs_cards (
        word TEXT PRIMARY KEY,
        stability REAL NOT NULL,
        difficulty REAL NOT NULL,
        elapsed_days INTEGER NOT NULL DEFAULT 0,
        scheduled_days INTEGER NOT NULL DEFAULT 0,
        last_review TEXT NOT NULL,
        due_date TEXT NOT NULL,
        repetitions INTEGER NOT NULL DEFAULT 0,
        review_count INTEGER NOT NULL DEFAULT 0,
        is_new INTEGER NOT NULL DEFAULT 1,
        short_term_stability REAL NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_fsrs_cards_due ON fsrs_cards(is_new, due_date)');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fsrs_daily_stats (
        date TEXT PRIMARY KEY,
        learn INTEGER NOT NULL DEFAULT 0,
        review INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS fsrs_active_dates (
        date TEXT PRIMARY KEY
      )
    ''');
  }

  // ============================================================
  // 读路径（仅启动 _load 时各执行一次）
  // ============================================================

  Future<List<FsrsCard>> loadCards() async {
    final rows = await _db.query('fsrs_cards');
    return rows.map(_cardFromRow).toList(growable: false);
  }

  Future<Map<String, Map<String, int>>> loadDailyStats() async {
    final rows = await _db.query('fsrs_daily_stats');
    return {
      for (final row in rows) row['date']! as String: {'learn': row['learn']! as int, 'review': row['review']! as int},
    };
  }

  Future<Set<String>> loadActiveDates() async {
    final rows = await _db.query('fsrs_active_dates');
    return {for (final row in rows) row['date']! as String};
  }

  /// 卡片总行数（迁移校验用）。
  Future<int> cardCount() async {
    final result = await _db.rawQuery('SELECT COUNT(*) AS n FROM fsrs_cards');
    return (result.single['n'] as int?) ?? 0;
  }

  FsrsCard _cardFromRow(Map<String, Object?> row) => FsrsCard(
    word: row['word']! as String,
    stability: (row['stability']! as num).toDouble(),
    difficulty: (row['difficulty']! as num).toDouble(),
    elapsedDays: row['elapsed_days']! as int,
    scheduledDays: row['scheduled_days']! as int,
    lastReview: DateTime.parse(row['last_review']! as String),
    dueDate: DateTime.parse(row['due_date']! as String),
    repetitions: row['repetitions']! as int,
    reviewCount: row['review_count']! as int,
    isNew: (row['is_new']! as int) != 0,
    shortTermStability: (row['short_term_stability']! as num).toDouble(),
  );

  // ============================================================
  // 写路径（评分 O(1) 单事务：1 卡片行 + 1 统计行 + 1 活跃日期）
  // ============================================================

  /// 评分落库：卡片 UPSERT + 今日统计自增 + 活跃日期忽略式插入。
  Future<void> recordRating({required FsrsCard card, required String dateKey, required bool isLearn}) async {
    await _db.transaction((txn) async {
      await txn.insert('fsrs_cards', _cardToRow(card), conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.rawInsert(
        'INSERT INTO fsrs_daily_stats(date, learn, review) VALUES(?, ?, ?) '
        'ON CONFLICT(date) DO UPDATE SET '
        'learn = learn + excluded.learn, review = review + excluded.review',
        [dateKey, isLearn ? 1 : 0, isLearn ? 0 : 1],
      );
      await txn.insert('fsrs_active_dates', {'date': dateKey}, conflictAlgorithm: ConflictAlgorithm.ignore);
    });
  }

  /// 遗留会话"重学"：删除单张卡片。
  Future<void> deleteCard(String word) async {
    await _db.delete('fsrs_cards', where: 'word = ?', whereArgs: [word]);
  }

  /// 迁移用：单事务批量插入卡片，任一行失败整体回滚。
  ///
  /// 事务提交前校验行数 == cards.length，不达标抛错回滚——
  /// 杜绝"半截迁移被下次启动误判为已完成"。
  Future<void> insertCardsInTransaction(List<FsrsCard> cards) async {
    await _db.transaction((txn) async {
      for (final card in cards) {
        await txn.insert('fsrs_cards', _cardToRow(card), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final result = await txn.rawQuery('SELECT COUNT(*) AS n FROM fsrs_cards');
      final count = (result.single['n'] as int?) ?? 0;
      if (count != cards.length) {
        throw StateError('迁移行数校验失败：预期 ${cards.length}，实际 $count');
      }
    });
  }

  /// 迁移用：单事务批量写入每日统计（累加语义，防重复迁移翻倍）。
  Future<void> mergeDailyStatsInTransaction(Map<String, Map<String, int>> stats) async {
    await _db.transaction((txn) async {
      for (final entry in stats.entries) {
        final learn = entry.value['learn'] ?? 0;
        final review = entry.value['review'] ?? 0;
        await txn.rawInsert(
          'INSERT INTO fsrs_daily_stats(date, learn, review) VALUES(?, ?, ?) '
          'ON CONFLICT(date) DO UPDATE SET '
          'learn = learn + excluded.learn, review = review + excluded.review',
          [entry.key, learn, review],
        );
      }
    });
  }

  /// 迁移用：单事务批量写入活跃日期。
  Future<void> insertActiveDatesInTransaction(Set<String> dates) async {
    await _db.transaction((txn) async {
      for (final date in dates) {
        await txn.insert('fsrs_active_dates', {'date': date}, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Map<String, Object?> _cardToRow(FsrsCard card) => {
    'word': card.word,
    'stability': card.stability,
    'difficulty': card.difficulty,
    'elapsed_days': card.elapsedDays,
    'scheduled_days': card.scheduledDays,
    'last_review': card.lastReview.toIso8601String(),
    'due_date': card.dueDate.toIso8601String(),
    'repetitions': card.repetitions,
    'review_count': card.reviewCount,
    'is_new': card.isNew ? 1 : 0,
    'short_term_stability': card.shortTermStability,
  };
}
