import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/missions/application/daily_mission_repository.dart';
import 'package:word_app/features/missions/application/daily_mission_store.dart';

class _MemoryRepository implements DailyMissionRepository {
  final Map<String, Map<DailyMissionId, DailyMissionRecord>> rows = {};

  @override
  Future<Map<DailyMissionId, DailyMissionRecord>> load(String day) async =>
      Map<DailyMissionId, DailyMissionRecord>.from(rows[day] ?? const {});

  @override
  Future<void> save(String day, DailyMissionId id, DailyMissionRecord record) async {
    rows.putIfAbsent(day, () => {})[id] = record;
  }
}

void main() {
  late _MemoryRepository repo;
  late DateTime now;

  DailyMissionStore buildStore() => DailyMissionStore(repository: repo, clock: () => now);

  setUp(() {
    repo = _MemoryRepository();
    now = DateTime(2026, 11, 7, 9);
  });

  test('初始三条任务：新词 10 / 复习目标跟随到期数 / 正确率 80', () async {
    final store = buildStore();
    await store.ensureLoaded(dueNow: 5);
    final missions = store.missions;
    expect(missions, hasLength(3));
    expect(missions[0].target, 10);
    expect(missions[1].target, 5);
    expect(missions[2].target, 80);
    expect(store.completedCount, 0);
  });

  test('到期不足 20：复习实际数即完成', () async {
    final store = buildStore();
    await store.ensureLoaded(dueNow: 5);
    for (var i = 0; i < 5; i++) {
      await store.recordReviewedWord();
    }
    await store.refreshDue(dueNow: 0);
    expect(store.missions[1].completed, isTrue);
    expect(store.completedCount, 1);
  });

  test('到期 30：复习满 20 完成，进度越界不会提前完成', () async {
    final store = buildStore();
    await store.ensureLoaded(dueNow: 30);
    for (var i = 0; i < 19; i++) {
      await store.recordReviewedWord();
    }
    expect(store.missions[1].completed, isFalse);
    await store.recordReviewedWord();
    expect(store.missions[1].completed, isTrue);
  });

  test('学 10 新词：第 10 个才完成', () async {
    final store = buildStore();
    await store.ensureLoaded(dueNow: 0);
    for (var i = 0; i < 9; i++) {
      await store.recordNewWordLearned();
    }
    expect(store.missions[0].completed, isFalse);
    await store.recordNewWordLearned();
    expect(store.missions[0].completed, isTrue);
  });

  test('正确率任务记当日最高值，80 才完成', () async {
    final store = buildStore();
    await store.ensureLoaded(dueNow: 0);
    await store.recordSessionAccuracyPercent(60);
    await store.recordSessionAccuracyPercent(55); // 低于最高值不回退
    expect(store.missions[2].progress, 60);
    expect(store.missions[2].completed, isFalse);
    await store.recordSessionAccuracyPercent(80);
    expect(store.missions[2].progress, 80);
    expect(store.missions[2].completed, isTrue);
  });

  test('跨天重置进度（本地 0 点为界）', () async {
    final store = buildStore();
    await store.ensureLoaded(dueNow: 5);
    await store.recordReviewedWord();
    await store.recordNewWordLearned();
    now = DateTime(2026, 11, 8, 0, 1);
    await store.ensureLoaded(dueNow: 5);
    expect(store.day, '2026-11-08');
    expect(store.missions[0].progress, 0);
    expect(store.missions[1].progress, 0);
    expect(store.completedCount, 0);
  });

  test('完成时间一旦落库不因目标变化回退', () async {
    final store = buildStore();
    await store.ensureLoaded(dueNow: 3);
    for (var i = 0; i < 3; i++) {
      await store.recordReviewedWord();
    }
    await store.refreshDue(dueNow: 0);
    expect(store.missions[1].completed, isTrue);
    // 又出现新的到期词（目标变大）也不会取消已完成状态。
    await store.refreshDue(dueNow: 10);
    expect(store.missions[1].completed, isTrue);
  });

  test('发币标记幂等：重复 markRewardClaimed 不变', () async {
    final store = buildStore();
    await store.ensureLoaded(dueNow: 3);
    for (var i = 0; i < 3; i++) {
      await store.recordReviewedWord();
    }
    await store.refreshDue(dueNow: 0);
    expect(store.completedUnclaimed, hasLength(1));
    await store.markRewardClaimed(DailyMissionId.reviewDue);
    final claimedAt = repo.rows[store.day]![DailyMissionId.reviewDue]!.rewardClaimedAt;
    expect(claimedAt, isNotNull);
    await store.markRewardClaimed(DailyMissionId.reviewDue);
    expect(repo.rows[store.day]![DailyMissionId.reviewDue]!.rewardClaimedAt, claimedAt);
    expect(store.completedUnclaimed, isEmpty);
  });

  test('当日进度落库后，新 Store 实例可恢复（同日重启）', () async {
    final first = buildStore();
    await first.ensureLoaded(dueNow: 20);
    for (var i = 0; i < 7; i++) {
      await first.recordReviewedWord();
    }
    final second = buildStore();
    await second.ensureLoaded(dueNow: 13);
    expect(second.missions[1].progress, 7);
    expect(second.missions[1].target, 20);
  });
}
