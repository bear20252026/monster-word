// M3：XpDao 幂等落库测试（真实 SQLite 内存库）。
//
// 只验证两件事：同一事件键不会重复加经验；xp_state 单行累加正确。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/features/progress/data/xp_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS xp_state (
        id INTEGER PRIMARY KEY,
        total_xp INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reward_events (
        event_key TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )
    ''');
  });

  tearDown(() async {
    await db.close();
  });

  test('首次读取：没有记录时为 0（老用户从 0 起算）', () async {
    final dao = XpDao(openDatabase: () async => db);
    expect(await dao.loadTotalXp(), 0);
    expect(dao.usesSqlite, isTrue);
  });

  test('累加写入单行，重复读取得同一值', () async {
    final dao = XpDao(openDatabase: () async => db);
    expect(await dao.addXpOnce(eventKey: 'xp:learn:1', delta: 20), 20);
    expect(await dao.addXpOnce(eventKey: 'xp:learn:2', delta: 15), 35);
    expect(await dao.loadTotalXp(), 35);
    final rows = await db.query('xp_state');
    expect(rows.length, 1, reason: 'xp_state 恒为单行');
    expect(rows.first['total_xp'], 35);
  });

  test('同一事件键重复写入：返回 null，累计不变', () async {
    final dao = XpDao(openDatabase: () async => db);
    expect(await dao.addXpOnce(eventKey: 'xp:learn:dup', delta: 20), 20);
    expect(await dao.addXpOnce(eventKey: 'xp:learn:dup', delta: 20), isNull);
    expect(await dao.loadTotalXp(), 20);
    final events = await db.query('reward_events', where: 'event_key = ?', whereArgs: ['xp:learn:dup']);
    expect(events.length, 1, reason: '事件键只落一行');
  });

  test('并发重复结算：只加一次', () async {
    final dao = XpDao(openDatabase: () async => db);
    final results = await Future.wait([
      dao.addXpOnce(eventKey: 'xp:review:concurrent', delta: 12),
      dao.addXpOnce(eventKey: 'xp:review:concurrent', delta: 12),
    ]);
    expect(results.whereType<int>().length, 1, reason: '两个并发结算只有一次真正写入');
    expect(await dao.loadTotalXp(), 12);
  });

  test('非正数增量不写入、不落事件键', () async {
    final dao = XpDao(openDatabase: () async => db);
    expect(await dao.addXpOnce(eventKey: 'xp:learn:zero', delta: 0), isNull);
    expect(await dao.loadTotalXp(), 0);
    expect((await db.query('reward_events')).isEmpty, isTrue);
  });

  test('审计 A6：瞬态写失败不粘性降级，恢复后仍落 SQLite', () async {
    final dao = XpDao(openDatabase: () async => db);
    expect(await dao.addXpOnce(eventKey: 'xp:a6:1', delta: 10), 10);
    // 制造一次瞬态写失败：删表 → 本次回退内存，但不得置 _useSqlite=false。
    await db.execute('DROP TABLE reward_events');
    expect(await dao.addXpOnce(eventKey: 'xp:a6:2', delta: 5), isNotNull);
    expect(dao.usesSqlite, isTrue, reason: '瞬态失败不得粘性降级');
    // 恢复表后下一次写入必须真正落库（旧实现此后永久只存内存）。
    await db.execute('CREATE TABLE reward_events (event_key TEXT PRIMARY KEY, created_at INTEGER NOT NULL)');
    expect(await dao.addXpOnce(eventKey: 'xp:a6:3', delta: 7), isNotNull);
    final events = await db.query('reward_events', where: 'event_key = ?', whereArgs: ['xp:a6:3']);
    expect(events.length, 1, reason: '恢复后写入必须落 SQLite');
  });
}
