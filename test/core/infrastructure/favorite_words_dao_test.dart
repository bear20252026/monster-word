// MEM/U6：FavoriteWordsDao 测试。
// SQLite（注入内存库）为事实来源：迁移幂等、单行写、同步索引口径；
// FLUTTER_TEST 下未注入的默认实例回退旧 SP 行为。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/favorite_words_dao.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE IF NOT EXISTS favorite_words (word TEXT PRIMARY KEY, created_at INTEGER NOT NULL)');
  });

  tearDown(() async {
    await db.close();
  });

  group('FavoriteWordsDao（MEM/U6 SQLite 模式）', () {
    test('SP → SQLite 首启迁移：幂等、去重、SP 快照保留、标记落盘', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_words_v1': ['banana', 'apple', 'banana'],
      });
      final dao = FavoriteWordsDao(openDatabase: () async => db);
      await dao.ensureLoaded();

      expect(dao.usesSqlite, isTrue);
      expect(dao.favoriteCount, 2, reason: '重复项按主键去重');
      expect(dao.isFavorite('banana'), isTrue);
      expect(dao.isFavorite('apple'), isTrue);

      final rows = await db.query('favorite_words', orderBy: 'created_at ASC');
      expect(rows.map((r) => r['word']), ['banana', 'apple'], reason: 'created_at 保持 SP 中的先后顺序');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('favorite_words_sqlite_migrated_v1'), 'done');
      expect(prefs.getStringList('favorite_words_v1'), isNotNull, reason: 'SP 快照保留为回滚依据');

      // 二次启动：marker 已写，不重复迁移（幂等）
      final dao2 = FavoriteWordsDao(openDatabase: () async => db);
      await dao2.ensureLoaded();
      expect(dao2.favoriteCount, 2);
    });

    test('toggle/add/remove 单行持久化与同步索引一致', () async {
      final dao = FavoriteWordsDao(openDatabase: () async => db);
      await dao.ensureLoaded();

      expect(await dao.toggle('apple'), isTrue);
      expect(dao.isFavorite('apple'), isTrue);
      expect((await db.query('favorite_words', where: 'word = ?', whereArgs: ['apple'])), hasLength(1));

      await dao.remove('apple');
      expect(dao.isFavorite('apple'), isFalse);
      expect(await db.query('favorite_words', where: 'word = ?', whereArgs: ['apple']), isEmpty);

      await dao.add('banana');
      expect(dao.isFavorite('banana'), isTrue);
      expect(dao.getWords(), {'banana'});
      expect((await dao.toggle('banana')), isFalse);
      expect(dao.favoriteCount, 0);
    });
  });

  group('FavoriteWordsDao（FLUTTER_TEST 未注入 → SP 回退）', () {
    test('保持迁移前的 SP 行为', () async {
      SharedPreferences.setMockInitialValues({
        'favorite_words_v1': ['legacy'],
      });
      final dao = FavoriteWordsDao();
      await dao.ensureLoaded();

      expect(dao.usesSqlite, isFalse);
      expect(dao.isFavorite('legacy'), isTrue);

      await dao.add('fresh');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('favorite_words_v1'), containsAll(['legacy', 'fresh']));
      expect(await db.query('favorite_words'), isEmpty, reason: '回退模式不触碰 SQLite');
    });
  });

  group('REG-AUDIT-001 迁移自愈与持久化失败回滚（2026-09-27 审计批次）', () {
    test('崩溃自愈：事务已提交、marker 未写（DB 已含 SP 全集）→ 不抛错并补写 marker', () async {
      // 模拟"迁移事务提交后、marker 写入前崩溃"的现场：
      // DB 已有全部 legacy 行，但 marker 缺失、SP 快照仍在。
      SharedPreferences.setMockInitialValues({
        'favorite_words_v1': ['banana', 'apple'],
      });
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('favorite_words', {'word': 'banana', 'created_at': now});
      await db.insert('favorite_words', {'word': 'apple', 'created_at': now + 1});

      final dao = FavoriteWordsDao(openDatabase: () async => db);
      await dao.ensureLoaded(); // 修复前：行数校验 inserted(0)≠2 抛错 → 永久降级 SP 循环失败

      expect(dao.usesSqlite, isTrue, reason: '不应因崩溃现场降级 SP');
      expect(dao.favoriteCount, 2);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('favorite_words_sqlite_migrated_v1'), 'done', reason: '自愈后补写 marker');
      expect(await db.query('favorite_words'), hasLength(2), reason: '不产生重复行');
    });

    test('持久化失败回滚：add 失败索引不含、remove 失败索引仍含', () async {
      final dao = FavoriteWordsDao(openDatabase: () async => db);
      await dao.ensureLoaded();
      await dao.add('apple');
      expect(dao.isFavorite('apple'), isTrue);

      // 关闭底层库模拟持久化故障（磁盘错误/连接丢失）
      await db.close();
      db = await openDatabase(inMemoryDatabasePath); // tearDown 关闭的是新库

      await dao.add('banana');
      expect(dao.isFavorite('banana'), isFalse, reason: 'add 持久化失败必须回滚索引（否则重启后收藏消失）');

      await dao.remove('apple');
      expect(dao.isFavorite('apple'), isTrue, reason: 'remove 持久化失败必须回滚索引（否则取消收藏复活）');
    });
  });
}
