import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/app_preferences.dart';
import '../../../engine/core_engine.dart';
import '../../../engine/fsrs6_engine.dart';
import '../../../engine/leitner_engine.dart';
import '../../../features/learning/data/learning_progress_repository.dart';
import '../../../features/learning/data/learning_queue_repository.dart';
import '../../../features/learning/data/review_schedule_repository.dart';
import '../../../features/learning/domain/choice_generator.dart';
import '../../../models/bb_word_process.dart';
import '../../../models/book.dart';
import '../../../models/word.dart';

/// 遗留学习流程的专用会话状态。
///
/// 该状态拥有可变学习队列、Leitner 推进、当前索引、翻卡结果和四选一候选；词书与
/// 收藏词加载、FSRS 排程和进度持久化均经专用端口完成。它不处理账号、收藏切换、
/// 手动掌握或正式复习会话。
class LearningSessionState extends ChangeNotifier {
  LearningSessionState({
    required LearningQueueRepository queueRepository,
    required LearningProgressRepository progressRepository,
    required ReviewScheduleRepository reviewSchedule,
  }) : _queueRepository = queueRepository,
       _progressRepository = progressRepository,
       _reviewSchedule = reviewSchedule {
    unawaited(_loadProgress());
  }

  final LearningQueueRepository _queueRepository;
  final LearningProgressRepository _progressRepository;
  final ReviewScheduleRepository _reviewSchedule;
  final LeitnerCardEngine _leitnerEngine = LeitnerCardEngine();

  Book? _currentBook;
  List<Word> _queue = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  List<WordChoicePair> _choices = [];

  Book? get currentBook => _currentBook;
  List<Word> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  int get total => _queue.length;
  bool get hasMoreWords => _currentIndex < _queue.length - 1;
  (int current, int total) get progress => _queue.isEmpty ? (0, 0) : (_currentIndex + 1, _queue.length);
  bool get showAnswer => _showAnswer;
  List<WordChoicePair> get choices => _choices;
  int get learnedNum => _leitnerEngine.learnedNumber;

  Word? get currentWord => _queue.isEmpty ? null : _queue[_currentIndex.clamp(0, _queue.length - 1)];

  Future<void> loadFavorites({int limit = 50}) async {
    final favorites = await _queueRepository.loadFavoriteWords(currentQueue: _queue);
    if (favorites.isEmpty) return;

    _currentBook = null;
    _replaceQueue(favorites.take(limit).toList(growable: false));
  }

  Future<void> loadBook(Book book, {int? limit, bool shuffle = true}) async {
    _currentBook = book;
    // 使用每日学习目标作为默认限制
    final dailyGoal = UserPreferences().getDailyGoal();
    final actualLimit = limit ?? dailyGoal;
    final queue = await _queueRepository.loadBook(book, limit: actualLimit, shuffle: shuffle);
    _replaceQueue(queue);
    unawaited(_saveProgress());
  }

  void flip() {
    _showAnswer = !_showAnswer;
    notifyListeners();
  }

  /// 结束当前学习会话，但不触碰收藏、手动掌握、FSRS 排程或音频播放状态。
  void exitLearning() {
    _currentBook = null;
    _queue = [];
    _currentIndex = 0;
    _showAnswer = false;
    _choices = [];
    _leitnerEngine.init(const <BBWordProcess>[]);
    notifyListeners();
  }

  Future<void> rate(FsrsRating rating) async {
    final word = currentWord;
    if (word == null) return;

    switch (rating) {
      case FsrsRating.again:
        _leitnerEngine.iDontKnow();
      case FsrsRating.hard:
        _leitnerEngine.iMayKnow();
      case FsrsRating.good:
        _leitnerEngine.iReallyKnow();
      case FsrsRating.easy:
        _leitnerEngine.tooEasy();
    }

    await _reviewSchedule.rateWord(word: word.word, rating: rating);
    _currentIndex++;
    if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
    _regenerateChoices();
    notifyListeners();
  }

  void relearn() {
    final word = currentWord;
    if (word == null) return;

    _queue.removeAt(_currentIndex);
    _queue.insert(_currentIndex.clamp(0, _queue.length), word);
    unawaited(_reviewSchedule.forget(word.word));
    if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
    _regenerateChoices();
    notifyListeners();
  }

  void next() {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _showAnswer = false;
    }
    _regenerateChoices();
    notifyListeners();
  }

  void previous() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _showAnswer = false;
    }
    _regenerateChoices();
    notifyListeners();
  }

  void jumpTo(int index) {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _showAnswer = false;
    _regenerateChoices();
    notifyListeners();
    unawaited(_saveProgress());
  }

  Future<void> _loadProgress() async {
    try {
      final saved = await _progressRepository.load();
      if (saved != null) {
        _currentIndex = saved.currentIndex;
      }
    } catch (error) {
      debugPrint('Load progress error: $error');
    }
  }

  Future<void> _saveProgress() async {
    try {
      await _progressRepository.save(currentBook: _currentBook, currentIndex: _currentIndex, queue: _queue);
    } catch (error) {
      debugPrint('Save progress error: $error');
    }
  }

  void _replaceQueue(List<Word> queue) {
    _queue = queue;
    _currentIndex = 0;
    _showAnswer = false;
    _leitnerEngine.init(
      _queue
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
          .toList(growable: false),
    );
    _regenerateChoices();
    notifyListeners();
  }

  void _regenerateChoices() {
    final current = currentWord;
    if (current == null) {
      _choices = [];
      return;
    }

    _choices = ChoiceGenerator.generate(
      correct: ChoiceCandidate(word: current.word, interpret: current.interpret),
      candidates: _queue.map((word) => ChoiceCandidate(word: word.word, interpret: word.interpret)),
    ).map((choice) => WordChoicePair(choice.word, choice.interpret)).toList(growable: false);
  }
}
