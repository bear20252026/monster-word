import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:word_app/core/engine/core_engine.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/core/engine/leitner_engine.dart';
import 'package:word_app/features/learning/application/choice_generator_port.dart';
import 'package:word_app/core/infrastructure/app_preferences.dart';
import 'package:word_app/features/learning/application/alphabet_spread_shuffle.dart';
import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/application/review_schedule_writer_port.dart';
import 'package:word_app/features/learning/domain/definition_formatter.dart';
import 'package:word_app/models/bb_word_process.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';

/// 遗留学习流程的专用会话状态。
///
/// 该状态拥有可变学习队列、Leitner 推进、当前索引、翻卡结果和四选一候选；词书与
/// 收藏词加载、FSRS 排程和进度持久化均经专用端口完成。它不处理账号、收藏切换、
/// 手动掌握或正式复习会话。
class LearningSessionState extends ChangeNotifier {
  LearningSessionState({
    required this._queuePort,
    required this._progressPort,
    required this._reviewSchedulePort,
    required this._choicePort,
    List<Word> Function(List<Word>)? shuffler,
  }) : _shuffler = shuffler ?? alphabetSpreadShuffle {
    unawaited(_loadProgress());
  }

  final LearningQueuePort _queuePort;
  final LearningProgressPort _progressPort;
  final List<Word> Function(List<Word>) _shuffler;
  final ReviewScheduleWriterPort _reviewSchedulePort;
  final ChoiceGeneratorPort _choicePort;
  final LeitnerCardEngine _leitnerEngine = LeitnerCardEngine();

  Book? _currentBook;
  List<Word> _queue = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  // 防止 rate() 异步 await 期间被连点二次进入，导致索引被双重推进而跳词/越界。
  bool _isRating = false;
  List<WordChoicePair> _choices = [];

  // 完成页总结数据
  final List<Word> _errorWords = [];
  int _totalAnswered = 0;

  /// 今日已学计数（跨会话持久化，跨天自动清零）——Learning 卡剩余联动
  int _todayLearned = 0;
  String _todayLearnedDate = '';
  int get todayLearned => _todayLearned;

  /// 每日学习目标（个），来自偏好设置
  int get dailyGoal => UserPreferences().getDailyGoal();

  /// 今日目标是否已达成（今日已学 >= 目标）——完成页庆祝横幅依据
  bool get dailyGoalAchieved => _todayLearned >= dailyGoal;

  Future<void> _loadTodayLearned() async {
    try {
      final prefs = AppPreferences();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      _todayLearnedDate = today;
      _todayLearned = prefs.getTodayLearned();
      final savedDate = prefs.getTodayLearnedDate();
      if (savedDate != today) _todayLearned = 0; // 跨天清零
    } catch (e, s) {
      reportSwallowedError('今日学习数恢复失败', e, s);
    }
  }

  Future<void> _incrementTodayLearned() async {
    _todayLearned++;
    try {
      await AppPreferences().setTodayLearned(_todayLearned, date: _todayLearnedDate);
    } catch (e, s) {
      reportSwallowedError('今日学习数写入失败', e, s);
    }
  }

  DateTime? _sessionStartTime;

  /// 队列代际计数：每当用户主动加载新的词库/收藏（`_replaceQueue`）时自增，
  /// 用于防止 `_loadProgress()` 异步返回的过期索引覆盖新会话的当前索引。
  int _queueGeneration = 0;

  Book? get currentBook => _currentBook;
  List<Word> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  int get total => _queue.length;
  bool get hasMoreWords => _currentIndex < _queue.length - 1;

  /// 是否有未保存的学习进度（已翻过至少 1 张卡且未完成全部）。
  /// 用于 SessionExitGuard 智能拦截：无进度时不打扰用户。
  bool get hasProgress => _queue.isNotEmpty && _currentIndex > 0 && _currentIndex < _queue.length;
  (int current, int total) get progress =>
      _queue.isEmpty ? (0, 0) : ((_currentIndex.clamp(0, _queue.length - 1)) + 1, _queue.length);
  bool get showAnswer => _showAnswer;
  List<WordChoicePair> get choices => _choices;
  int get learnedNum => _leitnerEngine.learnedNumber;

  /// 本次学习答错的单词列表（用于完成页回顾）
  List<Word> get errorWords => List.unmodifiable(_errorWords);

  /// 本次学习已答题数
  int get totalAnswered => _totalAnswered;

  /// 本次学习用时（秒），未开始为 null
  int? get sessionDurationSeconds =>
      _sessionStartTime == null ? null : DateTime.now().difference(_sessionStartTime!).inSeconds;

  /// 本次学习正确率（0.0 ~ 1.0），无答题记录为 null
  double? get accuracy => _totalAnswered == 0 ? null : (_totalAnswered - _errorWords.length) / _totalAnswered;

  Word? get currentWord => (_queue.isEmpty || _currentIndex >= _queue.length) ? null : _queue[_currentIndex];

