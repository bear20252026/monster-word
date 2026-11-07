/// XP 持久化端口：只存累计 XP，等级由 [xp_curve] 派生。
///
/// 实现放 data 层（`xp_state` 单行表 + `reward_events` 幂等键）；Store 只依赖
/// 本契约，便于纯函数单测。
abstract interface class XpRepository {
  /// 读取累计 XP；没有记录时返回 0（老用户从 0 起算）。
  Future<int> loadTotalXp();

  /// **幂等**累加：同一 [eventKey] 只加一次 XP，重复调用不会重复发放。
  ///
  /// 返回新的累计 XP；事件键已存在（同一局重复结算）时返回 null。
  Future<int?> addXpOnce({required String eventKey, required int delta});
}
