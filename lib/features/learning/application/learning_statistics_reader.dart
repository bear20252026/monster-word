import 'package:flutter/foundation.dart';

/// 学习统计的跨 feature 共享只读契约（core 层，单向依赖）。
///
/// 由 learning 模块的学习统计状态实现（见
/// `lib/features/learning/presentation/learning_statistics_state.dart`），并经由
/// learning feature scope 以 `LearningStatisticsReader` 类型暴露。
///
/// 装配约定：word_browse 等消费方（如 `foot_mark_page`）只依赖本契约读取
/// 待复习数、学习天数等统计字段，不再 import learning/presentation 的具体统计状态；
/// 规则同 `LearningCollectionsReader`。
abstract class LearningStatisticsReader extends ChangeNotifier {
  /// 本次学习队列总词数。
  int get total;

  /// 待复习（到期）卡片数。
  int get dueCount;

  /// 已学卡片数。
  int get learnedCount;

  /// 累计学习天数。
  int get totalLearnedDays;
}
