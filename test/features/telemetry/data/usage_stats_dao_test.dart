// UsageStatsDao 的 SQLite 行为测试（2026-10-15 审计 R3-E01 补：此前该 DAO **没有任何测试**）。
//
// 为什么这个文件重要：这个 DAO 的失败路径是「只上报不抛」，所以一旦语句在
// 某些设备上跑不通，表现是**静默不落盘**而不是报错。第三轮审计就是在这里发现
// UPSERT 在 Android ≤9 上会语法错（见 test/architecture/sqlite_compat_guard_test.dart）。
// 这里用真 SQLite（ffi 内存库）钉住读写语义。
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/features/telemetry/data/usage_stats_dao.dart';
import 'package:word_app/features/telemetry/domain/usage_daily_stats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late UsageStatsDao dao;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(inMemoryDatabasePath);
    // 与 user_database._createUsageStatsTables 的 DDL 保持一致。
    await db.execute('''
      CREATE TABLE usage_stats_daily (
        day TEXT PRIMARY KEY,
        foreground_ms INTEGER NOT NULL DEFAULT 0,
        session_count INTEGER NOT NULL DEFAULT 0,
        study_session_count INTEGER NOT NULL DEFAULT 0,
        words_reviewed INTEGER NOT NULL DEFAULT 0,
        words_correct INTEGER NOT NULL DEFAULT 0,
        new_words_learned INTEGER NOT NULL DEFAULT 0,
        book_word_count INTEGER NOT NULL DEFAULT 0,
        book_learned_count INTEGER NOT NULL DEFAULT 0,
        streak_days INTEGER NOT NULL DEFAULT 0,
        coins_earned INTEGER NOT NULL DEFAULT 0,
        module_open_counts TEXT NOT NULL DEFAULT '{}',
        uploaded_at INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE usage_stats_meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)
    ''');
    dao = UsageStatsDao(openDatabase: () async => db);
  });

  tearDown(() async {
    if (db.isOpen) await db.close();
  });

  UsageDailyStats stats({
    String day = '2026-10-15',
    int foregroundMs = 1000,
    int sessionCount = 1,
    int wordsReviewed = 10,
    int wordsCorrect = 9,
    Map<String, int> modules = const {'learn': 2},
  }) => UsageDailyStats(
    day: day,
    foregroundMs: foregroundMs,
    sessionCount: sessionCount,
    studySessionCount: 1,
    wordsReviewed: wordsReviewed,
    wordsCorrect: wordsCorrect,
    newWordsLearned: 3,
    bookWordCount: 4000,
    bookLearnedCount: 120,
    streakDays: 5,
    coinsEarned: 7,
    moduleOpenCounts: modules,
  );

  Future<int> rowCount() async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM usage_stats_daily');
    return (rows.first['c'] as int?) ?? -1;
  }

  Future<int?> uploadedAtOf(String day) async {
    final rows = await db.query('usage_stats_daily', columns: ['uploaded_at'], where: 'day = ?', whereArgs: [day]);
    return rows.isEmpty ? null : rows.first['uploaded_at'] as int?;
  }

  group('UsageStatsDao', () {
    test('首次 writeDay 落一行，readDay 原样读回（含 module_open_counts 的 JSON）', () async {
      await dao.writeDay(stats(modules: const {'learn': 4, 'review': 2}));

      expect(await rowCount(), 1);
      final read = await dao.readDay('2026-10-15');
      expect(read, isNotNull);
      expect(read!.foregroundMs, 1000);
      expect(read.wordsReviewed, 10);
      expect(read.wordsCorrect, 9);
      expect(read.bookLearnedCount, 120);
      expect(read.moduleOpenCounts, {'learn': 4, 'review': 2});
    });

    test('重复 writeDay 同一天：不新增行，字段被更新（不是删了重插）', () async {
      await dao.writeDay(stats(foregroundMs: 1000, wordsReviewed: 10));
      await dao.writeDay(stats(foregroundMs: 5000, wordsReviewed: 40));

      expect(await rowCount(), 1);
      final read = await dao.readDay('2026-10-15');
      expect(read!.foregroundMs, 5000);
      expect(read.wordsReviewed, 40);
    });

    test('重复 writeDay 保留 uploaded_at —— 已上报的日子不该被改回「未上报」', () async {
      await dao.writeDay(stats());
      await dao.markUploaded(['2026-10-15']);
      final before = await uploadedAtOf('2026-10-15');
      expect(before, isNotNull);

      await dao.writeDay(stats(foregroundMs: 9999));

      expect(await uploadedAtOf('2026-10-15'), before);
      expect(await dao.readPending(), isEmpty);
    });

    test('readPending 只取「未上报且有活动」的天，按日期升序', () async {
      await dao.writeDay(stats(day: '2026-10-13', foregroundMs: 100));
      await dao.writeDay(stats(day: '2026-10-14', foregroundMs: 200));
      // 无活动的日子不该占一行，否则「日活」会被稀释
      await dao.writeDay(UsageDailyStats(day: '2026-10-15'));
      await dao.writeDay(stats(day: '2026-10-16', foregroundMs: 400));
      await dao.markUploaded(['2026-10-14']);

      final pending = await dao.readPending();
      expect(pending.map((d) => d.day).toList(), ['2026-10-13', '2026-10-16']);
    });

    test('pruneUploadedBefore 只删「已上报且早于界限」的，未上报的必须保留', () async {
      await dao.writeDay(stats(day: '2026-09-01', foregroundMs: 100)); // 已上报、该删
      await dao.writeDay(stats(day: '2026-09-02', foregroundMs: 100)); // 未上报、必须留
      await dao.writeDay(stats(day: '2026-10-14', foregroundMs: 100)); // 太新、保留
      await dao.markUploaded(['2026-09-01']);

      await dao.pruneUploadedBefore(DateTime(2026, 10, 1));

      final remaining = (await db.query('usage_stats_daily', columns: ['day'])).map((r) => r['day'] as String).toList()
        ..sort();
      expect(remaining, ['2026-09-02', '2026-10-14']);
    });

    test('clearAll 清空两张表', () async {
      await dao.writeDay(stats());
      await dao.writeLastUploadAt(DateTime(2026, 10, 15));

      await dao.clearAll();

      expect(await rowCount(), 0);
      expect(await dao.readLastUploadAt(), isNull);
    });

    test('meta 往返：时间可读可写，writeNextAttemptAt(null) 表示清除退避', () async {
      expect(await dao.readLastUploadAt(), isNull);
      expect(await dao.readNextAttemptAt(), isNull);

      final at = DateTime.fromMillisecondsSinceEpoch(1760000000000);
      await dao.writeLastUploadAt(at);
      await dao.writeNextAttemptAt(at);

      expect(await dao.readLastUploadAt(), at);
      expect(await dao.readNextAttemptAt(), at);

      await dao.writeNextAttemptAt(null);
      expect(await dao.readNextAttemptAt(), isNull);
    });

    test('module_open_counts 存坏 JSON 时按空处理，不抛（旧版本写坏一行不该让整批失败）', () async {
      await db.insert('usage_stats_daily', {
        'day': '2026-10-15',
        'foreground_ms': 100,
        'module_open_counts': '{不是 JSON',
      });

      final read = await dao.readDay('2026-10-15');

      expect(read, isNotNull);
      expect(read!.moduleOpenCounts, isEmpty);
    });

    test('数据库不可用时全部方法静默降级（不抛）', () async {
      final broken = UsageStatsDao(openDatabase: () async => throw StateError('打不开'));

      await expectLater(broken.writeDay(stats()), completes);
      expect(await broken.readDay('2026-10-15'), isNull);
      expect(await broken.readPending(), isEmpty);
      await expectLater(broken.markUploaded(['2026-10-15']), completes);
      await expectLater(broken.clearAll(), completes);
      expect(await broken.readLastUploadAt(), isNull);
    });
  });
}