  Future<void> loadFavorites({int limit = 50}) async {
    final favorites = await _queuePort.loadFavoriteWords(currentQueue: _queue);
    if (favorites.isEmpty) return;

    _currentBook = null;
    _replaceQueue(favorites.take(limit).toList(growable: false));
  }

  Future<void> loadBook(Book book, {int? limit, bool shuffle = true}) async {
    _currentBook = book;
    // 使用每日学习目标作为默认限制
    final queue = await _queuePort.loadBook(book, limit: limit, shuffle: shuffle);
    // shuffle=false（测试/确定场景）跳过字母分散洗牌
    _replaceQueue(queue, shuffle: shuffle);
    // 新会话开始，重置完成页数据
    _errorWords.clear();
    _totalAnswered = 0;
    _sessionStartTime = DateTime.now();
    // 尖叫币会话奖励每会话只结算一次；复习错题（relearn）不重置此标记
    _sessionRewardSettled = false;
    unawaited(_saveProgress());
  }

  /// 本会话尖叫币奖励是否已结算（防复习错题后二次完成页重复发币）
  bool _sessionRewardSettled = false;
  bool get sessionRewardSettled => _sessionRewardSettled;
  void markSessionRewardSettled() => _sessionRewardSettled = true;

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
    _errorWords.clear();
    _totalAnswered = 0;
    _sessionStartTime = null;
    notifyListeners();
  }

  Future<void> rate(FsrsRating rating) async {
    final word = currentWord;
    if (word == null) return;
    // 重入保护：rate() 在 await 评分间隙是异步的，快速连点会二次进入并重复推进索引。
    if (_isRating) return;
    _isRating = true;

    try {
      _totalAnswered++;
      unawaited(_incrementTodayLearned());
      switch (rating) {
        case FsrsRating.again:
          _leitnerEngine.iDontKnow();
          _errorWords.add(word); // 记录答错的词
        case FsrsRating.hard:
          _leitnerEngine.iMayKnow();
        case FsrsRating.good:
          _leitnerEngine.iReallyKnow();
        case FsrsRating.easy:
          _leitnerEngine.tooEasy();
      }

      await _reviewSchedulePort.rateWord(word: word.word, rating: rating);
      _currentIndex++;
      // 完成整个队列：让 currentWord 变为 null，触发学习完成界面，而不是永远停在最后一个词。
      if (_currentIndex > _queue.length) {
        _currentIndex = _queue.length;
      }
      _regenerateChoices();
      notifyListeners();
    } finally {
      _isRating = false;
    }
  }

  /// 从指定单词列表加载学习队列（用于错题复习）。
  void loadFromWords(List<Word> words, {Book? book}) {
    if (words.isEmpty) return;
    // 打乱顺序，避免按错误顺序重复
    final shuffled = List<Word>.from(words)..shuffle();
    _replaceQueue(shuffled);
    _errorWords.clear();
    _totalAnswered = 0;
    _sessionStartTime = DateTime.now();
    notifyListeners();
  }

  void relearn() {
    final word = currentWord;
    if (word == null) return;

    _queue.removeAt(_currentIndex);
    _queue.insert(_currentIndex.clamp(0, _queue.length), word);
    unawaited(_reviewSchedulePort.forget(word.word));
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
    await _loadTodayLearned();
    // 记录发起加载时的代际；若期间用户已加载新词库（代际改变），丢弃过期进度。
    final generation = _queueGeneration;
    try {
      final saved = await _progressPort.load();
      if (saved != null && generation == _queueGeneration) {
        _currentIndex = saved.currentIndex.clamp(0, _queue.length - 1);
      }
    } catch (error) {
      debugPrint('Load progress error: $error');
    }
  }

  Future<void> _saveProgress() async {
    try {
      if (_currentBook == null) return;
      await _progressPort.save(currentBook: _currentBook!, currentIndex: _currentIndex, queue: _queue);
    } catch (error) {
      debugPrint('Save progress error: $error');
    }
  }

  void _replaceQueue(List<Word> rawQueue, {bool shuffle = true}) {
    // 过滤无中文释义的空壳词：词库约 55% 词条缺 interpret（数据源如此），
    // 空词进队列会导致四选一残缺、详情页空白。宁少勿缺。
    final filtered = rawQueue
        .where((w) => DefinitionFormatter.extractChinese(w.interpret).isNotEmpty)
        .toList(growable: false);
    // 用户需求：单词顺序打乱，避免同一首字母连续出现
    final queue = shuffle ? _shuffler(filtered) : filtered;
    _queueGeneration++; // 新会话开始：作废任何进行中的旧进度加载
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

    final generated = _choicePort.generate(
      correct: ChoiceCandidate(word: current.word, interpret: current.interpret),
      candidates: _queue.map((word) => ChoiceCandidate(word: word.word, interpret: word.interpret)),
    );
    _choices = generated.map((c) => WordChoicePair(c.word, c.interpret)).toList(growable: false);
  }
}
