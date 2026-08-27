import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../data/wordbook_database.dart' show Book;
import '../../../state/learning_state.dart';

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
    required this.memoryStats,
    required this.todayStats,
  });

  factory LearningStatisticsSnapshot.empty() {
    return const LearningStatisticsSnapshot(
      currentBook: null,
      total: 0,
      dueCount: 0,
      learnedCount: 0,
      memoryStats: <String, int>{},
      todayStats: <String, int>{},
    );
  }

  factory LearningStatisticsSnapshot.fromLegacy(LearningState legacy) {
    return LearningStatisticsSnapshot(
      currentBook: legacy.currentBook,
      total: legacy.total,
      dueCount: legacy.dueCount,
      learnedCount: legacy.learnedNum,
      memoryStats: UnmodifiableMapView(Map<String, int>.from(legacy.memoryStats)),
      todayStats: UnmodifiableMapView(Map<String, int>.from(legacy.todayStats)),
    );
  }

  final Book? currentBook;
  final int total;
  final int dueCount;
  final int learnedCount;
  final Map<String, int> memoryStats;
  final Map<String, int> todayStats;

  int memoryStat(String key) => memoryStats[key] ?? 0;

  int todayStat(String key) => todayStats[key] ?? 0;
}

/// 学习统计的过渡展示状态。
///
/// 当前由 [LearningState] 同步，以确保页面迁移不会改变既有统计来源。
/// 当统计持久化与查询服务完成迁移后，只替换该类的同步实现即可，页面
/// 无需再次依赖遗留状态。
class LearningStatisticsState extends ChangeNotifier {
  LearningStatisticsSnapshot _snapshot = LearningStatisticsSnapshot.empty();

  LearningStatisticsSnapshot get snapshot => _snapshot;

  Book? get currentBook => _snapshot.currentBook;

  int get total => _snapshot.total;

  int get dueCount => _snapshot.dueCount;

  int get learnedCount => _snapshot.learnedCount;

  Map<String, int> get memoryStats => _snapshot.memoryStats;

  Map<String, int> get todayStats => _snapshot.todayStats;

  void synchronizeFrom(LearningState legacy) {
    _snapshot = LearningStatisticsSnapshot.fromLegacy(legacy);
    notifyListeners();
  }
}
