// 审计 A3（2026-11-15）：daily_missions 写路径事务化 + 非粘性降级回归。
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/features/missions/application/daily_mission_repository.dart';
import 'package:word_app/features/missions/data/daily_mission_dao.dart';
import 'package:word_app/features/missions/domain/daily_mission.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(inMemoryDatabasePath);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_missions (
        day TEXT NOT NULL,
        task_id TEXT NOT NULL,
        progress INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER,
        reward_claimed_at INTEGER,
        PRIMARY KEY (day, task_id)
      )
    ''');
  });

  tearDown(() async => db.close());

  test('并发同 (day,task) 写入不撞主键、不降级', () async {
    final dao = DailyMissionDao(openDatabase: () async => db);
    const id = DailyMissionId.learnNew;
    await Future.wait([for (var i = 0; i < 5; i++) dao.save('2026-11-15', id, DailyMissionRecord(progress: i + 1))]);
    expect(dao.usesSqlite, isTrue, reason: '事务串行化后并发写不得撞主键降级');
    final rows = await db.query('daily_missions');
    expect(rows.length, 1, reason: '同 (day,task) 恒一行');
  });

  test('瞬态写失败不粘性降级，恢复后仍落 SQLite', () async {
    final dao = DailyMissionDao(openDatabase: () async => db);
    const id = DailyMissionId.learnNew;
    await dao.save('2026-11-15', id, DailyMissionRecord(progress: 1));
    await db.execute('DROP TABLE daily_missions');
    await dao.save('2026-11-15', id, DailyMissionRecord(progress: 2)); // 瞬态失败
    expect(dao.usesSqlite, isTrue, reason: '瞬态失败不得粘性降级');
    await db.execute('''
      CREATE TABLE daily_missions (
        day TEXT NOT NULL, task_id TEXT NOT NULL, progress INTEGER NOT NULL DEFAULT 0,
        completed_at INTEGER, reward_claimed_at INTEGER, PRIMARY KEY (day, task_id)
      )
    ''');
    await dao.save('2026-11-15', id, DailyMissionRecord(progress: 3));
    final rows = await db.query('daily_missions');
    expect(rows.single['progress'], 3, reason: '恢复后写入必须落 SQLite');
  });
}
