import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:word_app/core/engine/core_engine.dart' show WordChoicePair;
import 'package:word_app/core/engine/srs_engine.dart' show RecallRating;
import 'package:word_app/core/engine/super_memory_engine.dart';
import 'package:word_app/models/mw_word_process.dart';
import 'package:word_app/features/learning/application/review_queue_reader.dart';
import 'package:word_app/features/learning/application/review_rating_writer.dart';
import 'package:word_app/features/learning/application/review_session_question_factory.dart';
import 'package:word_app/features/learning/application/review_session_rating_executor.dart';
import 'package:word_app/features/learning/presentation/review_session_answer_state.dart';
// 埋点端口（跨 feature 只 import 对方的 application 层，架构守卫 R4 允许）。
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';

/// 正式复习队列加载的当前阶段。
enum ReviewSessionLoadPhase { idle, loading, ready, failed }

/// 正式复习会话的展示状态。
///
/// 该状态负责 `/review` 的内存题目队列、加载阶段、候选项、答题反馈和会话
/// 进度。词源选择由 [ReviewQueueReader] 负责，FSRS 卡片、统计和持久化写入
/// 由 [ReviewRatingWriter] 负责；两者均不在此重复实现。
class ReviewSessionState extends ChangeNotifier {
  ReviewSessionState({
    required this._queueReader,
    required ReviewRatingWriter ratingWriter,
    this._usageStats,
    SuperMemoryEngine? engine,
    ReviewSessionQuestionFactory? questionFactory,
  }) : _engine = engine ?? SuperMemoryEngine(),
       _questionFactory = questionFactory ?? const ReviewSessionQuestionFactory() {
    _ratingExecutor = ReviewSessionRatingExecutor(engine: _engine, ratingWriter: ratingWriter);
  }

  final ReviewQueueReader _queueReader;
  final SuperMemoryEngine _engine;
  final ReviewSessionQuestionFactory _questionFactory;
  late final ReviewSessionRatingExecutor _ratingExecutor;

  /// 使用统计埋点端口；未注入时为 null，埋点静默跳过。
  final UsageStatsRecorder? _usageStats;

  /// 本会话中「首次作答即答错」的题数（同一题反复点错只算一次）。
  ///
  /// 口径说明：与学习页的错词口径对齐——「答对」指没点错过。用户点错后
  /// 看答案继续（good 评分）仍计入错题，因为那题他确实没能一次答对。
  int _wrongCount = 0;

  /// 当前这一题是否已经点错过（用于同一题去重）。
  bool _currentQuestionWrong = false;

  ReviewSessionLoadPhase _loadPhase = ReviewSessionLoadPhase.idle;
  Object? _loadError;
  late final ReviewSessionAnswerState _answerState = ReviewSessionAnswerState(
    onChanged: notifyListeners,
    // 答对反馈驻留（对勾+彩带）结束后再推进评分，体验对齐学习页的答对时刻
    onCorrectFeedbackElapsed: () => rate(RecallRating.good),
  );
  List<WordChoicePair> _choices = const [];
  int _total = 0;
  int _done = 0;

  ReviewSessionLoadPhase get loadPhase => _loadPhase;
  bool get isLoading => _loadPhase == ReviewSessionLoadPhase.idle || _loadPhase == ReviewSessionLoadPhase.loading;
  bool get isReady => _loadPhase == ReviewSessionLoadPhase.ready;
  bool get hasLoadError => _loadPhase == ReviewSessionLoadPhase.failed;
  Object? get loadError => _loadError;
  bool get showAnswer => _answerState.showAnswer;
  String? get selectedWrongChoice => _answerState.selectedWrongChoice;
  List<WordChoicePair> get choices => _choices;
  int get total => _total;
  int get done => _done;
  MwWordProcess? get currentWord => _engine.currentWord();

  void updateRatingWriter(ReviewRatingWriter ratingWriter) {
    _ratingExecutor.updateRatingWriter(ratingWriter);
  }

