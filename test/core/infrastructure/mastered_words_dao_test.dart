// P2-10（架构审计 2026-11-12）：MasteredWordsDao 测试。
// SQLite（注入内存库）为事实来源：迁移幂等、单行写、同步索引口径；
// FLUTTER_TEST 下未注入的默认实例回退旧 SP 行为。口径对齐 favorite_words_dao_test。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/mastered_words_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE IF NOT EXISTS mastered_words (word TEXT PRIMARY KEY, created_at INTEGER NOT NULL)');
  });

  tearDown(() async {
    await db.close();
  });

  group('MasteredWordsDao（P2-10 SQLite 模式）', () {
    test('SP → SQLite 首启迁移：幂等、去重、SP 快照保留、标记落盘', () async {
      SharedPreferences.setMockInitialValues({
        'mastered_words_v1': ['banana', 'apple', 'banana'],
      });
      final dao = MasteredWordsDao(openDatabase: () async => db);
      await dao.ensureLoaded();

      expect(dao.usesSqlite, isTrue);
      expect(dao.masteredCount, 2, reason: '重复项按主键去重');
      expect(dao.isMastered('banana'), isTrue);
      expect(dao.isMastered('apple'), isTrue);

      final rows = await db.query('mastered_words', orderBy: 'created_at ASC');
      expect(rows.map((r) => r['word']), ['banana', 'apple'], reason: 'created_at 保持 SP 中的先后顺序');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('mastered_words_sqlite_migrated_v1'), 'done');
      expect(prefs.getStringList('mastered_words_v1'), isNotNull, reason: 'SP 快照保留为回滚依据');

      // 二次启动：marker 已写，不重复迁移（幂等）
      final dao2 = MasteredWordsDao(openDatabase: () async => db);
      await dao2.ensureLoaded();
      expect(dao2.masteredCount, 2);
    });

    test('迁移崩溃自愈：DB 已含全集而 marker 缺失时直接补标记不重插', () async {
      SharedPreferences.setMockInitialValues({
        'mastered_words_v1': ['apple', 'banana'],
      });
      // 模拟「事务已提交、marker 未写」的崩溃现场：DB 已有全部行
      await db.insert('mastered_words', {'word': 'apple', 'created_at': 1});
      await db.insert('mastered_words', {'word': 'banana', 'created_at': 2});

      final dao = MasteredWordsDao(openDatabase: () async => db);
      await dao.ensureLoaded();

      expect(dao.masteredCount, 2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('mastered_words_sqlite_migrated_v1'), 'done');
      expect(await db.query('mastered_words'), hasLength(2), reason: '不重复插入');
    });

    test('toggle 单行持久化与同步索引一致', () async {
      final dao = MasteredWordsDao(openDatabase: () async => db);
      await dao.ensureLoaded();

      expect(await dao.toggle('apple'), isTrue);
      expect(dao.isMastered('apple'), isTrue);
      expect(await db.query('mastered_words', where: 'word = ?', whereArgs: ['apple']), hasLength(1));

      expect(await dao.toggle('apple'), isFalse);
      expect(dao.isMastered('apple'), isFalse);
      expect(await db.query('mastered_words', where: 'word = ?', whereArgs: ['apple']), isEmpty);

      await dao.toggle('banana');
      expect(dao.getWords(), {'banana'});
      expect(dao.masteredCount, 1);
    });

    test('空 SP 首启：标记落盘、空索引、后续 toggle 正常', () async {
      final dao = MasteredWordsDao(openDatabase: () async => db);
      await dao.ensureLoaded();

      expect(dao.usesSqlite, isTrue);
      expect(dao.masteredCount, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('mastered_words_sqlite_migrated_v1'), 'done');

      await dao.toggle('cherry');
      expect(dao.isMastered('cherry'), isTrue);
      expect(await db.query('mastered_words'), hasLength(1));
    });
  });

  group('MasteredWordsDao（SP 回退）', () {
    test('未注入数据库时回退旧 SP 行为', () async {
      SharedPreferences.setMockInitialValues({
        'mastered_words_v1': ['apple'],
      });
      final dao = MasteredWordsDao();
      await dao.ensureLoaded();

      expect(dao.usesSqlite, isFalse);
      expect(dao.isMastered('apple'), isTrue);

      await dao.toggle('banana');
      expect(dao.isMastered('banana'), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('mastered_words_v1')?.toSet(), {'apple', 'banana'});
    });
  });
}
