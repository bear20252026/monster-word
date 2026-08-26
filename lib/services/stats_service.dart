// StatsService — 学习统计服务

/// 学习统计服务接口
abstract class StatsService {
  /// 获取学习统计
  Future<Map<String, dynamic>> getStats();

  /// 获取今日学习数据
  Future<Map<String, dynamic>> getTodayStats();

  /// 获取周学习数据
  Future<List<Map<String, dynamic>>> getWeeklyStats();

  /// 记录学习事件
  Future<void> recordLearnEvent(String word, {bool success = true});

  /// 记录复习事件
  Future<void> recordReviewEvent(String word, {required int quality});
}
