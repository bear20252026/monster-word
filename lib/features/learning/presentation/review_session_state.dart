import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../engine/core_engine.dart' show WordChoicePair;
import '../../../engine/fsrs6_engine.dart' show FsrsRating;
import '../../../engine/srs_engine.dart' show RecallRating;
import '../../../engine/super_memory_engine.dart';
import '../../../models/bb_word_process.dart';
import '../application/review_queue_reader.dart';
import '../application/review_rating_writer.dart';
import '../domain/choice_generator.dart';

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
  }) : _queueReader = queueReader,
       _ratingWriter = ratingWriter,
       _engine = engine ?? SuperMemoryEngine();

  final ReviewQueueReader _queueReader;
  ReviewRatingWriter _ratingWriter;
  final SuperMemoryEngine _engine;

  ReviewSessionLoadPhase _loadPhase = ReviewSessionLoadPhase.idle;
  Object? _loadError;
  bool _showAnswer = false;
  String? _wrongChoiceWord;
  Timer? _wrongChoiceTimer;
  List<WordChoicePair> _choices = const [];
  int _total = 0;
  int _done = 0;

  ReviewSessionLoadPhase get loadPhase => _loadPhase;
  bool get isLoading => _loadPhase == ReviewSessionLoadPhase.idle || _loadPhase == ReviewSessionLoadPhase.loading;
  bool get isReady => _loadPhase == ReviewSessionLoadPhase.ready;
  bool get hasLoadError => _loadPhase == ReviewSessionLoadPhase.failed;
  Object? get loadError => _loadError;
  bool get showAnswer => _showAnswer;
  String? get selectedWrongChoice => _wrongChoiceWord;
  List<WordChoicePair> get choices => _choices;
  int get total => _total;
  int get done => _done;
  BBWordProcess? get currentWord => _engine.currentWord();

  void updateRatingWriter(ReviewRatingWriter ratingWriter) {
    _ratingWriter = ratingWriter;
  }

  /// 按既有正式复习队列优先级初始化本地会话。
  Future<void> initialize(ReviewQueueSnapshot snapshot) async {
    _wrongChoiceTimer?.cancel();
    _loadPhase = ReviewSessionLoadPhase.loading;
    _loadError = null;
    _showAnswer = false;
    _wrongChoiceWord = null;
    _choices = const [];
    _total = 0;
    _done = 0;
    notifyListeners();

    try {
      final pool = await _queueReader.loadWords(snapshot);
      final processes = pool
          .map(
            (word) => BBWordProcess(
              word: word.word,
              wordId: word.id,
              interpret: word.interpret,
              usPron: word.usPron,
              ukPron: word.ukPron,
              example: word.example,
            ),
          )
          .toList();
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

    if (selectedWord == reviewedWord.word) {
      rate(RecallRating.good);
      return;
    }

    _wrongChoiceTimer?.cancel();
    _wrongChoiceWord = selectedWord;
    _wrongChoiceTimer = Timer(const Duration(milliseconds: 300), () {
      _wrongChoiceWord = null;
      notifyListeners();
    });
    notifyListeners();
  }

  bool isWrongChoiceSelected(String word) => _wrongChoiceWord == word;

  /// 记录本题评分，推进本地引擎，并异步提交同一题目的 FSRS 持久化请求。
  void rate(RecallRating rating) {
    final reviewedWord = currentWord;
    if (reviewedWord == null) return;

    _wrongChoiceTimer?.cancel();
    _wrongChoiceWord = null;
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
    _showAnswer = false;
    _regenerateChoices();
    notifyListeners();
  }

  void revealAnswer() {
    if (_showAnswer) return;
    _showAnswer = true;
    notifyListeners();
  }

  /// 保持“看答案后继续”沿用 good 评分推进正式复习的既有行为。
  void continueWithGoodRating() => rate(RecallRating.good);

  /// 保留原“熟”操作的会话推进语义；该按钮当前不提交 FSRS 持久化评分。
  bool markAsKnown() {
    if (currentWord == null) return false;
    _wrongChoiceTimer?.cancel();
    _wrongChoiceWord = null;
    _engine.iReallyKnow();
    _done++;
    _showAnswer = false;
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

    final choices = ChoiceGenerator.generate(
      correct: ChoiceCandidate(word: current.word, interpret: current.interpret),
      candidates: _engine.reviewList.map((word) => ChoiceCandidate(word: word.word, interpret: word.interpret)),
    );
    _choices = choices.map((choice) => WordChoicePair(choice.word, choice.interpret)).toList();
  }

  @override
  void dispose() {
    _wrongChoiceTimer?.cancel();
    super.dispose();
  }
}
