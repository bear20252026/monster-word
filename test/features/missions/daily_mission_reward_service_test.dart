import 'package:flutter_test/flutter_test.dart';
import 'package:word_app/features/missions/application/daily_mission_repository.dart';
import 'package:word_app/features/missions/application/daily_mission_reward_service.dart';
import 'package:word_app/features/missions/application/daily_mission_store.dart';

import '../checkin/data/fake_scare_coin_store.dart';

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
  test('三条任务各 5 币，日上限 15；重复结算不重复发', () async {
    final repo = _MemoryRepository();
    final store = DailyMissionStore(repository: repo, clock: () => DateTime(2026, 11, 7, 9));
    await store.ensureLoaded(dueNow: 5);
    for (var i = 0; i < 10; i++) {
      await store.recordNewWordLearned();
    }
    for (var i = 0; i < 5; i++) {
      await store.recordReviewedWord();
    }
    await store.recordSessionAccuracyPercent(90);
    await store.refreshDue(dueNow: 0);
    expect(store.allCompleted, isTrue);

    final coins = FakeScareCoinStore();
    final service = DailyMissionRewardService(store: store, coins: coins);

    final first = await service.settle();
    expect(first, dailyMissionDailyCoinCap);
    expect(coins.balanceValue, dailyMissionDailyCoinCap);

    // 第二次结算（例如再次进入首页）：没有待结算任务，0 币。
    final second = await service.settle();
    expect(second, 0);
    expect(coins.balanceValue, dailyMissionDailyCoinCap);
  });

  test('同一天同一任务的事件键已存在时不重复加币（跨 Store 实例重入）', () async {
    final coins = FakeScareCoinStore();
    // 模拟：上一次结算已经写过事件键，但本地 claimed 标记丢了。
    coins.rewardEvents.add('mission:2026-11-07:learn_new');

    final repo = _MemoryRepository();
    final store = DailyMissionStore(repository: repo, clock: () => DateTime(2026, 11, 7, 9));
    await store.ensureLoaded(dueNow: 0);
    for (var i = 0; i < 10; i++) {
      await store.recordNewWordLearned();
    }
    final service = DailyMissionRewardService(store: store, coins: coins);
    final granted = await service.settle();
    expect(granted, 0);
    expect(coins.balanceValue, 0);
    // 事件键已存在 → 视为已领取，落本地标记，避免每次首页都再撞一次。
    expect(store.missions[0].rewardClaimed, isTrue);
  });

  test('未完成的任务不发币', () async {
    final repo = _MemoryRepository();
    final store = DailyMissionStore(repository: repo, clock: () => DateTime(2026, 11, 7, 9));
    await store.ensureLoaded(dueNow: 0);
    await store.recordNewWordLearned();
    final coins = FakeScareCoinStore();
    expect(await DailyMissionRewardService(store: store, coins: coins).settle(), 0);
    expect(coins.balanceValue, 0);
  });
}
