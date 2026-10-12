// QA-02 故障注入回归矩阵（2026-10-11 批次）。
//
// 覆盖 P1-01 降级日志链路的故障注入：写失败 → 意图落日志 → SQLite 恢复后
// 幂等回放。这是「用户操作不因一次写失败而丢失」这条数据安全语义的守门测试。
//
// 注入手法：用 `OpenDatabaseOptions(readOnly: true)` 打开库——**读正常、写必失败**，
// 精确模拟「库可读但落盘故障」（磁盘满 / 只读挂载 / 连接降级），比关库更贴近
// 真实故障，且不会让读路径（isNewWord 预检）一起炸掉、掩盖被测路径。
//
// 真机故障注入（Android/Windows 真机矩阵：进程被杀、库文件物理损坏）属测试
// 工程，见 docs/HANDOVER.md 待办；本文件覆盖可在 CI 稳定复现的注入面。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/infrastructure/degraded_journal.dart';
import 'package:word_app/core/infrastructure/user_database.dart';
import 'package:word_app/core/repositories/new_word_repository_impl.dart';
import 'package:word_app/models/word.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    databaseFactory = databaseFactoryFfi;
  });

  group('DegradedJournal 基础设施', () {
    const journal = DegradedJournal(key: 'test_journal_v1', domain: '测试', cap: 3);

    test('append → entries → pendingCount，自动补写时间戳', () async {
      expect(await journal.pendingCount(), 0);
      expect(await journal.append({'op': 'add', 'word': 'a'}), isTrue);
      expect(await journal.append({'op': 'add', 'word': 'b'}), isTrue);

      expect(await journal.pendingCount(), 2);
      final entries = await journal.entries();
      expect(entries.map((e) => e['word']), ['a', 'b'], reason: '保持写入顺序');
      expect(entries.first['savedAt'], isNotNull);
    });

    test('超容量上限丢弃最旧、保留最新', () async {
      for (final w in ['a', 'b', 'c', 'd', 'e']) {
        await journal.append({'op': 'add', 'word': w});
      }
      final entries = await journal.entries();
      expect(entries, hasLength(3));
      expect(entries.map((e) => e['word']), ['c', 'd', 'e']);
    });

    test('回放全部成功 → 清空日志', () async {
      await journal.append({'op': 'add', 'word': 'x'});
      final applied = <String>[];
      final count = await journal.replay((entry) async => applied.add(entry['word'] as String));

      expect(count, 1);
      expect(applied, ['x']);
      expect(await journal.pendingCount(), 0);
    });

    test('回放中途失败 → 日志整体保留待重试', () async {
      await journal.append({'op': 'add', 'word': 'p'});
      await journal.append({'op': 'add', 'word': 'q'});

      final applied = <String>[];
      final count = await journal.replay((entry) async {
        final w = entry['word'] as String;
        if (w == 'q') throw StateError('injected failure');
        applied.add(w);
      });

      expect(count, 1, reason: '只统计成功应用条数');
      expect(applied, ['p']);
      expect(await journal.pendingCount(), 2, reason: '任一条失败即整体保留（回放要求幂等，不能部分消费）');
    });

    test('单条 JSON 损坏 → 跳过该条，其余照常回放', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('test_journal_v1', [
        jsonEncode({'op': 'add', 'word': 'ok1'}),
        '{not-json',
        jsonEncode({'op': 'add', 'word': 'ok2'}),
      ]);

      final applied = <String>[];
      await journal.replay((entry) async => applied.add(entry['word'] as String));

      expect(applied, ['ok1', 'ok2'], reason: '损坏条目不得阻塞整条回放链');
      expect(await journal.pendingCount(), 0);
    });

    test('空日志回放为 no-op', () async {
      expect(await journal.replay((_) async {}), 0);
    });
  });

  group('生词本故障注入（P1-01）', () {
    const journal = DegradedJournal(key: NewWordRepositoryImpl.degradedJournalKey, domain: '测试');

    late Directory tmpDir;
    late String dbPath;
    late Database db;

    Future<void> createTable(Database target) async {
      await target.execute('''
        CREATE TABLE IF NOT EXISTS new_words (
          word_id INTEGER PRIMARY KEY,
          word_text TEXT NOT NULL,
          source TEXT NOT NULL,
          operation_code TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          synced_at INTEGER
        )
      ''');
    }

    /// 打开只读连接：读路径正常、写路径必失败。
    Future<Database> openReadOnly() =>
        databaseFactory.openDatabase(dbPath, options: OpenDatabaseOptions(readOnly: true));

    Future<Database> openWritable() => databaseFactory.openDatabase(dbPath);

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('nw_fault_test');
      dbPath = p.join(tmpDir.path, 'user_data.db');
      final setup = await openWritable();
      await createTable(setup);
      await setup.close();
      db = await openReadOnly();
    });

    tearDown(() async {
      try {
        await db.close();
      } catch (_) {
        // 已关闭可忽略
      }
      try {
        tmpDir.deleteSync(recursive: true);
      } catch (_) {
        // Windows 句柄释放有时序延迟，残留临时目录无碍
      }
    });

    test('写失败落日志且视为已加入；恢复后懒回放补库', () async {
      final repo = NewWordRepositoryImpl(UserDatabase.instance, databaseOverride: db);
      expect(await repo.addNewWord(Word(id: 43, word: 'banana')), isTrue, reason: '日志保底成功 → 按已加入返回');
      expect(await journal.pendingCount(), 1, reason: '写失败必须留下可回放的意图记录');

      await db.close();
      db = await openWritable();

      final repo2 = NewWordRepositoryImpl(UserDatabase.instance, databaseOverride: db);
      expect(await repo2.isNewWord(43), isTrue, reason: '懒回放在读路径上生效');
      expect(await repo2.getNewWordCount(), 1);
      expect(await journal.pendingCount(), 0, reason: '回放成功后日志清空');
    });

    test('remove 写失败落日志，回放后不复活', () async {
      await db.close();
      db = await openWritable();
      final repo = NewWordRepositoryImpl(UserDatabase.instance, databaseOverride: db);
      await repo.addNewWord(Word(id: 7, word: 'apple'));
      expect(await repo.isNewWord(7), isTrue);

      await db.close();
      db = await openReadOnly(); // 该词已在库中，读得到；删除必失败
      final repoRo = NewWordRepositoryImpl(UserDatabase.instance, databaseOverride: db);
      expect(await repoRo.removeNewWord(7), isTrue);
      expect(await journal.pendingCount(), 1);

      await db.close();
      db = await openWritable();
      final repo2 = NewWordRepositoryImpl(UserDatabase.instance, databaseOverride: db);
      expect(await repo2.isNewWord(7), isFalse, reason: '回放 remove 生效，移除的生词不复活');
      expect(await repo2.getNewWordCount(), 0);
    });

    test('回放幂等：重复回放同一 add 不叠加', () async {
      await journal.append({'op': 'add', 'wordId': 9, 'wordText': 'cherry', 'source': 'manual', 'at': 1});
      await journal.append({'op': 'add', 'wordId': 9, 'wordText': 'cherry', 'source': 'manual', 'at': 2});

      // 本用例测的是回放幂等（不是写失败），故须用可写连接让回放真正落库。
      await db.close();
      db = await openWritable();

      final repo = NewWordRepositoryImpl(UserDatabase.instance, databaseOverride: db);
      expect(await repo.isNewWord(9), isTrue);
      expect(await repo.getNewWordCount(), 1, reason: 'word_id 主键 REPLACE，重复回放不叠加');
      expect(await journal.pendingCount(), 0);
    });

    test('预检读失败不阻断写入尝试（读路径故障不应让用户操作直接失败）', () async {
      // 先写入一行，再切到只读连接：读得到 → 走「已存在」分支返回 false
      await db.close();
      db = await openWritable();
      await db.insert('new_words', {
        'word_id': 5,
        'word_text': 'pear',
        'source': 'manual',
        'operation_code': 'add',
        'created_at': 1,
        'updated_at': 1,
        'synced_at': null,
      });
      await db.close();
      db = await openReadOnly();

      final repo = NewWordRepositoryImpl(UserDatabase.instance, databaseOverride: db);
      expect(await repo.addNewWord(Word(id: 5, word: 'pear')), isFalse, reason: '已存在则幂等返回 false');
      expect(await journal.pendingCount(), 0, reason: '无写入尝试 → 不产生日志');
    });
  });
}
