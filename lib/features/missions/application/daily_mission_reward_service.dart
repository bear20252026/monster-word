import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/features/missions/application/daily_mission_store.dart';
import 'package:word_app/features/scare_coin/application/scare_coin_store.dart';

/// D2：每日任务发币结算。
///
/// 幂等双保险：
///   1. `reward_events.event_key = mission:<day>:<taskId>` —— 同一天同一条任务
///      无论结算多少次，账本只加一次（并发也只成功一次）；
///   2. `daily_missions.reward_claimed_at` —— 本地已结算标记，避免每次进首页
///      都去撞一次事件键。
///
/// 只有当任务「已完成且未结算」时才发币，因此日上限天然是 5 × 3 = 15。
class DailyMissionRewardService {
  DailyMissionRewardService({required this.store, required this.coins});

  final DailyMissionStore store;
  final ScareCoinStore coins;

  /// 返回本次实际发出的币数（0 表示没有待结算任务，或都已发过）。
  Future<int> settle() async {
    var granted = 0;
    for (final mission in store.completedUnclaimed) {
      final eventKey = 'mission:${store.day}:${mission.id.key}';
      try {
        final balance = await coins.grantOnce(
          delta: dailyMissionCoinReward,
          reason: '每日任务·${mission.definition.title}',
          eventKey: eventKey,
        );
        if (balance != null) granted += dailyMissionCoinReward;
        // 事件键已存在（null）= 之前发过，同样落本地已结算标记，不再重试。
        await store.markRewardClaimed(mission.id);
      } catch (e, s) {
        // 发币失败：不落 claimed，下次结算会重试（事件键保证不重复发）。
        reportSwallowedError('每日任务发币失败（下次结算重试）', e, s);
        break;
      }
    }
    return granted;
  }
}
