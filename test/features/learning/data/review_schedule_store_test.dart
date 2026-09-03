import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/data/review_schedule_store.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late ReviewScheduleStore store;

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath);
    store = await ReviewScheduleStore.forTest(db);
  });

  tearDown(() async {
    await db.close();
  });

  FsrsCard card(String word, {double stability = 3, bool isNew = false}) => FsrsCard(
    word: word,
    stability: stability,
    difficulty: 5,
    lastReview: DateTime.parse('2026-09-01T08:00:00.000'),
    dueDate: DateTime.parse('2026-09-04T08:00:00.000'),
    repetitions: 2,
    reviewCount: 5,
    isNew: isNew,
    shortTermStability: stability,
  );

  test('recordRating 写入卡片/统计/日期三表，load 读回字段一致', () async {
    await store.recordRating(card: card('apple'), dateKey: '2026-09-04', isLearn: false);

    final cards = await store.loadCards();
    expect(cards, hasLength(1));
    expect(cards.single.word, 'apple');
    expect(cards.single.stability, 3);
    expect(cards.single.difficulty, 5);
    expect(cards.single.lastReview, DateTime.parse('2026-09-01T08:00:00.000'));
    expect(cards.single.dueDate, DateTime.parse('2026-09-04T08:00:00.000'));
    expect(cards.single.repetitions, 2);
    expect(cards.single.reviewCount, 5);
    expect(cards.single.isNew, isFalse);
    expect(cards.single.shortTermStability, 3);

    final stats = await store.loadDailyStats();
    expect(stats['2026-09-04'], {'learn': 0, 'review': 1});
    expect(await store.loadActiveDates(), {'2026-09-04'});
    expect(await store.cardCount(), 1);
  });

  test('同日多次评分统计自增且卡片 UPSERT 覆盖（O(1) 写路径核心语义）', () async {
    await store.recordRating(card: card('apple', stability: 3), dateKey: '2026-09-04', isLearn: true);
    await store.recordRating(card: card('apple', stability: 4), dateKey: '2026-09-04', isLearn: false);
    await store.recordRating(card: card('bee'), dateKey: '2026-09-04', isLearn: true);

    expect(await store.cardCount(), 2);
    final apple = (await store.loadCards()).firstWhere((c) => c.word == 'apple');
    expect(apple.stability, 4);
    expect(await store.loadDailyStats(), {
      '2026-09-04': {'learn': 2, 'review': 1},
    });
    expect(await store.loadActiveDates(), {'2026-09-04'});
  });

  test('deleteCard 删除单行且不影响其他卡片', () async {
    await store.recordRating(card: card('apple'), dateKey: '2026-09-04', isLearn: true);
    await store.recordRating(card: card('bee'), dateKey: '2026-09-04', isLearn: true);

    await store.deleteCard('apple');

    final words = (await store.loadCards()).map((c) => c.word).toList();
    expect(words, ['bee']);
  });

  test('mergeDailyStatsInTransaction 累加不覆盖（防重复迁移翻倍依赖的语义）', () async {
    await store.recordRating(card: card('apple'), dateKey: '2026-09-04', isLearn: true);
    await store.mergeDailyStatsInTransaction({
      '2026-09-04': {'learn': 3, 'review': 2},
      '2026-09-03': {'learn': 1, 'review': 0},
    });

    expect(await store.loadDailyStats(), {
      '2026-09-04': {'learn': 4, 'review': 2},
      '2026-09-03': {'learn': 1, 'review': 0},
    });
  });
}
