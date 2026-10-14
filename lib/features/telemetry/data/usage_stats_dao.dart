// 使用统计的本地持久化（SQLite，表在 user_data.db 里，见 user_database.dart 的
// _createUsageStatsTables，schema v7 引入）。
//
// 放在 feature 的 data 层而不是 core/infrastructure：它实现的是本 feature 的
// UsageStatsStore 端口。若放 core，core 就要反向依赖 feature 的 application —— 分层是反的。
// （account 的 secure_password_auth_store 同样在 feature data 层。）
//
// 实现要点：
//   - 写用 INSERT OR REPLACE：一天一行，主键是日期，天然幂等；
//   - 读-改-写由调用方（collector）串行发起，本层不做缓存 —— 统计写入频率极低
//     （进前台、切后台、完成一次学习会话），不值得为它引入缓存与失效逻辑；
//   - **所有方法都不抛**：统计是附加能力，任何失败都不该影响学习主流程。
//     失败只上报给 Sentry（reportSwallowedError）。

import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/telemetry/application/usage_stats_collector.dart';
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';
import 'package:word_app/features/telemetry/domain/usage_daily_stats.dart';

class UsageStatsDao implements UsageStatsStore {
  UsageStatsDao({Future<Database> Function()? openDatabase}) : _openOverride = openDatabase;

  /// 测试注入口：提供即绕过 UserDatabase 单例，直接用注入的库。
  final Future<Database> Function()? _openOverride;

  static const String _dailyTable = 'usage_stats_daily';
  static const String _metaTable = 'usage_stats_meta';
  static const String _keyLastUploadAt = 'last_upload_at_ms';
  static const String _keyNextAttemptAt = 'next_attempt_at_ms';

  /// 取数据库。初始化失败返回 null（调用方一律降级为「不统计」）。
  Future<Database?> _dbOrNull() async {
    try {
      if (_openOverride != null) return await _openOverride();
      await UserDatabase.instance.initialize();
      return UserDatabase.instance.db;
    } catch (e, s) {
      reportSwallowedError('UsageStatsDao 打开数据库失败（降级为不统计）', e, s);
      return null;
    }
  }

  @override
  Future<UsageDailyStats?> readDay(String day) async {
    final db = await _dbOrNull();
    if (db == null) return null;
    try {
      final rows = await db.query(_dailyTable, where: 'day = ?', whereArgs: [day], limit: 1);
      if (rows.isEmpty) return null;
      return _fromRow(rows.first);
    } catch (e, s) {
      reportSwallowedError('UsageStatsDao.readDay', e, s);
      return null;
    }
  }

  @override
  Future<void> writeDay(UsageDailyStats stats) async {
    final db = await _dbOrNull();
    if (db == null) return;
    try {
      // 保留 uploaded_at：这一天可能已经上报过，重写不该把它变回「未上报」，
      // 否则下一轮会重复上报同一天（服务端要靠 (device_id, day) 去重兜底，
      // 但客户端不该主动制造重复）。
      await db.rawInsert(
        '''
        INSERT INTO $_dailyTable (
          day, foreground_ms, session_count, study_session_count,
          words_reviewed, words_correct, new_words_learned,
          book_word_count, book_learned_count, streak_days, coins_earned,
          module_open_counts, uploaded_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, (SELECT uploaded_at FROM $_dailyTable WHERE day = ?))
        ON CONFLICT(day) DO UPDATE SET
          foreground_ms = excluded.foreground_ms,
          session_count = excluded.session_count,
          study_session_count = excluded.study_session_count,
          words_reviewed = excluded.words_reviewed,
          words_correct = excluded.words_correct,
          new_words_learned = excluded.new_words_learned,
          book_word_count = excluded.book_word_count,
          book_learned_count = excluded.book_learned_count,
          streak_days = excluded.streak_days,
          coins_earned = excluded.coins_earned,
          module_open_counts = excluded.module_open_counts
      ''',
        [
          stats.day,
          stats.foregroundMs,
          stats.sessionCount,
          stats.studySessionCount,
          stats.wordsReviewed,
          stats.wordsCorrect,
          stats.newWordsLearned,
          stats.bookWordCount,
          stats.bookLearnedCount,
          stats.streakDays,
          stats.coinsEarned,
          jsonEncode(stats.moduleOpenCounts),
          stats.day,
        ],
      );
    } catch (e, s) {
      reportSwallowedError('UsageStatsDao.writeDay', e, s);
    }
  }

