// MEM/U3：FavSentenceDao 测试。
// SQLite（注入内存库）为事实来源：迁移无损往返、同步索引判重、单行写；
// FLUTTER_TEST 下未注入的默认实例回退旧 SP 行为。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/degraded_journal.dart';
import 'package:word_app/core/infrastructure/fav_sentence_dao.dart';
import 'package:word_app/models/sentence_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(inMemoryDatabasePath);
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
  });

  tearDown(() async {
    await db.close();
  });

  String spPayload(List<Map<String, dynamic>> items) => jsonEncode(items);

  Map<String, dynamic> legacyEntry({
    required String sentenceId,
    required String english,
    String updateTime = '20260901010101',
  }) => {
    'word': 'apple',
    'wordId': 7,
    'sentenceId': sentenceId,
    'sentenceData': {'sid': sentenceId, 'e': english, 'c': '中文', 'b': '标题', 'u': 'https://audio/$sentenceId'},
    'wordUsage': '',
    'updateTime': updateTime,
    'type': 0,
  };

  group('FavSentenceDao（MEM/U3 SQLite 模式）', () {
    test('SP → SQLite 首启迁移：载荷无损往返、时间倒序、SP 快照保留', () async {
      SharedPreferences.setMockInitialValues({
        'fav_sentence_list': spPayload([
          legacyEntry(sentenceId: '10001', english: 'old sentence', updateTime: '20260901010101'),
          legacyEntry(sentenceId: '20002', english: 'new sentence', updateTime: '20260902020202'),
        ]),
      });
      final dao = FavSentenceDao(openDatabase: () async => db);
      final all = await dao.loadAll();

      expect(dao.usesSqlite, isTrue);
      expect(all, hasLength(2));
      expect(all.first.sentenceId, '20002', reason: '按 update_time 倒序');
      // 载荷无损：例句英文/中文/音频 URL 均完整保留
      final restored = all.firstWhere((e) => e.sentenceId == '20002');
      expect(restored.sentenceData?.e, 'new sentence');
      expect(restored.sentenceData?.c, '中文');
      expect(restored.sentenceData?.u, 'https://audio/20002');
      expect(restored.wordId, 7);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fav_sentence_sqlite_migrated_v1'), 'done');
      expect(prefs.getString('fav_sentence_list'), isNotNull, reason: 'SP 快照保留为回滚依据');
    });

    test('同步判重索引 + 单行写：add/remove/toggle 与 favCount 一致', () async {
      final dao = FavSentenceDao(openDatabase: () async => db);
      await dao.loadAll();

      final added = await dao.addFavSentence(
        word: 'apple',
        wordId: 7,
        sentenceId: '30003',
        sentenceData: SentenceData(sid: '30003', e: 'An apple a day.', c: '一天一苹果。'),
      );
      expect(added, isTrue);
      expect(dao.isFavSentence(7, '30003'), isTrue, reason: '同步判重走索引，无需先 loadAll');
      expect(dao.favCount, 1);

      expect(
        await dao.addFavSentence(
          word: 'apple',
          wordId: 7,
          sentenceId: '30003',
          sentenceData: SentenceData(sid: '30003', e: 'dup'),
        ),
        isFalse,
        reason: '重复收藏被拒绝',
      );

      final all = await dao.loadAll();
      expect(all.single.sentenceData?.e, 'An apple a day.', reason: '新增行载荷完整');

      expect(await dao.removeFavSentence(7, '30003'), isTrue);
      expect(dao.isFavSentence(7, '30003'), isFalse);
      expect(dao.favCount, 0);
      expect(await db.query('favorite_sentences'), isEmpty);
    });
  });

  group('FavSentenceDao（MEM/U3+分页 countAll/loadPage）', () {
    test('SQLite：COUNT 口径与按更新时间倒序的窗口切片', () async {
      SharedPreferences.setMockInitialValues({
        'fav_sentence_list': spPayload([
          legacyEntry(sentenceId: '10001', english: 's1', updateTime: '20260901010101'),
          legacyEntry(sentenceId: '20002', english: 's2', updateTime: '20260902020202'),
          legacyEntry(sentenceId: '30003', english: 's3', updateTime: '20260903030303'),
        ]),
      });
      final dao = FavSentenceDao(openDatabase: () async => db);

      expect(await dao.countAll(), 3);
      final page0 = await dao.loadPage(limit: 2);
      expect(page0.map((e) => e.sentenceId).toList(), ['30003', '20002']);
      final page1 = await dao.loadPage(limit: 2, offset: 2);
      expect(page1.map((e) => e.sentenceId).toList(), ['10001']);
      final beyond = await dao.loadPage(limit: 2, offset: 3);
      expect(beyond, isEmpty);
    });

    test('SP 回退：分页为缓存切片', () async {
      SharedPreferences.setMockInitialValues({
        'fav_sentence_list': spPayload([
          legacyEntry(sentenceId: '10001', english: 's1', updateTime: '20260901010101'),
          legacyEntry(sentenceId: '20002', english: 's2', updateTime: '20260902020202'),
        ]),
      });
      final dao = FavSentenceDao();
      expect(await dao.countAll(), 2);
      final page = await dao.loadPage(limit: 5, offset: 1);
      expect(page.single.sentenceId, '10001');
    });
  });

  group('FavSentenceDao（FLUTTER_TEST 未注入 → SP 回退）', () {
    test('保持迁移前的 SP 行为', () async {
      SharedPreferences.setMockInitialValues({
        'fav_sentence_list': spPayload([legacyEntry(sentenceId: '10001', english: 'legacy sentence')]),
      });
      final dao = FavSentenceDao();
      final all = await dao.loadAll();

      expect(dao.usesSqlite, isFalse);
      expect(all.single.sentenceData?.e, 'legacy sentence');
      expect(dao.favCount, 1);

      await dao.addFavSentence(
        word: 'apple',
        wordId: 9,
        sentenceId: '90009',
        sentenceData: SentenceData(sid: '90009', e: 'fresh'),
      );
      final prefs = await SharedPreferences.getInstance();
      final persisted = jsonDecode(prefs.getString('fav_sentence_list')!) as List<dynamic>;
      expect(persisted, hasLength(2));
      expect(await db.query('favorite_sentences'), isEmpty, reason: '回退模式不触碰 SQLite');
    });
  });

  group('REG-AUDIT（I19）批量取消收藏单事务', () {
    test('removeFavSentencesBatch：一次移除多条、索引同步回退、返回实际条数', () async {
      final dao = FavSentenceDao(openDatabase: () async => db);
      await dao.loadAll();
      for (var i = 0; i < 5; i++) {
        await dao.addFavSentence(
          word: 'apple',
          wordId: 7,
          sentenceId: '9000$i',
          sentenceData: SentenceData(sid: '9000$i', e: 'sentence $i', c: ''),
        );
      }
      expect(dao.favCount, 5);

      final removed = await dao.removeFavSentencesBatch([
        (wordId: 7, sentenceId: '90001'),
        (wordId: 7, sentenceId: '90003'),
        (wordId: 7, sentenceId: '99999'), // 不存在：不计入
      ]);

      expect(removed, 2, reason: '只统计实际删除行');
      expect(dao.favCount, 3, reason: '同步索引与 DB 保持一致');
      expect(dao.isFavSentence(7, '90001'), isFalse);
      expect(dao.isFavSentence(7, '90002'), isTrue);
      expect(dao.isFavSentence(7, '90003'), isFalse);
      expect((await db.query('favorite_sentences')).length, 3);
    });
  });

  group('REG-AUDIT-003 SP 损坏中止迁移与持久化失败回滚', () {
    test('SP 快照损坏：中止迁移走 SP 回退，不写 marker、原档保留', () async {
      const corrupted = '{"not-json';
      SharedPreferences.setMockInitialValues({'fav_sentence_list': corrupted});

      final dao = FavSentenceDao(openDatabase: () async => db);
      await dao.loadAll(); // 修复前：按 0 行迁移并写 done → 收藏永久清空且无恢复入口

      expect(dao.usesSqlite, isFalse, reason: '损坏时中止迁移回退 SP 模式');
      expect(dao.favCount, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fav_sentence_sqlite_migrated_v1'), isNull, reason: '不写迁移完成标记');
      expect(prefs.getString('fav_sentence_list'), corrupted, reason: 'SP 原档保留供人工恢复');
    });

    test('持久化失败：日志保底成功则索引不回滚（P1-01 新契约）', () async {
      final dao = FavSentenceDao(openDatabase: () async => db);
      await dao.loadAll();
      await dao.addFavSentence(
        word: 'apple',
        wordId: 7,
        sentenceId: '40004',
        sentenceData: SentenceData(sid: '40004', e: 'Keep me.', c: '留下'),
      );
      expect(dao.isFavSentence(7, '40004'), isTrue);

      await db.close();
      db = await openDatabase(inMemoryDatabasePath); // tearDown 关闭的是新库

      final added = await dao.addFavSentence(
        word: 'apple',
        wordId: 7,
        sentenceId: '50005',
        sentenceData: SentenceData(sid: '50005', e: 'Fail.', c: ''),
      );
      expect(added, isTrue, reason: 'add 返回值语义保持（persist 失败不改变返回契约）');
      // P1-01 契约变更：写失败 → 降级日志（含完整载荷）保底 → 索引不回滚。
      expect(dao.isFavSentence(7, '50005'), isTrue, reason: '日志保底成功 → 保留索引态（回放补库）');

      expect(await dao.removeFavSentence(7, '40004'), isTrue);
      expect(dao.isFavSentence(7, '40004'), isFalse, reason: '取消收藏同样由日志保底');
    });
  });

  group('P1-01 降级日志：例句收藏意图不丢（2026-10-11 批次）', () {
    const journal = DegradedJournal(key: FavSentenceDao.degradedJournalKey, domain: '测试');

    Future<void> createTable() async {
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
    }

    test('add 写失败落日志（载荷无损），新实例加载时回放', () async {
      final dao = FavSentenceDao(openDatabase: () async => db);
      await dao.loadAll();

      await db.close();
      await dao.addFavSentence(
        word: 'apple',
        wordId: 7,
        sentenceId: '60006',
        sentenceData: SentenceData(sid: '60006', e: 'Replay me.', c: '回放我'),
      );
      expect(await journal.pendingCount(), 1, reason: '写失败必须留下可回放的意图记录');

      db = await openDatabase(inMemoryDatabasePath);
      await createTable();

      final dao2 = FavSentenceDao(openDatabase: () async => db);
      await dao2.loadAll();

      expect(dao2.isFavSentence(7, '60006'), isTrue, reason: '回放后进入事实来源');
      expect(await journal.pendingCount(), 0, reason: '回放成功后日志清空');

      final rows = await db.query('favorite_sentences', where: 'sentence_id = ?', whereArgs: ['60006']);
      expect(rows, hasLength(1));
      final payload = FavSentenceData.fromJson(jsonDecode(rows.first['data_json']! as String) as Map<String, dynamic>);
      expect(payload.sentenceData?.e, 'Replay me.', reason: '回放载荷无损（句子原文可还原）');
    });

    test('remove 写失败落日志，回放后不复活', () async {
      final dao = FavSentenceDao(openDatabase: () async => db);
      await dao.loadAll();
      await dao.addFavSentence(
        word: 'apple',
        wordId: 7,
        sentenceId: '40004',
        sentenceData: SentenceData(sid: '40004', e: 'Keep me.', c: '留下'),
      );

      await db.close();
      await dao.removeFavSentence(7, '40004');
      expect(await journal.pendingCount(), 1);

      // 新库里预置该行（模拟故障前的持久化态），回放 remove 必须删掉它
      db = await openDatabase(inMemoryDatabasePath);
      await createTable();
      await db.insert('favorite_sentences', {
        'word_id': 7,
        'sentence_id': '40004',
        'word': 'apple',
        'update_time': '20260101000000',
        'data_json': jsonEncode(
          FavSentenceData(word: 'apple', wordId: 7, sentenceId: '40004', updateTime: '20260101000000').toJson(),
        ),
      });

      final dao2 = FavSentenceDao(openDatabase: () async => db);
      await dao2.loadAll();

      expect(dao2.isFavSentence(7, '40004'), isFalse, reason: '回放 remove 生效，取消收藏不复活');
      expect(await journal.pendingCount(), 0);
    });
  });
}
