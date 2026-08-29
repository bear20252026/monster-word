// 正式复习路由协调层：会话、词条操作和视觉布局各自独立。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../application/review_session_starter.dart';
import '../application/review_word_details.dart';
import 'review_audio_state.dart';
import 'review_queue_state.dart';
import 'review_word_action_coordinator.dart';
import 'review_word_action_feedback.dart';
import 'review_session_state.dart';
import 'review_word_actions_state.dart';
import 'widgets/formal_review_widgets.dart';
import '../../../models/bb_word_process.dart';
import '../../../core/router/route_names.dart';
import '../../../state/wallpaper_state.dart';
import '../../../core/router/nav_utils.dart';
import '../../../widgets/session_exit_guard.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  static const routeName = '/review';

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
    required BBWordProcess word,
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
          showAnswer: session.showAnswer,
          wallpaper: context.watch<WallpaperState>().current,
          isFavorite: wordActions.isFavorite(word.word),
          onBack: () => NavUtils.safePop(context),
          onToggleFavorite: _toggleFavorite,
          onMarkAsKnown: _markAsKnown,
          onShowMore: () => _showMoreOptions(context),
          onPlayAudio: _playWordAudio,
          onSelectChoice: session.selectChoice,
          onRevealAnswer: session.revealAnswer,
          onContinueWithGoodRating: session.continueWithGoodRating,
          audioLoading: reviewAudio.isLoading,
        ),
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    final result = await _wordActionCoordinator().toggleFavorite();
    _showWordActionFeedback(result);
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

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: result.feedbackDuration));
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

  void _openWordDetails(BBWordProcess word) {
    Navigator.pushNamed(context, RouteNames.dictionary, arguments: word.toDictionaryWord());
  }

  Future<void> _playWordAudio(BBWordProcess word) async {
    try {
      await context.read<ReviewAudioState>().playWord(word.word);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('发音加载失败，请检查网络'), duration: Duration(seconds: 2)));
      }
    }
  }
}
