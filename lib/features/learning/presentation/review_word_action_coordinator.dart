import 'package:word_app/models/bb_word_process.dart';
import 'package:word_app/features/learning/presentation/review_word_actions_state.dart';

/// 从当前正式复习会话读取词条的只读端口。
typedef CurrentReviewWord = BBWordProcess? Function();

/// 推进当前正式复习词条的“手动掌握”命令端口。
typedef MarkCurrentReviewWordAsKnown = bool Function();

/// 正式复习词条操作的明确结果。
enum ReviewWordActionOutcome {
  ignored,
  favoriteAdded,
  favoriteRemoved,
  manuallyMastered,
  alreadyManuallyMastered,
  favoritePersistFailed,
  manualMasteryPersistFailed,
}

/// 将词条操作的持久化结果与页面反馈意图分离。
class ReviewWordActionResult {
  const ReviewWordActionResult({required this.outcome, this.word});

  final ReviewWordActionOutcome outcome;
  final String? word;

  bool get isSuccess => switch (outcome) {
    ReviewWordActionOutcome.favoriteAdded ||
    ReviewWordActionOutcome.favoriteRemoved ||
    ReviewWordActionOutcome.manuallyMastered => true,
    _ => false,
  };

  bool get shouldShowFeedback => switch (outcome) {
    ReviewWordActionOutcome.ignored || ReviewWordActionOutcome.alreadyManuallyMastered => false,
    _ => true,
  };
}

/// 正式复习词条操作协调器。
///
/// 本协调器保留既有顺序：收藏先持久化后更新展示快照；“熟”先推进当前会话，
/// 再写入幂等手动掌握标记。它不依赖 BuildContext、Navigator 或 SnackBar。
class ReviewWordActionCoordinator {
  const ReviewWordActionCoordinator({
    required this._wordActions,
    required this._currentWord,
    required this._markCurrentWordAsKnown,
  });

  final ReviewWordActionsState _wordActions;
  final CurrentReviewWord _currentWord;
  final MarkCurrentReviewWordAsKnown _markCurrentWordAsKnown;

  Future<ReviewWordActionResult> toggleFavorite() async {
    final currentWord = _currentWord();
    if (currentWord == null) return const ReviewWordActionResult(outcome: ReviewWordActionOutcome.ignored);

    try {
      final isFavorite = await _wordActions.toggleFavorite(currentWord.word);
      return ReviewWordActionResult(
        outcome: isFavorite ? ReviewWordActionOutcome.favoriteAdded : ReviewWordActionOutcome.favoriteRemoved,
        word: currentWord.word,
      );
    } catch (_) {
      return ReviewWordActionResult(outcome: ReviewWordActionOutcome.favoritePersistFailed, word: currentWord.word);
    }
  }

  Future<ReviewWordActionResult> markCurrentWordAsKnown() async {
    final currentWord = _currentWord();
    if (currentWord == null || !_markCurrentWordAsKnown()) {
      return const ReviewWordActionResult(outcome: ReviewWordActionOutcome.ignored);
    }

    try {
      final marked = await _wordActions.markManuallyMastered(currentWord.word);
      return ReviewWordActionResult(
        outcome: marked ? ReviewWordActionOutcome.manuallyMastered : ReviewWordActionOutcome.alreadyManuallyMastered,
        word: currentWord.word,
      );
    } catch (_) {
      return ReviewWordActionResult(
        outcome: ReviewWordActionOutcome.manualMasteryPersistFailed,
        word: currentWord.word,
      );
    }
  }
}
