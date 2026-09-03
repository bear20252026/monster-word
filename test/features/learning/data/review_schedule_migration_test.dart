import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/data/review_schedule_store.dart';

/// 批次 E（v2.7.56）：FSRS 学习记录 SP blob → SQLite 首启迁移与双读降级。
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

  Map<String, dynamic> legacyCardJson(String word, {double stability = 2.5}) => FsrsCard(
    word: word,
    stability: stability,
    difficulty: 4.5,
    lastReview: DateTime.parse('2026-08-30T09:00:00.000'),
    dueDate: DateTime.parse('2026-09-01T09:00:00.000'),
    repetitions: 1,
    reviewCount: 3,
    isNew: false,
    shortTermStability: stability,
  ).toJson();

  String legacyCardsBlob({bool includeCorrupt = false}) {
    final map = <String, dynamic>{'apple': legacyCardJson('apple'), 'bee': legacyCardJson('bee', stability: 6.5)};
    if (includeCorrupt) {
      map['corrupt-entry'] = 'not-a-map';
    }
    return jsonEncode(map);
  }

  Future<ReviewScheduleStore> newStore() async => ReviewScheduleStore.forTest(db);

  test('首启迁移：SP 数据事务导入，损坏行跳过并写标记，仓储走 SQLite 模式', () async {
    SharedPreferences.setMockInitialValues({
      ReviewScheduleRepository.cardsPrefKey: legacyCardsBlob(includeCorrupt: true),
      ReviewScheduleRepository.dailyStatsPrefKey: jsonEncode({
        '2026-09-03': {'learn': 5, 'review': 2},
      }),
      ReviewScheduleRepository.activeDatesPrefKey: ['2026-09-02', '2026-09-03'],
    });

    final store = await newStore();
    final repo = ReviewScheduleRepository(store: store);
    await repo.initialize();

    expect(repo.usesSqlite, isTrue);
    expect(repo.cardFor('apple'), isNotNull);
    expect(repo.cardFor('bee'), isNotNull);
    expect(repo.cardFor('corrupt-entry'), isNull);
    expect(repo.cardFor('apple')!.stability, 2.5);
    expect(repo.cardFor('bee')!.stability, 6.5);
    expect(repo.activeDateCount, 2);

    // 迁移标记已写；SQLite 行数 == 解析成功行数（损坏行未入库）。
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ReviewScheduleRepository.migratedMarkerKey), 'done');
    expect(await store.cardCount(), 2);
    expect(await store.loadDailyStats(), {
      '2026-09-03': {'learn': 5, 'review': 2},
    });
  });

  test('已迁移后不再重跑迁移（表非空 / 标记 done 双重守卫，统计不翻倍）', () async {
    SharedPreferences.setMockInitialValues({
      ReviewScheduleRepository.cardsPrefKey: legacyCardsBlob(),
      ReviewScheduleRepository.dailyStatsPrefKey: jsonEncode({
        '2026-09-03': {'learn': 5, 'review': 2},
      }),
      ReviewScheduleRepository.activeDatesPrefKey: ['2026-09-03'],
    });

    final store = await newStore();
    final first = ReviewScheduleRepository(store: store);
    await first.initialize();
    expect(await store.loadDailyStats(), {
      '2026-09-03': {'learn': 5, 'review': 2},
    });

    // 篡改 SP 数据模拟"旧数据又出现"：若重跑迁移，统计会被再次累加翻倍。
    SharedPreferences.setMockInitialValues({
      ReviewScheduleRepository.cardsPrefKey: legacyCardsBlob(),
      ReviewScheduleRepository.dailyStatsPrefKey: jsonEncode({
        '2026-09-03': {'learn': 100, 'review': 100},
      }),
      ReviewScheduleRepository.activeDatesPrefKey: ['2026-09-03'],
      ReviewScheduleRepository.migratedMarkerKey: 'done',
    });

    final second = ReviewScheduleRepository(store: store);
    await second.initialize();
    expect(second.usesSqlite, isTrue);
    expect(await store.cardCount(), 2);
    expect(await store.loadDailyStats(), {
      '2026-09-03': {'learn': 5, 'review': 2},
    });
  });

  test('SP 无历史数据：直接写迁移标记，SQLite 空库正常工作', () async {
    SharedPreferences.setMockInitialValues({});

    final store = await newStore();
    final repo = ReviewScheduleRepository(store: store);
    await repo.initialize();

    expect(repo.usesSqlite, isTrue);
    expect(repo.cardFor('anything'), isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ReviewScheduleRepository.migratedMarkerKey), 'done');
  });

  test('SP blob 顶层损坏：迁移失败降级 SP 模式，不写标记（下次启动可重试）', () async {
    SharedPreferences.setMockInitialValues({ReviewScheduleRepository.cardsPrefKey: '{not-valid-json'});

    final store = await newStore();
    final repo = ReviewScheduleRepository(store: store);
    await repo.initialize();

    expect(repo.usesSqlite, isFalse);
    expect(await store.cardCount(), 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ReviewScheduleRepository.migratedMarkerKey), isNull);
  });

  test('SQLite 模式评分往返：重开仓储后卡片/统计/日期一致，forget 删除生效', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await newStore();

    final writer = ReviewScheduleRepository(store: store);
    await writer.initialize();
    await writer.rateWord(word: 'learned', rating: FsrsRating.good);
    await writer.rateWord(word: 'learned', rating: FsrsRating.again);
    await writer.rateWord(word: 'forgotten', rating: FsrsRating.easy);
    await writer.forget('forgotten');

    // 全新仓储实例 + 同一底层库：验证持久化而非内存缓存。
    final reader = ReviewScheduleRepository(store: await newStore());
    await reader.initialize();

    expect(reader.usesSqlite, isTrue);
    expect(reader.cardFor('learned'), isNotNull);
    expect(reader.cardFor('learned')!.isNew, isFalse);
    expect(reader.cardFor('forgotten'), isNull);
    expect(reader.todayLearnCount, 2);
    expect(reader.todayReviewCount, 1);
    expect(reader.activeDateCount, 1);
    expect(await store.cardCount(), 1);
  });

  test('SP 降级模式下评分仍写旧 key（旧版装回可读到迁移前历史）', () async {
    // 顶层 blob 损坏 → 迁移失败 → SP 模式；此时评分应写回 SP。
    SharedPreferences.setMockInitialValues({ReviewScheduleRepository.cardsPrefKey: '{broken'});

    final store = await newStore();
    final repo = ReviewScheduleRepository(store: store);
    await repo.initialize();
    await repo.rateWord(word: 'fallback-word', rating: FsrsRating.good);

    expect(repo.usesSqlite, isFalse);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(ReviewScheduleRepository.cardsPrefKey)!;
    expect(raw, contains('fallback-word'));
    expect(prefs.getString(ReviewScheduleRepository.dailyStatsPrefKey), isNotNull);
    expect(prefs.getStringList(ReviewScheduleRepository.activeDatesPrefKey), isNotEmpty);
  });
}
