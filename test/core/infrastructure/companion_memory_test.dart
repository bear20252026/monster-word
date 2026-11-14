// 学习伴侣 AI 化 · 记忆层单测。
// DAO：CRUD/分层/串行闸/journal 回放/未注入回退空记忆；curator：幂等沉淀+上下文组装。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/application/monster_memory_curator.dart';
import 'package:word_app/core/application/monster_memory_port.dart';
import 'package:word_app/core/infrastructure/companion_memory_dao.dart';

/// 每个调用独立临时文件库——`:memory:` 在同进程多次打开会共享同一库，
/// 造成跨测试数据泄漏，故用唯一文件路径隔离。
Future<Database> _openMemoryDb() async {
  final dir = await Directory.systemTemp.createTemp('companion_memory_test');
  final db = await openDatabase(p.join(dir.path, 'mem.db'));
  await db.execute('''
    CREATE TABLE IF NOT EXISTS companion_memory (
      kind TEXT NOT NULL, key TEXT NOT NULL, content TEXT NOT NULL, updated_at INTEGER NOT NULL,
      PRIMARY KEY (kind, key)
    )
  ''');
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactoryFfi;
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('CompanionMemoryDao（注入内存库）', () {
    test('put/get/read 分层读写，同键 upsert 覆盖', () async {
      final dao = CompanionMemoryDao(openDatabase: _openMemoryDb);
      await dao.put(MemoryKind.fact, 'streak', '连续签到 3 天');
      await dao.put(MemoryKind.fact, 'streak', '连续签到 5 天');
      await dao.put(MemoryKind.recent, 'r1', '昨天聊了旅行');

      final streak = await dao.get(MemoryKind.fact, 'streak');
      expect(streak?.content, '连续签到 5 天');
      final facts = await dao.read(MemoryKind.fact);
      expect(facts.length, 1);
      final recent = await dao.read(MemoryKind.recent);
      expect(recent.single.content, '昨天聊了旅行');
    });

    test('remove 删除指定键', () async {
      final dao = CompanionMemoryDao(openDatabase: _openMemoryDb);
      await dao.put(MemoryKind.fact, 'k', 'v');
      await dao.remove(MemoryKind.fact, 'k');
      expect(await dao.get(MemoryKind.fact, 'k'), isNull);
    });

    test('trimRecent 只保留最新 N 条', () async {
      final dao = CompanionMemoryDao(openDatabase: _openMemoryDb);
      for (var i = 0; i < 6; i++) {
        await dao.put(MemoryKind.recent, 'r$i', '记忆$i');
        // 保证 updated_at 递增（同毫秒可能相等）。
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      await dao.trimRecent(3);
      final recent = await dao.read(MemoryKind.recent);
      expect(recent.length, 3);
      expect(recent.first.content, '记忆5');
    });

    test('持久化到 SQLite：新实例重开同库可读回', () async {
      final db = await _openMemoryDb();
      final dao1 = CompanionMemoryDao(openDatabase: () async => db);
      await dao1.put(MemoryKind.fact, 'k', '持久值');
      final dao2 = CompanionMemoryDao(openDatabase: () async => db);
      expect((await dao2.get(MemoryKind.fact, 'k'))?.content, '持久值');
    });
  });

  group('CompanionMemoryDao（未注入回退）', () {
    test('FLUTTER_TEST 未注入 → 空记忆，读写不抛', () async {
      final dao = CompanionMemoryDao();
      expect(await dao.read(MemoryKind.fact), isEmpty);
      await dao.put(MemoryKind.fact, 'k', 'v'); // 内存态可读
      expect((await dao.get(MemoryKind.fact, 'k'))?.content, 'v');
      expect(dao.usesSqlite, isFalse);
    });
  });

  group('MonsterMemoryCurator', () {
    test('ingestLearningSnapshot 幂等沉淀事实层', () async {
      final dao = CompanionMemoryDao(openDatabase: _openMemoryDb);
      final curator = MonsterMemoryCurator(dao);
      const snap = LearningSnapshot(
        totalCheckinDays: 30,
        streakDays: 5,
        todayLearned: 8,
        dailyGoal: 10,
        dueCount: 12,
        coinBalance: 200,
      );
      await curator.ingestLearningSnapshot(snap);
      await curator.ingestLearningSnapshot(snap); // 再沉淀一次，不重复
      final facts = await dao.read(MemoryKind.fact);
      expect(facts.length, 5);
      expect((await dao.get(MemoryKind.fact, MonsterMemoryCurator.factStreak))?.content, '连续签到 5 天');
    });

    test('buildContext 组装事实+近期+人格', () async {
      final dao = CompanionMemoryDao(openDatabase: _openMemoryDb);
      final curator = MonsterMemoryCurator(dao);
      await curator.ingestLearningSnapshot(
        const LearningSnapshot(
          totalCheckinDays: 1,
          streakDays: 1,
          todayLearned: 1,
          dailyGoal: 10,
          dueCount: 0,
          coinBalance: 0,
        ),
      );
      await curator.recordRecent('r1', '用户说喜欢猫');
      await curator.recordPersona('p1', '性格活泼');
      final ctx = await curator.buildContext();
      expect(ctx, contains('相处模式'));
      expect(ctx, contains('学习近况'));
      expect(ctx, contains('最近记忆'));
      expect(ctx, contains('用户说喜欢猫'));
    });
  });
}
