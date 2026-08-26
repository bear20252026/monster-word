// 由 Claude 团队生成 | Monster Word App
// StatsServiceImpl — 学习统计服务实现

import '../repositories/user_repository.dart';
import 'stats_service.dart';

/// 学习统计服务实现
class StatsServiceImpl implements StatsService {
  final UserRepository? _userRepo;

  StatsServiceImpl({UserRepository? userRepo}) : _userRepo = userRepo;

  @override
  Future<Map<String, dynamic>> getStats() async {
    if (_userRepo == null) return {};
    return await _userRepo!.getLearningStats();
  }

  @override
  Future<Map<String, dynamic>> getTodayStats() async {
    // TODO: 实现今日统计
    return {'today': 0};
  }

  @override
  Future<List<Map<String, dynamic>>> getWeeklyStats() async {
    // TODO: 实现周统计
    return [];
  }

  @override
  Future<void> recordLearnEvent(String word, {bool success = true}) async {
    // TODO: 记录学习事件到本地存储
  }

  @override
  Future<void> recordReviewEvent(String word, {required int quality}) async {
    // TODO: 记录复习事件到本地存储
  }
}
