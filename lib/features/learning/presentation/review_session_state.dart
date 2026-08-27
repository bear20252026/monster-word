import 'package:flutter/foundation.dart';

import '../../../engine/core_engine.dart' show WordChoicePair;
import '../../../engine/fsrs6_engine.dart' show FsrsRating;
import '../../../engine/srs_engine.dart' show RecallRating;
import '../../../engine/super_memory_engine.dart';
import '../../../models/bb_word_process.dart';
import '../application/review_queue_reader.dart';
import '../application/review_rating_writer.dart';
import '../domain/choice_generator.dart';

/// 正式复习会话的展示状态。
///
/// 该状态仅负责 `/review` 的内存题目队列、候选项、作答推进和可观察进度。
/// 词源选择由 [ReviewQueueReader] 负责，FSRS 卡片、统计和持久化写入由
/// [ReviewRatingWriter] 负责；两者均不在此重复实现。
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

  bool _initialized = false;
  bool _showAnswer = false;
  List<WordChoicePair> _choices = const [];
  int _total = 0;
  int _done = 0;

  bool get initialized => _initialized;
  bool get showAnswer => _showAnswer;
  List<WordChoicePair> get choices => _choices;
  int get total => _total;
  int get done => _done;
  BBWordProcess? get currentWord => _engine.currentWord();

  void updateRatingWriter(ReviewRatingWriter ratingWriter) {
    _ratingWriter = ratingWriter;
  }

  /// 按既有正式复习队列优先级初始化本地会话。
  Future<void> initialize(ReviewQueueSnapshot snapshot) async {
    _initialized = false;
    _showAnswer = false;
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
      _initialized = true;
      _regenerateChoices();
    } catch (_) {
      _initialized = true;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// 记录本题评分，推进本地引擎，并异步提交同一题目的 FSRS 持久化请求。
  void rate(RecallRating rating) {
    final reviewedWord = currentWord;
    if (reviewedWord == null) return;

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

  /// 保留原“熟”操作的会话推进语义；该按钮当前不提交 FSRS 持久化评分。
  bool markAsKnown() {
    if (currentWord == null) return false;
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
}
