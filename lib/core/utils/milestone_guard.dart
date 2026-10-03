// MilestoneGuard：金币里程碑跨档判定（蓝图 W3「临界值爆发 + 里程碑守卫」）。
//
// 纯函数，不持久化——跨档事件的「只庆祝一次」由调用方持久化
// （如 SP 记 lastCelebratedMilestone）。多档连跨（如 480→1200 同时跨
// 500 与 1000）取最大档，只庆祝一次。
class MilestoneGuard {
  MilestoneGuard._();

  /// 里程碑档位（升序）。
  static const List<int> thresholds = [100, 500, 1000, 5000];

  /// 余额从 [oldBalance] 变到 [newBalance] 时跨越的最大里程碑档位；
  /// 未跨档返回 null。负向变动（消费）不庆祝。
  static int? crossedMilestone(int oldBalance, int newBalance) {
    if (newBalance <= oldBalance) return null;
    int? crossed;
    for (final t in thresholds) {
      if (oldBalance < t && newBalance >= t) {
        crossed = t;
      }
    }
    return crossed;
  }
}