  @override
  Future<List<UsageDailyStats>> readPending({int limit = 31}) async {
    final db = await _dbOrNull();
    if (db == null) return const [];
    try {
      // 有活动才值得上报 —— 与 UsageDailyStats.hasActivity 同一口径。
      // 装了但没打开的日子不该占一行，否则「日活」这类指标会被稀释。
      final rows = await db.rawQuery(
        '''
        SELECT * FROM $_dailyTable
        WHERE uploaded_at IS NULL
          AND (foreground_ms > 0 OR session_count > 0 OR study_session_count > 0
               OR words_reviewed > 0 OR new_words_learned > 0)
        ORDER BY day ASC
        LIMIT ?
      ''',
        [limit],
      );
      return rows.map(_fromRow).toList();
    } catch (e, s) {
      reportSwallowedError('UsageStatsDao.readPending', e, s);
      return const [];
    }
  }

  @override
  Future<void> markUploaded(Iterable<String> days) async {
    final list = days.toList();
    if (list.isEmpty) return;
    final db = await _dbOrNull();
    if (db == null) return;
    try {
      final placeholders = List.filled(list.length, '?').join(',');
      await db.rawUpdate('UPDATE $_dailyTable SET uploaded_at = ? WHERE day IN ($placeholders)', [
        DateTime.now().millisecondsSinceEpoch,
        ...list,
      ]);
    } catch (e, s) {
      reportSwallowedError('UsageStatsDao.markUploaded', e, s);
    }
  }

  @override
  Future<void> pruneUploadedBefore(DateTime before) async {
    final db = await _dbOrNull();
    if (db == null) return;
    try {
      // 按**数据日期**而不是上报时间清理：保留期说的是「多久之前的使用数据不再留」。
      // 只删已上报的：未上报的可能是网络一直不通攒下来的，删了就永久丢了。
      await db.delete(
        _dailyTable,
        where: 'uploaded_at IS NOT NULL AND day < ?',
        whereArgs: [UsageStatsCollector.dayKey(before)],
      );
    } catch (e, s) {
      reportSwallowedError('UsageStatsDao.pruneUploadedBefore', e, s);
    }
  }

  @override
  Future<DateTime?> readLastUploadAt() => _readMetaTime(_keyLastUploadAt);

  @override
  Future<void> writeLastUploadAt(DateTime at) => _writeMetaTime(_keyLastUploadAt, at);

  @override
  Future<DateTime?> readNextAttemptAt() => _readMetaTime(_keyNextAttemptAt);

  @override
  Future<void> writeNextAttemptAt(DateTime? at) async {
    final db = await _dbOrNull();
    if (db == null) return;
    try {
      if (at == null) {
        await db.delete(_metaTable, where: 'key = ?', whereArgs: [_keyNextAttemptAt]);
      } else {
        await _writeMetaTime(_keyNextAttemptAt, at);
      }
    } catch (e, s) {
      reportSwallowedError('UsageStatsDao.writeNextAttemptAt', e, s);
    }
  }

  @override
  Future<void> clearAll() async {
    final db = await _dbOrNull();
    if (db == null) return;
    try {
      await db.delete(_dailyTable);
      await db.delete(_metaTable);
    } catch (e, s) {
      reportSwallowedError('UsageStatsDao.clearAll', e, s);
    }
  }

  Future<DateTime?> _readMetaTime(String key) async {
    final db = await _dbOrNull();
    if (db == null) return null;
    try {
      final rows = await db.query(_metaTable, where: 'key = ?', whereArgs: [key], limit: 1);
      if (rows.isEmpty) return null;
      final ms = int.tryParse('${rows.first['value']}');
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (e, s) {
      reportSwallowedError('UsageStatsDao._readMetaTime', e, s);
      return null;
    }
  }

  Future<void> _writeMetaTime(String key, DateTime at) async {
    final db = await _dbOrNull();
    if (db == null) return;
    try {
      await db.insert(_metaTable, {
        'key': key,
        'value': '${at.millisecondsSinceEpoch}',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e, s) {
      reportSwallowedError('UsageStatsDao._writeMetaTime', e, s);
    }
  }

  /// 行 → 模型。module_open_counts 是 JSON 文本；解析失败按空处理
  /// （旧版本写坏一行不该让整批上报失败）。
  UsageDailyStats _fromRow(Map<String, Object?> row) {
    Map<String, Object?> modules = const {};
    final raw = row['module_open_counts'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) modules = decoded.cast<String, Object?>();
      } catch (e, s) {
        reportSwallowedError('UsageStatsDao.module_open_counts 解析失败', e, s);
      }
    }
    return UsageDailyStats.fromJson({
      'day': row['day'],
      'foreground_ms': row['foreground_ms'],
      'session_count': row['session_count'],
      'study_session_count': row['study_session_count'],
      'words_reviewed': row['words_reviewed'],
      'words_correct': row['words_correct'],
      'new_words_learned': row['new_words_learned'],
      'book_word_count': row['book_word_count'],
      'book_learned_count': row['book_learned_count'],
      'streak_days': row['streak_days'],
      'coins_earned': row['coins_earned'],
      'module_open_counts': modules,
    });
  }
}
