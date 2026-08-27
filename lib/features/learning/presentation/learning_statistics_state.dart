import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../data/wordbook_database.dart' show Book;
import '../data/review_schedule_repository.dart';
import 'learning_queue_state.dart';

/// 学习展示层使用的不可变统计快照。
///
/// 该模型只暴露首页与仪表盘所需的只读字段，不承载评分、词书加载、
/// 收藏或持久化等会话行为。
class LearningStatisticsSnapshot {
  const LearningStatisticsSnapshot({
    required this.currentBook,
    required this.total,
    required this.dueCount,
    required this.learnedCount,
    required this.totalLearnedDays,
    required this.memoryStats,
    required this.todayStats,
  });

  factory LearningStatisticsSnapshot.empty() {
    return const LearningStatisticsSnapshot(
      currentBook: null,
      total: 0,
      dueCount: 0,
      learnedCount: 0,
      totalLearnedDays: 0,
      memoryStats: <String, int>{},
      todayStats: <String, int>{},
    );
  }

  factory LearningStatisticsSnapshot.fromSources({
    required LearningQueueSnapshot queue,
    required ReviewScheduleRepository schedule,
  }) {
    final memoryStats = schedule.memoryStats;
    return LearningStatisticsSnapshot(
      currentBook: queue.currentBook,
      total: queue.total,
      dueCount: schedule.dueCount,
      learnedCount: queue.learnedCount,
      totalLearnedDays: schedule.activeDateCount,
      memoryStats: UnmodifiableMapView(Map<String, int>.from(memoryStats)),
      todayStats: UnmodifiableMapView({
        'learned': queue.total - (memoryStats['new'] ?? 0),
        'due': memoryStats['due'] ?? 0,
        'total': memoryStats['total'] ?? 0,
        'mature': memoryStats['mature'] ?? 0,
      }),
    );
  }

  final Book? currentBook;
  final int total;
  final int dueCount;
  final int learnedCount;
  final int totalLearnedDays;
  final Map<String, int> memoryStats;
  final Map<String, int> todayStats;

  int memoryStat(String key) => memoryStats[key] ?? 0;

  int todayStat(String key) => todayStats[key] ?? 0;
}

/// 学习统计的过渡展示状态。
///
/// 当前由 [LearningQueueSnapshot] 与 [ReviewScheduleRepository] 同步：前者提供当前
/// 队列与词书，后者提供 FSRS 卡片和统计。当队列写入完成迁移后，只替换快照来源即可，
/// 页面无需再次依赖遗留状态。
class LearningStatisticsState extends ChangeNotifier {
  LearningStatisticsSnapshot _snapshot = LearningStatisticsSnapshot.empty();

  LearningStatisticsSnapshot get snapshot => _snapshot;

  Book? get currentBook => _snapshot.currentBook;

  int get total => _snapshot.total;

  int get dueCount => _snapshot.dueCount;

  int get learnedCount => _snapshot.learnedCount;

  int get totalLearnedDays => _snapshot.totalLearnedDays;

  Map<String, int> get memoryStats => _snapshot.memoryStats;

  Map<String, int> get todayStats => _snapshot.todayStats;

  void synchronize({required LearningQueueSnapshot queue, required ReviewScheduleRepository schedule}) {
    _snapshot = LearningStatisticsSnapshot.fromSources(queue: queue, schedule: schedule);
    notifyListeners();
  }
}
