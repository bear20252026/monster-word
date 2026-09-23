// MEM/F3：ReviewScheduleRepository 子集加载语义测试。
//
// 关键回归点：SQLite 模式下 _cards 只是「到期子集 + 补齐缓存」——
// 已学但未到期的词不在 map 时，评分必须查库防「重置为新学」，
// forget 必须能删到不在 map 的卡，计数必须与全表一致。
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/features/learning/data/review_schedule_repository.dart';
import 'package:word_app/features/learning/data/review_schedule_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Database db;
  late ReviewScheduleStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    databaseFactory = databaseFactoryFfi;
    db = await openDatabase(inMemoryDatabasePath);
    store = await ReviewScheduleStore.forTest(db);
  });

  tearDown(() async {
    await db.close();
  });

  FsrsCard matureCard(String word, {DateTime? dueDate}) {
    return FsrsCard(
      word: word,
      stability: 12,
      difficulty: 5,
      lastReview: DateTime.now().subtract(const Duration(days: 3)),
      dueDate: dueDate ?? DateTime.now().add(const Duration(days: 20)),
      repetitions: 4,
      reviewCount: 6,
      isNew: false,
      shortTermStability: 1,
    );
  }

  group('MEM/F3 子集加载下的仓储语义', () {
    test('启动只装到期子集，计数仍来自全表聚合', () async {
      final now = DateTime.now();
      await store.insertCardsInTransaction([
        matureCard('future-word'),
        matureCard('future-word-2'),
        FsrsCard(
          word: 'due-word',
          stability: 5,
          difficulty: 5,
          lastReview: now.subtract(const Duration(days: 3)),
          dueDate: now.subtract(const Duration(days: 1)),
          isNew: false,
        ),
      ]);

      final schedule = ReviewScheduleRepository(store: store);
      await schedule.initialize();

      // 到期子集：due-word 必已在内存（复习关键路径 t0 正确）
      expect(schedule.cardFor('due-word'), isNotNull);
      // 计数是全表口径，不因子集加载失真
      expect(schedule.dueCount, 1);
      expect(schedule.memoryStats['total'], 3);
      expect(schedule.memoryStats['due'], 1);
      expect(schedule.memoryStats['mature'], 2);

      // 后台补齐完成后全量进图
      await schedule.debugTopUpDone;
      expect(schedule.cardFor('future-word'), isNotNull);
    });

    test('幽灵卡防护：map 未命中的已学词评分走 review 而非 learn', () async {
      final schedule = ReviewScheduleRepository(store: store);
      await schedule.initialize();
      await schedule.debugTopUpDone; // 空表，map 确定为空

      // 绕过仓储直接往库里插一张「已学未到期」卡——模拟补齐窗口外的存量卡
      await store.insertCardsInTransaction([matureCard('ghost-word')]);

      await schedule.rateWord(word: 'ghost-word', rating: FsrsRating.good);

      expect(schedule.todayReviewCount, 1, reason: '已学词评分必须计入 review');
      expect(schedule.todayLearnCount, 0, reason: '绝不允许把已学词当新学（重置调度进度）');
      // 库侧计数：评分 UPSERT 未把该词重置为新学（仍是 1 行学习记录）
      final counts = await store.loadCounts(DateTime.now());
      expect(counts.total, 1);
      expect(counts.newCount, 0);
    });

    test('forget 能删除不在内存 map 的存量卡', () async {
      // 先落库再 initialize：计数聚合并入该行后再验证 forget 的减量
      await store.insertCardsInTransaction([matureCard('ghost-word')]);
      final schedule = ReviewScheduleRepository(store: store);
      await schedule.initialize();
      await schedule.debugTopUpDone;

      await schedule.forget('ghost-word');

      expect(await store.cardForWord('ghost-word'), isNull, reason: '不在 map 的卡也必须从库中删除');
      expect(schedule.memoryStats['total'], 0);
    });

    test('读穿填充：cardFor 未命中异步查库并通知', () async {
      final schedule = ReviewScheduleRepository(store: store);
      await schedule.initialize();
      await schedule.debugTopUpDone;

      await store.insertCardsInTransaction([matureCard('late-word')]);

      // 首次同步读：未命中触发异步填充
      schedule.cardFor('late-word');
      await schedule.debugFlushFills();

      expect(schedule.cardFor('late-word'), isNotNull);
    });

    test('评分后计数与到期集合随写路径增量正确', () async {
      final schedule = ReviewScheduleRepository(store: store);
      await schedule.initialize();

      await schedule.rateWord(word: 'fresh-word', rating: FsrsRating.good);

      expect(schedule.memoryStats['total'], 1);
      expect(schedule.todayLearnCount, 1);
      // 新学卡短期到期（引擎调度），dueCount 反映写后状态且与库一致
      final counts = await store.loadCounts(DateTime.now());
      expect(counts.total, 1);
      expect(schedule.dueCount, counts.due);
    });
  });
}
