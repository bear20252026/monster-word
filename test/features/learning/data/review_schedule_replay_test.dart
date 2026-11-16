import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/data/review_schedule_store.dart';

/// 2026-10-17 审计 P1-02 / P1-03 的回归守卫：**降级日志回放**的语义。
///
/// 两条缺陷都在同一个函数里，而且都不会让任何既有测试变红：
/// - **P1-02**：回放时用「恢复当天」当答题时间 ⇒ 几天前的评分被当成刚刚，
///   FSRS 的 elapsedDays 与间隔全部算错。
/// - **P1-03**：回放写的是库，但内存快照是回放**之前**读的、之后没有重读
///   ⇒ 本次启动全程统计/到期集/连续天数都缺那批数据，要等下次启动才自愈。
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath);
  });

  tearDown(() async {
    await db.close();
  });

  String dateKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String journalEntry({
    required String word,
    required FsrsRating rating,
    required DateTime answeredAt,
    required String ratingId,
    bool isLearn = true,
  }) => jsonEncode({
    'ratingId': ratingId,
    'word': word,
    'rating': rating.value,
    'date': dateKey(answeredAt),
    'isLearn': isLearn,
    'savedAt': answeredAt.toIso8601String(),
  });

  test('P1-02：回放按**原答题时间**重算，不用恢复当天', () async {
    final answeredAt = DateTime.now().subtract(const Duration(days: 5));
    SharedPreferences.setMockInitialValues({
      ReviewScheduleRepository.degradedJournalKey: [
        journalEntry(word: 'apple', rating: FsrsRating.good, answeredAt: answeredAt, ratingId: 'r-old-1'),
      ],
    });

    final store = await ReviewScheduleStore.forTest(db);
    final repo = ReviewScheduleRepository(store: store);
    await repo.initialize();

    final rows = await db.query('fsrs_cards', where: 'word = ?', whereArgs: ['apple']);
    expect(rows, hasLength(1), reason: '回放必须把卡片落库');

    final lastReview = DateTime.parse(rows.single['last_review']! as String);
    expect(
      lastReview.difference(answeredAt).inSeconds.abs(),
      lessThanOrEqualTo(1),
      reason: 'last_review 必须是原答题时刻；若等于「现在」，说明 reviewedAt 没传进引擎',
    );

    // 间隔也必须按「5 天前学过」算：到期日不可能晚于「现在 + 最大间隔」这种
    // 明显是「刚学完」的形态。这里只做一个方向性断言：到期日不应比原答题日
    // 更早，且必须落在原答题日之后 —— 关键是它不能等于「今天 + 首个间隔」。
    final dueDate = DateTime.parse(rows.single['due_date']! as String);
    expect(dueDate.isAfter(answeredAt), isTrue, reason: '到期日必须晚于原答题时刻');
  });

  test('P1-03：回放后内存快照必须重读（当天统计立刻可见）', () async {
    final answeredAt = DateTime.now();
    SharedPreferences.setMockInitialValues({
      ReviewScheduleRepository.degradedJournalKey: [
        journalEntry(word: 'bee', rating: FsrsRating.good, answeredAt: answeredAt, ratingId: 'r-today-1'),
      ],
    });

    final store = await ReviewScheduleStore.forTest(db);
    final repo = ReviewScheduleRepository(store: store);
    await repo.initialize();

    // 回放前库里是空的 ⇒ 若快照没重读，这两个值都会是 0。
    expect(repo.usesSqlite, isTrue);
    expect(repo.todayLearnCount, 1, reason: '回放写入的学习次数必须在本次启动就可见，不能等下次启动');
    expect(repo.activeDateCount, 1, reason: '回放写入的活跃日期同理');
  });

  test('审计 A1：迁移预登记 journal 评分 → 回放不二次应用卡片', () async {
    final answeredAt = DateTime.now().subtract(const Duration(days: 2));
    final card = FsrsCard(
      word: 'cat',
      stability: 5,
      difficulty: 5,
      isNew: false,
      lastReview: answeredAt,
      dueDate: answeredAt.add(const Duration(days: 5)),
    );
    SharedPreferences.setMockInitialValues({
      ReviewScheduleRepository.cardsPrefKey: jsonEncode({'cat': card.toJson()}),
      ReviewScheduleRepository.dailyStatsPrefKey: jsonEncode({
        dateKey(answeredAt): {'learn': 1, 'review': 0},
      }),
      ReviewScheduleRepository.degradedJournalKey: [
        journalEntry(word: 'cat', rating: FsrsRating.good, answeredAt: answeredAt, ratingId: 'r-dup-1'),
      ],
    });

    final store = await ReviewScheduleStore.forTest(db);
    final repo = ReviewScheduleRepository(store: store);
    await repo.initialize();

    final rows = await db.query('fsrs_cards', where: 'word = ?', whereArgs: ['cat']);
    expect(rows, hasLength(1));
    // blob 卡已含该评分；若回放二次应用，last_review 会被推到现在、review_count 虚增。
    final lastReview = DateTime.parse(rows.single['last_review']! as String);
    expect(lastReview.difference(answeredAt).inSeconds.abs(), lessThanOrEqualTo(1), reason: '回放不得二次应用已含评分');
    expect(rows.single['review_count'], card.reviewCount, reason: 'review_count 不得虚增');
  });

  test('审计 A2：SP marker 丢失但 DB marker 在 → 重迁移不翻倍统计', () async {
    final answeredAt = DateTime.now();
    final card = FsrsCard(
      word: 'dog',
      stability: 3,
      difficulty: 5,
      isNew: false,
      lastReview: answeredAt,
      dueDate: answeredAt,
    );
    final sp = {
      ReviewScheduleRepository.cardsPrefKey: jsonEncode({'dog': card.toJson()}),
      ReviewScheduleRepository.dailyStatsPrefKey: jsonEncode({
        dateKey(answeredAt): {'learn': 1, 'review': 0},
      }),
    };
    SharedPreferences.setMockInitialValues(sp);
    final store = await ReviewScheduleStore.forTest(db);
    await ReviewScheduleRepository(store: store).initialize();
    final first = (await db.query('fsrs_daily_stats')).single['learn'];

    // 模拟「事务提交后 SP marker 写失败」：清掉 SP marker，DB marker 仍在。
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ReviewScheduleRepository.migratedMarkerKey);
    await ReviewScheduleRepository(store: store).initialize();
    final second = (await db.query('fsrs_daily_stats')).single['learn'];
    expect(second, first, reason: 'DB 标记在则不重迁移，统计不得累加翻倍');
  });

  test('审计 R1：journal 先行、blob 未含该评分 → 不得预登记，回放必须补上', () async {
    // 场景：降级期评分写了 journal，但 blob 快照写失败（pendingRetry）——
    // blob 卡的 lastReview 早于该评分 savedAt。旧实现无条件预登记 → 回放跳过
    // → 评分永久丢失；修复后该评分不预登记，回放正常应用。
    final older = DateTime.now().subtract(const Duration(days: 3));
    final answeredAt = DateTime.now().subtract(const Duration(days: 1));
    final staleCard = FsrsCard(
      word: 'fox',
      stability: 4,
      difficulty: 5,
      isNew: false,
      lastReview: older, // blob 停在 3 天前：1 天前的评分未落快照
      dueDate: older.add(const Duration(days: 4)),
    );
    SharedPreferences.setMockInitialValues({
      ReviewScheduleRepository.cardsPrefKey: jsonEncode({'fox': staleCard.toJson()}),
      ReviewScheduleRepository.degradedJournalKey: [
        journalEntry(word: 'fox', rating: FsrsRating.good, answeredAt: answeredAt, ratingId: 'r-lost-1'),
      ],
    });

    final store = await ReviewScheduleStore.forTest(db);
    final repo = ReviewScheduleRepository(store: store);
    await repo.initialize();

    // 回放必须把评分补上：last_review 前进到 answeredAt 附近（回放应用后写
    // 幂等日志属正常行为，故以卡片终态而非日志空否判定）。
    final rows = await db.query('fsrs_cards', where: 'word = ?', whereArgs: ['fox']);
    final lastReview = DateTime.parse(rows.single['last_review']! as String);
    expect(lastReview.isAfter(older.add(const Duration(days: 1))), isTrue, reason: '回放必须补上未落快照的评分');
    final logged = await db.query('fsrs_rating_log', where: 'rating_id = ?', whereArgs: ['r-lost-1']);
    expect(logged, hasLength(1), reason: '回放应用后写幂等日志，防下次重复');
  });
}
