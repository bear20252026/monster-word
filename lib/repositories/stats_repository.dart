// 由 Claude 团队生成 | Monster Word App
// StatsRepository — 统计数据仓库

/// 统计数据仓库接口
abstract class StatsRepository {
  Future<Map<String, dynamic>> getStats();
  Future<Map<String, dynamic>> getTodayStats();
  Future<List<Map<String, dynamic>>> getWeeklyStats();
}
