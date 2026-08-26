// 用户学习统计 ViewModel — 学习统计、连续天数
import 'package:flutter/foundation.dart';

import '../services/stats_service.dart';

/// 用户学习统计 ViewModel
///
/// 负责管理学习统计数据、连续天数、每日学习量。
/// 通过 StatsService 访问统计业务逻辑。
class UserStatsState extends ChangeNotifier {
  final StatsService _statsService;

  UserStatsState({required StatsService statsService})
      : _statsService = statsService;

  int _consecutiveDays = 0;
  int _totalWordsLearned = 0;
  int _totalWordsReviewed = 0;
  bool _initialized = false;

  int get consecutiveDays => _consecutiveDays;
  int get totalWordsLearned => _totalWordsLearned;
  int get totalWordsReviewed => _totalWordsReviewed;
  bool get initialized => _initialized;

  int get totalWords => _totalWordsLearned + _totalWordsReviewed;

  /// 初始化统计数据
  Future<void> init() async {
    await _loadStats();
    _initialized = true;
    notifyListeners();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _statsService.getStats();
      _consecutiveDays = stats['consecutiveDays'] as int? ?? 0;
      _totalWordsLearned = stats['totalLearned'] as int? ?? 0;
      _totalWordsReviewed = stats['totalReviewed'] as int? ?? 0;
    } catch (e) {
      debugPrint('[UserStatsState] load error: $e');
    }
  }

  /// 记录学习事件
  Future<void> recordLearnEvent(String word, {bool success = true}) async {
    await _statsService.recordLearnEvent(word, success: success);
    await _loadStats();
    notifyListeners();
  }

  /// 记录复习事件
  Future<void> recordReviewEvent(String word, {required int quality}) async {
    await _statsService.recordReviewEvent(word, quality: quality);
    await _loadStats();
    notifyListeners();
  }

  /// 刷新统计数据
  Future<void> refresh() async {
    await _loadStats();
    notifyListeners();
  }
}