  /// 按既有正式复习队列优先级初始化本地会话。
  Future<void> initialize(ReviewQueueSnapshot snapshot) async {
    _answerState.reset();
    _loadPhase = ReviewSessionLoadPhase.loading;
    _loadError = null;
    _choices = const [];
    _total = 0;
    _done = 0;
    _wrongCount = 0;
    _currentQuestionWrong = false;
    notifyListeners();

    try {
      final pool = await _queueReader.loadWords(snapshot);
      final processes = _questionFactory.createProcesses(pool);
      _engine.init(processes);
      _total = _engine.totalNum;
      _loadPhase = ReviewSessionLoadPhase.ready;
      _regenerateChoices();
    } catch (error) {
      _loadError = error;
      _loadPhase = ReviewSessionLoadPhase.failed;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// 处理一个候选项选择；错误选择会显示 300 毫秒的反馈，正确选择视作 good。
  void selectChoice(String selectedWord) {
    final reviewedWord = currentWord;
    if (reviewedWord == null) return;

    // 答对进入反馈驻留，驻留结束经 onCorrectFeedbackElapsed → rate(good) 推进；
    // 此处不再立即评分，避免对勾/彩带未展示即切题。
    final selection = _answerState.selectChoice(selectedWord: selectedWord, correctWord: reviewedWord.word);
    // 埋点口径：同一题只记一次错（反复点错不重复计）。
    if (selection == ReviewChoiceSelection.wrong && !_currentQuestionWrong) {
      _currentQuestionWrong = true;
      _wrongCount++;
    }
  }

  bool isWrongChoiceSelected(String word) => _answerState.isWrongChoiceSelected(word);

  /// 本题已答对并处于反馈驻留窗口。
  bool get correctRevealed => _answerState.correctRevealed;

  /// 记录本题评分，推进本地引擎，并异步提交同一题目的 FSRS 持久化请求。
  void rate(RecallRating rating) {
    final reviewedWord = currentWord;
    if (reviewedWord == null) return;

    _answerState.reset();
    _currentQuestionWrong = false;
    _ratingExecutor.rate(reviewedWord: reviewedWord, rating: rating);
    _done++;
    _reportSessionCompletedIfDone();
    _regenerateChoices();
    notifyListeners();
  }

  void revealAnswer() {
    _answerState.revealAnswer();
  }

  /// 保持“看答案后继续”沿用 good 评分推进正式复习的既有行为。
  void continueWithGoodRating() => rate(RecallRating.good);

  /// 「熟」：仅推进会话计数，**有意不提交 FSRS 评分**（产品语义，非遗漏）。
  ///
  /// 与 continueWithGoodRating（good→FSRS）区分：用户认为该词已掌握时跳过
  /// 复习队列即可，不改 stability/due。若未来拍板要记 FSRS，应映射 easy 并补测试。
  bool markAsKnown() {
    if (currentWord == null) return false;
    _answerState.reset();
    _currentQuestionWrong = false;
    _ratingExecutor.markAsKnown();
    _done++;
    _reportSessionCompletedIfDone();
    _regenerateChoices();
    notifyListeners();
    return true;
  }

  /// 队列走完时上报一次会话（会话数 + 答题词次与答对数）。
  ///
  /// 为什么放在这里而不是页面里：`_done`/`_total`/错题数都在本类，
  /// 页面再算一遍就会有两套口径。`currentWord == null` 之后 [rate] 会提前返回，
  /// 所以本方法在一次会话里只会命中一次。
  void _reportSessionCompletedIfDone() {
    if (_total <= 0 || _done < _total) return;
    final recorder = _usageStats;
    if (recorder == null) return;
    unawaited(recorder.recordStudySession());
    unawaited(recorder.recordAnswers(reviewed: _done, correct: (_done - _wrongCount).clamp(0, _done)));
  }

  void _regenerateChoices() {
    final current = currentWord;
    if (current == null) {
      _choices = const [];
      return;
    }

    _choices = _questionFactory.createChoices(currentWord: current, reviewWords: _engine.reviewList);
  }

  @override
  void dispose() {
    _answerState.dispose();
    super.dispose();
  }
}
