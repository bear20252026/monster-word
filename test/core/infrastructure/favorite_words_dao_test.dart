// MEM/U6：FavoriteWordsDao 测试。
// SQLite（注入内存库）为事实来源：迁移幂等、单行写、同步索引口径；
// FLUTTER_TEST 下未注入的默认实例回退旧 SP 行为。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/degraded_journal.dart';
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

    test('持久化失败：日志保底成功则索引不回滚（P1-01 新契约）', () async {
      final dao = FavoriteWordsDao(openDatabase: () async => db);
      await dao.ensureLoaded();
      await dao.add('apple');
      expect(dao.isFavorite('apple'), isTrue);

      // 关闭底层库模拟持久化故障（磁盘错误/连接丢失）
      await db.close();
      db = await openDatabase(inMemoryDatabasePath); // tearDown 关闭的是新库

      // P1-01 契约变更：写失败 → 降级日志保底 → 内存**不回滚**。
      // 旧契约（无条件回滚）会让用户这一次收藏直接消失；新契约下日志会在
      // 下次加载时回放，内存态与最终事实来源仍然一致。
      await dao.add('banana');
      expect(dao.isFavorite('banana'), isTrue, reason: '日志保底成功 → 保留内存态（回放补库）');

      await dao.remove('apple');
      expect(dao.isFavorite('apple'), isFalse, reason: '取消收藏同样由日志保底');
    });
  });

  group('P1-01 降级日志：收藏意图不丢（2026-10-11 批次）', () {
    const journal = DegradedJournal(key: FavoriteWordsDao.degradedJournalKey, domain: '测试');

    test('add 写失败落日志，新实例加载时回放补库并清空日志', () async {
      final dao = FavoriteWordsDao(openDatabase: () async => db);
      await dao.ensureLoaded();

      await db.close(); // 制造写失败
      await dao.add('banana');
      expect(dao.isFavorite('banana'), isTrue);
      expect(await journal.pendingCount(), 1, reason: '写失败必须留下可回放的意图记录');

      // 恢复：新库 + 新 DAO，ensureLoaded 时回放
      db = await openDatabase(inMemoryDatabasePath);
      await db.execute(
        'CREATE TABLE IF NOT EXISTS favorite_words (word TEXT PRIMARY KEY, created_at INTEGER NOT NULL)',
      );
      final dao2 = FavoriteWordsDao(openDatabase: () async => db);
      await dao2.ensureLoaded();

      expect(dao2.isFavorite('banana'), isTrue, reason: '回放后进入事实来源');
      expect(await journal.pendingCount(), 0, reason: '回放成功后日志清空');
      expect(await db.query('favorite_words', where: 'word = ?', whereArgs: ['banana']), hasLength(1));
    });

    test('remove 写失败落日志，回放后不复活', () async {
      final dao = FavoriteWordsDao(openDatabase: () async => db);
      await dao.ensureLoaded();
      await dao.add('apple');

      await db.close();
      await dao.remove('apple');
      expect(dao.isFavorite('apple'), isFalse);
      expect(await journal.pendingCount(), 1);

      // 新库里预置 apple（模拟故障前的持久化态），回放 remove 必须删掉它
      db = await openDatabase(inMemoryDatabasePath);
      await db.execute(
        'CREATE TABLE IF NOT EXISTS favorite_words (word TEXT PRIMARY KEY, created_at INTEGER NOT NULL)',
      );
      await db.insert('favorite_words', {'word': 'apple', 'created_at': 1});

      final dao2 = FavoriteWordsDao(openDatabase: () async => db);
      await dao2.ensureLoaded();

      expect(dao2.isFavorite('apple'), isFalse, reason: '回放 remove 生效，取消收藏不复活');
      expect(await journal.pendingCount(), 0);
    });

    test('回放幂等：重复执行同一份日志不产生重复行', () async {
      await journal.append({'op': 'add', 'word': 'grape', 'at': 1});
      await db.execute(
        'CREATE TABLE IF NOT EXISTS favorite_words (word TEXT PRIMARY KEY, created_at INTEGER NOT NULL)',
      );

      final dao = FavoriteWordsDao(openDatabase: () async => db);
      await dao.ensureLoaded();
      expect(dao.isFavorite('grape'), isTrue);

      // 再放一份同样的日志，回放后仍只有一行（主键 OR IGNORE）
      await journal.append({'op': 'add', 'word': 'grape', 'at': 2});
      final dao2 = FavoriteWordsDao(openDatabase: () async => db);
      await dao2.ensureLoaded();
      expect(await db.query('favorite_words', where: 'word = ?', whereArgs: ['grape']), hasLength(1));
    });
  });
}
