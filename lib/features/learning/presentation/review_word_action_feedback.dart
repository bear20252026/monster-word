import 'package:word_app/features/learning/presentation/review_word_action_coordinator.dart';

/// 词条操作结果对应的页面反馈文案。
///
/// 页面只根据结果决定是否展示 Snackbar；文字与业务结果映射集中在此，
/// 不改变收藏和手动掌握各自独立的持久化语义。
extension ReviewWordActionFeedback on ReviewWordActionResult {
  String? get feedbackMessage => switch (outcome) {
    ReviewWordActionOutcome.favoriteAdded => '已收藏 $word',
    ReviewWordActionOutcome.favoriteRemoved => '已取消收藏',
    ReviewWordActionOutcome.manuallyMastered => '已标记掌握 $word',
    ReviewWordActionOutcome.favoritePersistFailed => '收藏状态保存失败，请重试',
    ReviewWordActionOutcome.manualMasteryPersistFailed => '掌握标记保存失败，请重试',
    ReviewWordActionOutcome.ignored || ReviewWordActionOutcome.alreadyManuallyMastered => null,
  };

  Duration get feedbackDuration => switch (outcome) {
    ReviewWordActionOutcome.favoriteAdded ||
    ReviewWordActionOutcome.favoriteRemoved ||
    ReviewWordActionOutcome.manuallyMastered => const Duration(seconds: 1),
    _ => const Duration(seconds: 4),
  };
}
