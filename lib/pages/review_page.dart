// 正式复习路由协调层：会话、词条操作和视觉布局各自独立。
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/di/service_locator.dart';
import '../features/learning/presentation/review_queue_state.dart';
import '../features/learning/presentation/review_session_state.dart';
import '../features/learning/presentation/review_word_actions_state.dart';
import '../features/learning/presentation/widgets/formal_review_widgets.dart';
import '../models/bb_word_process.dart';
import '../models/word.dart';
import '../pages/dictionary_page.dart';
import '../services/audio_service.dart';
import '../state/wallpaper_state.dart';
import '../widgets/session_exit_guard.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  static const routeName = '/review';

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool _audioLoading = false;

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
          session: session,
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
          audioLoading: _audioLoading,
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
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.volume_up),
              title: const Text('播放发音'),
              onTap: () {
                Navigator.pop(sheetContext);
                final word = context.read<ReviewSessionState>().currentWord;
                if (word != null) _playWordAudio(word);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('查看详情'),
              onTap: () {
                Navigator.pop(sheetContext);
                final word = context.read<ReviewSessionState>().currentWord;
                if (word != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DictionaryPage(
                        word: Word(
                          id: word.wordId,
                          word: word.word,
                          mainWord: word.word,
                          interpret: word.interpret,
                          usPron: word.usPron,
                          ukPron: word.ukPron,
                          example: word.example,
                          phrase: '',
                          confuse: '',
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _playWordAudio(BBWordProcess word) async {
    if (_audioLoading) return;
    setState(() => _audioLoading = true);
    try {
      await sl<AudioService>().playWordAudio(word.word);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('发音加载失败，请检查网络'), duration: Duration(seconds: 2)));
      }
    } finally {
      if (mounted) setState(() => _audioLoading = false);
    }
  }
}
