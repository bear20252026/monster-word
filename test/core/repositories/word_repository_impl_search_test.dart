// 集成测试（2026-09-01）：查词页中文释义搜索。
//
// 背景：搜索框提示"输入要查询的英文或中文"，但 WordRepositoryImpl.searchWords
// 此前只匹配 word 列 → 中文查询恒为空。现扩展到 interpret（中文释义），
// 并保证英文命中排序优先于中文命中。
// 真库验证：sqflite_common_ffi 内存库 + WordBookDatabase.debugInjectDbForTest。
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/infrastructure/wordbook_database.dart';
import 'package:word_app/core/repositories/word_repository_impl.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late WordRepositoryImpl repo;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE words (id INTEGER PRIMARY KEY, word TEXT, interpret TEXT)');
    // 场景覆盖：英文命中 / 中文释义命中 / 两者兼有。
    await db.insert('words', {'id': 1, 'word': 'apple', 'interpret': 'n. 苹果'});
    await db.insert('words', {'id': 2, 'word': 'banana', 'interpret': 'n. 香蕉；芭蕉'});
    await db.insert('words', {'id': 3, 'word': 'pineapple', 'interpret': 'n. 菠萝'});
    await db.insert('words', {'id': 4, 'word': 'fruit', 'interpret': 'n. 水果；果实'});
    final database = WordBookDatabase.instance;
    database.debugInjectDbForTest(db);
    repo = WordRepositoryImpl(database);
  });

  tearDown(() async {
    await db.close();
  });

  test('中文关键词命中释义（"苹果" → apple）', () async {
    final results = await repo.searchWords('苹果');
    expect(results.map((w) => w.word), contains('apple'));
  });

  test('中文关键词命中释义（"水果" → fruit）', () async {
    final results = await repo.searchWords('水果');
    expect(results.map((w) => w.word), contains('fruit'));
  });

  test('英文搜索仍正常且不受中文扩展影响', () async {
    final results = await repo.searchWords('banana');
    expect(results, isNotEmpty);
    expect(results.first.word, 'banana');
  });

  test('英文命中排序优先于中文命中', () async {
    // "pin"：pineapple 单词前缀命中；若某词仅释义含 pin 则排后。
    final results = await repo.searchWords('apple');
    // apple（词=apple 精确）应排在 pineapple（词含 apple 的前缀外模糊命中）之前
    expect(results.first.word, 'apple');
    expect(results.map((w) => w.word), contains('pineapple'));
  });

  test('无命中的中文查询返回空列表', () async {
    final results = await repo.searchWords('不存在的释义');
    expect(results, isEmpty);
  });

  group('三层化回归（2026-09-28，审计 I12）：大小写平局与元字符', () {
    late Database db2;
    late WordRepositoryImpl repo2;

    setUp(() async {
      // singleInstance=false：默认 ':memory:' 路径会复用外层 setUp 的同一连接。
      db2 = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      await db2.execute('CREATE TABLE words (id INTEGER PRIMARY KEY, word TEXT UNIQUE, interpret TEXT)');
      // rowid 序 = 插入序，用于锁定 NOCASE 平局时的显式 tie-break 行为。
      await db2.insert('words', {'id': 1, 'word': 'apple', 'interpret': 'n. 苹果'});
      await db2.insert('words', {'id': 2, 'word': 'applesauce', 'interpret': 'n. 苹果酱'});
      await db2.insert('words', {'id': 3, 'word': 'Apple', 'interpret': 'n. 苹果公司'});
      await db2.insert('words', {'id': 4, 'word': 'APPLE', 'interpret': 'abbr. 苹果'});
      await db2.insert('words', {'id': 5, 'word': 'apply', 'interpret': 'v. 申请'});
      await db2.insert('words', {'id': 6, 'word': 'pineapple', 'interpret': 'n. 菠萝'});
      await db2.execute('CREATE UNIQUE INDEX idx_words_word ON words(word)');
      final database = WordBookDatabase.instance;
      database.debugInjectDbForTest(db2);
      repo2 = WordRepositoryImpl(database);
    });

    tearDown(() async {
      await db2.close();
    });

    test('大小写不敏感前缀全命中且 NOCASE 序、平局按 rowid', () async {
      final results = await repo2.searchWords('apple');
      // 第 2 层命中 apple/Apple/APPLE/applesauce：NOCASE 序 apple=Apple=APPLE，
      // 平局按 rowid（插入序 apple→Apple→APPLE），applesauce 排其后。
      expect(results.map((w) => w.word).toList(), ['apple', 'Apple', 'APPLE', 'applesauce', 'pineapple']);
    });

    test('全大写查询走第 2/3 层仍得到相同命中集', () async {
      final results = await repo2.searchWords('APPLE');
      expect(results.map((w) => w.word), containsAll(['apple', 'Apple', 'APPLE', 'applesauce']));
    });

    test('GLOB 元字符按字面处理不放大匹配', () async {
      expect(await repo2.searchWords('app*'), isEmpty);
      expect(await repo2.searchWords('a%'), isEmpty);
      expect(await repo2.searchWords('_pple'), isEmpty);
    });

    test('单字符查询覆盖大小写双变体', () async {
      final results = await repo2.searchWords('A');
      // 第 2 层：apple/Apple/APPLE（NOCASE 平局按 rowid）→ applesauce → apply；
      // 第 3 层中缀兜底补 pineapple（CASE 2 排在前缀命中之后）。
      expect(results.map((w) => w.word).toList(), ['apple', 'Apple', 'APPLE', 'applesauce', 'apply', 'pineapple']);
    });
  });
}
