// 由 Claude 团队生成 | Monster Word App
// StatsRepositoryImpl — 统计数据仓库实现

import '../services/stats_service.dart';
import 'stats_repository.dart';

/// 统计数据仓库实现
class StatsRepositoryImpl implements StatsRepository {
  final StatsService _statsService;

  StatsRepositoryImpl({required StatsService statsService})
      : _statsService = statsService;

  @override
  Future<Map<String, dynamic>> getStats() async {
    return await _statsService.getStats();
  }

  @override
  Future<Map<String, dynamic>> getTodayStats() async {
    return await _statsService.getTodayStats();
  }

  @override
  Future<List<Map<String, dynamic>>> getWeeklyStats() async {
    return await _statsService.getWeeklyStats();
  }
}
