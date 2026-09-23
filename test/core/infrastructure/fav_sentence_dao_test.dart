// MEM/U3：FavSentenceDao 测试。
// SQLite（注入内存库）为事实来源：迁移无损往返、同步索引判重、单行写；
// FLUTTER_TEST 下未注入的默认实例回退旧 SP 行为。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
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
}
