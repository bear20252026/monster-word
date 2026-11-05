// 正式复习路由协调层：会话、词条操作和视觉布局各自独立。
import 'dart:async';

import 'package:word_app/widgets/common/mw_feedback.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:word_app/widgets/monster_answer_signal.dart';
import 'package:word_app/features/learning/application/boss_intro_day_store.dart';
import 'package:word_app/features/learning/application/review_session_snapshot_store.dart';
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
import 'package:word_app/core/utils/boss_siege.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  static const routeName = RouteNames.review;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final BossIntroDayStore _bossIntroDay = const BossIntroDayStore();
  final ReviewSessionSnapshotStore _snapshotStore = const ReviewSessionSnapshotStore();

  /// 当日首次入场是否已被消费（本局内只读一次，进入 pendingIntro 时置位并落盘）。
  bool _introPlayedToday = false;

  /// 入场动画是否正在播：true 期间保持 pendingIntro，动画结束（或 reduce-motion
  /// 直接跳过）后转 active 并解除答题冻结。
  bool _introPlaying = false;

  @override
  void initState() {
    super.initState();
    _introPlayedToday = _bossIntroDay.readDay() == bossDayStamp(DateTime.now());
    _initReview();
  }

  Future<void> _initReview() async {
    // 上次中断的一局：只有通过 sanitize 且词仍在当前到期集合里才会被恢复。
    final restore = _snapshotStore.read();
    final result = await ReviewSessionStarter(
      snapshot: context.read<ReviewQueueState>().snapshot,
      initialize: (snapshot) => context.read<ReviewSessionState>().initialize(snapshot, restore: restore),
    ).start();
    if (result == ReviewSessionStartResult.ready) _beginBossIntroIfFirstToday();
  }

  /// 当日首次、且确实触发头目时，进入入场动画并落盘日期（一天只演一次）。
  void _beginBossIntroIfFirstToday() {
    if (_introPlayedToday || !mounted) return;
    final session = context.read<ReviewSessionState>();
    final phase = resolveBossPhase(
      hadDueAtStart: session.hadDueAtStart,
      total: session.total,
      done: session.done,
      hasWord: session.currentWord != null,
      introPlayedToday: false,
    );
    if (phase != BossBattlePhase.pendingIntro) return;
    setState(() {
      _introPlayedToday = true;
      _introPlaying = true;
    });
    unawaited(_bossIntroDay.markDay(bossDayStamp(DateTime.now())));
  }

  void _onBossIntroFinished() {
    if (!mounted || !_introPlaying) return;
    setState(() => _introPlaying = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<ReviewSessionState>();
    final wordActions = context.watch<ReviewWordActionsState>();
    final reviewAudio = context.watch<ReviewAudioState>();

    final word = session.currentWord;
    // 触发口径只认会话开局冻结的 hadDueAtStart/total：中途 done 涨落、剩余
    // 跌破 40 都不会让已出现的头目消失（闩锁），唯一退场是 currentWord == null。
    // 当日首次入场在动画播完前仍算 pendingIntro（_introPlaying），播完才转 active。
    final bossPhase = resolveBossPhase(
      hadDueAtStart: session.hadDueAtStart,
      total: session.total,
      done: session.done,
      hasWord: word != null,
      introPlayedToday: _introPlayedToday && !_introPlaying,
    );
    final bossActive = bossPhase == BossBattlePhase.pendingIntro || bossPhase == BossBattlePhase.active;
    return FormalReviewPageContent(
      phase: formalReviewPagePhase(
        isLoading: session.isLoading,
        hasLoadError: session.hasLoadError,
        hasWord: word != null,
      ),
      loadError: session.loadError,
      done: session.done,
      word: word,
      bossBattle: bossPhase == BossBattlePhase.victory,
      onRetry: _initReview,
      onReturnHome: () => NavUtils.goHome(context),
      reviewingBuilder: (contentContext, reviewingWord) => _buildReviewingContent(
        context: contentContext,
        word: reviewingWord,
        session: session,
        wordActions: wordActions,
        reviewAudio: reviewAudio,
        bossActive: bossActive,
        bossIntroPending: bossPhase == BossBattlePhase.pendingIntro,
      ),
    );
  }

  Widget _buildReviewingContent({
    required BuildContext context,
    required MwWordProcess word,
    required ReviewSessionState session,
    required ReviewWordActionsState wordActions,
    required ReviewAudioState reviewAudio,
    required bool bossActive,
    required bool bossIntroPending,
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
          bossActive: bossActive,
          bossIntroPending: bossIntroPending,
          bossShieldSegments: bossShieldSegments(session.done),
          bossShieldCapacity: bossShieldCapacity(session.total),
          onBossIntroFinished: _onBossIntroFinished,
          bossStepLabel: bossStepLabel(session.done, session.total),
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
