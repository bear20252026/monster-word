// 正式复习路由协调层：会话、词条操作和视觉布局各自独立。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/learning/application/review_word_details.dart';
import '../features/learning/presentation/review_audio_state.dart';
import '../features/learning/presentation/review_queue_state.dart';
import '../features/learning/presentation/review_session_state.dart';
import '../features/learning/presentation/review_word_actions_state.dart';
import '../features/learning/presentation/widgets/formal_review_widgets.dart';
import '../models/bb_word_process.dart';
import '../pages/dictionary_page.dart';
import '../state/wallpaper_state.dart';
import '../widgets/session_exit_guard.dart';

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
    try {
      final reviewQueue = context.read<ReviewQueueState>();
      await context.read<ReviewSessionState>().initialize(reviewQueue.snapshot);
    } catch (_) {
      // 会话状态保存异常并触发错误视图；页面只负责提供重试回调。
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ReviewSessionState>();
    final wordActions = context.watch<ReviewWordActionsState>();
    final reviewAudio = context.watch<ReviewAudioState>();

    if (session.isLoading) return const FormalReviewLoadingView();
    if (session.hasLoadError) return FormalReviewLoadErrorView(error: session.loadError, onRetry: _initReview);

    final word = session.currentWord;
    if (word == null) {
      return FormalReviewCompleteView(
        done: session.done,
        onReturnHome: () => Navigator.of(context).pushReplacementNamed('/'),
      );
    }

    return SessionExitGuard(
      subject: '本次复习',
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
          onBack: () => Navigator.pop(context),
          onToggleFavorite: () {
            _toggleFavorite();
          },
          onMarkAsKnown: () {
            _markAsKnown();
          },
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
    final current = context.read<ReviewSessionState>().currentWord;
    if (current == null) return;

    try {
      final isFavorite = await context.read<ReviewWordActionsState>().toggleFavorite(current.word);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFavorite ? '已收藏 ${current.word}' : '已取消收藏'), duration: const Duration(seconds: 1)),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('收藏状态保存失败，请重试')));
      }
    }
  }

  Future<void> _markAsKnown() async {
    final session = context.read<ReviewSessionState>();
    final currentWord = session.currentWord;
    if (currentWord == null || !session.markAsKnown()) return;

    try {
      final marked = await context.read<ReviewWordActionsState>().markManuallyMastered(currentWord.word);
      if (mounted && marked) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('已标记掌握 ${currentWord.word}'), duration: const Duration(seconds: 1)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('掌握标记保存失败，请重试')));
      }
    }
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => DictionaryPage(word: word.toDictionaryWord())));
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
