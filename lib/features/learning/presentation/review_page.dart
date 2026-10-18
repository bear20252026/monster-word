// 正式复习路由协调层：会话、词条操作和视觉布局各自独立。
import 'package:word_app/widgets/common/mw_feedback.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/widgets/monster_answer_signal.dart';
import 'package:word_app/features/learning/application/review_session_starter.dart';
import 'package:word_app/features/learning/application/review_word_details.dart';
import 'package:word_app/features/learning/presentation/review_audio_state.dart';
import 'package:word_app/features/learning/presentation/review_queue_state.dart';
import 'package:word_app/features/learning/presentation/review_word_action_coordinator.dart';
import 'package:word_app/features/learning/presentation/review_word_action_feedback.dart';
import 'package:word_app/features/learning/presentation/review_session_state.dart';
import 'package:word_app/features/learning/presentation/review_word_actions_state.dart';
import 'package:word_app/features/learning/presentation/widgets/formal_review_widgets.dart';
import 'package:word_app/models/mw_word_process.dart';
import 'package:word_app/app/router/route_names.dart';
import 'package:word_app/theme/wallpaper_state.dart';
import 'package:word_app/app/router/nav_utils.dart';
import 'package:word_app/widgets/session_exit_guard.dart';
import 'package:word_app/core/application/app_messages.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  static const routeName = RouteNames.review;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  @override
  void initState() {
    super.initState();
    _initReview();
  }

  Future<void> _initReview() async {
    await ReviewSessionStarter(
      snapshot: context.read<ReviewQueueState>().snapshot,
      initialize: context.read<ReviewSessionState>().initialize,
    ).start();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ReviewSessionState>();
    final wordActions = context.watch<ReviewWordActionsState>();
    final reviewAudio = context.watch<ReviewAudioState>();

    final word = session.currentWord;
    return FormalReviewPageContent(
      phase: formalReviewPagePhase(
        isLoading: session.isLoading,
        hasLoadError: session.hasLoadError,
        hasWord: word != null,
      ),
      loadError: session.loadError,
      done: session.done,
      word: word,
      onRetry: _initReview,
      onReturnHome: () => NavUtils.goHome(context),
      reviewingBuilder: (contentContext, reviewingWord) => _buildReviewingContent(
        context: contentContext,
        word: reviewingWord,
        session: session,
        wordActions: wordActions,
        reviewAudio: reviewAudio,
      ),
    );
  }

  Widget _buildReviewingContent({
    required BuildContext context,
    required MwWordProcess word,
    required ReviewSessionState session,
    required ReviewWordActionsState wordActions,
    required ReviewAudioState reviewAudio,
  }) {
    return SessionExitGuard(
      subject: '本次复习',
      shouldIntercept: () => session.done == 0 && session.total > 0,
      child: Scaffold(
        body: FormalReviewSessionLayout(
          word: word,
          choices: session.choices,
          done: session.done,
          total: session.total,
          selectedWrongChoice: session.selectedWrongChoice,
          correctRevealed: session.correctRevealed,
          showAnswer: session.showAnswer,
          wallpaper: context.watch<WallpaperState>().current,
          isFavorite: wordActions.isFavorite(word.word),
          onBack: () => NavUtils.safePop(context),
          onToggleFavorite: _toggleFavorite,
          onMarkAsKnown: _markAsKnown,
          onShowMore: () => _showMoreOptions(context),
          onPlayAudio: _playWordAudio,
          onSelectChoice: (choice) => _onSelectChoice(session, choice),
          onRevealAnswer: session.revealAnswer,
          onContinueWithGoodRating: () => _continueReview(session),
          audioLoading: reviewAudio.isLoading,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final result = await _wordActionCoordinator().toggleFavorite();
    _showWordActionFeedback(result);
  }

  /// 选项点选：先交会话处理，再把「对/错」这个事实报给演出层。
  ///
  /// 2026-10-17 companion：正式复习页原本**完全没有怪兽**，用户在这一屏学得最吃力
  /// 却看不到任何陪伴。报事实这一层先落地（连续答错的升级由 companion 自己数），
  /// 复习页内的怪兽呈现留到下一步。
  void _onSelectChoice(ReviewSessionState session, String choice) {
    session.selectChoice(choice);
    final wrong = session.selectedWrongChoice == choice;
    announceMonsterAnswer(context, correct: !wrong);
  }

  /// 「看答案后继续」：**先落盘、成功才翻页**（审计 P1-04，业主选定「甲」）。
  ///
  /// 写库失败时会话不会推进，这里必须把失败告诉用户 —— 否则他会以为这题
  /// 已经复习完，实际记录没保存，而复习队列下次还会把它当成没复习过。
  Future<void> _continueReview(ReviewSessionState session) async {
    final advanced = await session.continueWithGoodRating();
    if (advanced || !mounted) return;
    showMwSnackBar(
      context,
      const SnackBar(content: Text('这条复习记录没保存成功，请再点一次（存储空间或数据库异常）'), duration: Duration(seconds: 4)),
    );
  }

  Future<void> _markAsKnown() async {
    final result = await _wordActionCoordinator().markCurrentWordAsKnown();
    _showWordActionFeedback(result);
  }

  ReviewWordActionCoordinator _wordActionCoordinator() {
    final session = context.read<ReviewSessionState>();
    return ReviewWordActionCoordinator(
      wordActions: context.read<ReviewWordActionsState>(),
      currentWord: () => session.currentWord,
      markCurrentWordAsKnown: session.markAsKnown,
    );
  }

  void _showWordActionFeedback(ReviewWordActionResult result) {
    final message = result.feedbackMessage;
    if (!mounted || message == null) return;

    showMwSnackBar(context, SnackBar(content: Text(message), duration: result.feedbackDuration));
  }

  void _showMoreOptions(BuildContext context) {
    final word = context.read<ReviewSessionState>().currentWord;
    if (word == null) return;

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => FormalReviewMoreOptionsSheet(
        onPlayAudio: () {
          Navigator.pop(sheetContext);
          _playWordAudio(word);
        },
        onShowDetails: () {
          Navigator.pop(sheetContext);
          _openWordDetails(word);
        },
      ),
    );
  }

  void _openWordDetails(MwWordProcess word) {
    Navigator.pushNamed(context, RouteNames.dictionary, arguments: word.toDictionaryWord());
  }

  Future<void> _playWordAudio(MwWordProcess word) async {
    try {
      await context.read<ReviewAudioState>().playWord(word.word);
    } catch (_) {
      if (mounted) {
        showMwSnackBar(
          context,
          const SnackBar(content: Text(AppMessages.audioLoadFailed), duration: Duration(seconds: 2)),
        );
      }
    }
  }
}
