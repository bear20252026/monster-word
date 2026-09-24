// MEM/F3：ReviewScheduleStore 按需读取层测试。
// 覆盖 loadCounts（SQL 聚合口径）、loadDueCards（到期子集）、
// cardForWord（单行索引查）、cardsForWords/dueWordTextsFor（异步读取面）。
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/data/review_schedule_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late ReviewScheduleStore store;

  setUp(() async {
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(inMemoryDatabasePath);
    store = await ReviewScheduleStore.forTest(db);
  });

  tearDown(() async {
    await db.close();
  });

  FsrsCard card(String word, {required bool isNew, required DateTime dueDate, double stability = 5}) {
    return FsrsCard(
      word: word,
      stability: stability,
      difficulty: 5,
      lastReview: DateTime.now().subtract(const Duration(days: 2)),
      dueDate: dueDate,
      repetitions: 3,
      reviewCount: 5,
      isNew: isNew,
      shortTermStability: 1,
    );
  }

  group('MEM/F3 loadCounts（SQL 聚合，口径与 memoryStats 一致）', () {
    test('new/due/learning/mature/total 分桶正确（learning/mature 排除到期卡）', () async {
      final now = DateTime.now();
      final cards = [
        card('new-word', isNew: true, dueDate: now.add(const Duration(days: 1))),
        card('due-word', isNew: false, dueDate: now.subtract(const Duration(days: 1))),
        card('learning-word', isNew: false, dueDate: now.add(const Duration(days: 3)), stability: 3),
        card('mature-word', isNew: false, dueDate: now.add(const Duration(days: 30)), stability: 12),
      ];
      await store.insertCardsInTransaction(cards);

      final counts = await store.loadCounts(now);

      expect(counts.total, 4);
      expect(counts.newCount, 1);
      expect(counts.due, 1);
      expect(counts.learning, 1);
      expect(counts.mature, 1);
    });

    test('空表全零', () async {
      final counts = await store.loadCounts(DateTime.now());
      expect(counts.total, 0);
      expect(counts.newCount, 0);
      expect(counts.due, 0);
      expect(counts.learning, 0);
      expect(counts.mature, 0);
    });
  });

  group('MEM/F3 loadDueCards / cardForWord / loadCardsBatch', () {
    test('loadDueCards 只返回已过期的非新卡', () async {
      final now = DateTime.now();
      await store.insertCardsInTransaction([
        card('due-a', isNew: false, dueDate: now.subtract(const Duration(days: 1))),
        card('due-b', isNew: false, dueDate: now.subtract(const Duration(hours: 2))),
        card('future', isNew: false, dueDate: now.add(const Duration(days: 5))),
        card('brand-new', isNew: true, dueDate: now.subtract(const Duration(days: 1))),
      ]);

      final due = await store.loadDueCards(now);
      expect(due.map((c) => c.word).toSet(), {'due-a', 'due-b'});
    });

    test('cardForWord 命中返回卡片，未命中返回 null', () async {
      final now = DateTime.now();
      await store.insertCardsInTransaction([card('known', isNew: false, dueDate: now)]);

      expect((await store.cardForWord('known'))?.word, 'known');
      expect(await store.cardForWord('unknown'), isNull);
    });

    test('cardsForWords 分块 IN 查询：存在的词返回卡，缺失的词不在 Map', () async {
      final now = DateTime.now();
      final cards = [for (var i = 0; i < 7; i++) card('w$i', isNew: false, dueDate: now)];
      await store.insertCardsInTransaction(cards);

      final fetched = await store.cardsForWords(['w0', 'w3', 'w6', 'missing']);
      expect(fetched.keys, containsAll(['w0', 'w3', 'w6']));
      expect(fetched, isNot(contains('missing')));
      expect(fetched['w3']?.word, 'w3');

      // dueDate == now 不算到期（isBefore 语义），用次日口径查询使种子卡全部到期
      final due = await store.dueWordTextsFor(['w0', 'w6', 'missing'], now.add(const Duration(days: 1)));
      expect(due, {'w0', 'w6'});
    });
  });
}
