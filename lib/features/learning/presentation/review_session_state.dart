import 'package:flutter/foundation.dart';

import '../../../engine/core_engine.dart' show WordChoicePair;
import '../../../engine/fsrs6_engine.dart' show FsrsRating;
import '../../../engine/srs_engine.dart' show RecallRating;
import '../../../engine/super_memory_engine.dart';
import '../../../models/bb_word_process.dart';
import '../application/review_queue_reader.dart';
import '../application/review_rating_writer.dart';
import '../application/review_session_question_factory.dart';
import 'review_session_answer_state.dart';

/// 正式复习队列加载的当前阶段。
enum ReviewSessionLoadPhase { idle, loading, ready, failed }

/// 正式复习会话的展示状态。
///
/// 该状态负责 `/review` 的内存题目队列、加载阶段、候选项、答题反馈和会话
/// 进度。词源选择由 [ReviewQueueReader] 负责，FSRS 卡片、统计和持久化写入
/// 由 [ReviewRatingWriter] 负责；两者均不在此重复实现。
class ReviewSessionState extends ChangeNotifier {
  ReviewSessionState({
    required ReviewQueueReader queueReader,
    required ReviewRatingWriter ratingWriter,
    SuperMemoryEngine? engine,
    ReviewSessionQuestionFactory? questionFactory,
  }) : _queueReader = queueReader,
       _ratingWriter = ratingWriter,
       _engine = engine ?? SuperMemoryEngine(),
       _questionFactory = questionFactory ?? const ReviewSessionQuestionFactory();

  final ReviewQueueReader _queueReader;
  ReviewRatingWriter _ratingWriter;
  final SuperMemoryEngine _engine;
  final ReviewSessionQuestionFactory _questionFactory;

  ReviewSessionLoadPhase _loadPhase = ReviewSessionLoadPhase.idle;
  Object? _loadError;
  late final ReviewSessionAnswerState _answerState = ReviewSessionAnswerState(onChanged: notifyListeners);
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
  BBWordProcess? get currentWord => _engine.currentWord();

  void updateRatingWriter(ReviewRatingWriter ratingWriter) {
    _ratingWriter = ratingWriter;
  }

  /// 按既有正式复习队列优先级初始化本地会话。
  Future<void> initialize(ReviewQueueSnapshot snapshot) async {
    _answerState.reset();
    _loadPhase = ReviewSessionLoadPhase.loading;
    _loadError = null;
    _choices = const [];
    _total = 0;
    _done = 0;
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

    final selection = _answerState.selectChoice(selectedWord: selectedWord, correctWord: reviewedWord.word);
    if (selection == ReviewChoiceSelection.correct) {
      rate(RecallRating.good);
    }
  }

  bool isWrongChoiceSelected(String word) => _answerState.isWrongChoiceSelected(word);

  /// 记录本题评分，推进本地引擎，并异步提交同一题目的 FSRS 持久化请求。
  void rate(RecallRating rating) {
    final reviewedWord = currentWord;
    if (reviewedWord == null) return;

    _answerState.reset();
    switch (rating) {
      case RecallRating.again:
        _engine.iDontKnow();
      case RecallRating.hard:
        _engine.iMayKnow();
      case RecallRating.good:
        _engine.iReallyKnow();
      case RecallRating.easy:
        _engine.tooEasy();
    }
    final fsrsRating = switch (rating) {
      RecallRating.again => FsrsRating.again,
      RecallRating.hard => FsrsRating.hard,
      RecallRating.good => FsrsRating.good,
      RecallRating.easy => FsrsRating.easy,
    };
    _ratingWriter.rate(word: reviewedWord.word, rating: fsrsRating);
    _done++;
    _regenerateChoices();
    notifyListeners();
  }

  void revealAnswer() {
    _answerState.revealAnswer();
  }

  /// 保持“看答案后继续”沿用 good 评分推进正式复习的既有行为。
  void continueWithGoodRating() => rate(RecallRating.good);

  /// 保留原“熟”操作的会话推进语义；该按钮当前不提交 FSRS 持久化评分。
  bool markAsKnown() {
    if (currentWord == null) return false;
    _answerState.reset();
    _engine.iReallyKnow();
    _done++;
    _regenerateChoices();
    notifyListeners();
    return true;
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
