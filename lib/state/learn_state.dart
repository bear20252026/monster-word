// 学习状态 ViewModel — 学习队列、当前词、4选1逻辑
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/core_engine.dart' show WordChoicePair;
import '../engine/fsrs6_engine.dart' show Fsrs6Engine, FsrsCard, FsrsRating;
import '../engine/leitner_engine.dart';
import '../features/learning/domain/choice_generator.dart';
import '../models/bb_word_process.dart';
import '../models/book.dart';
import '../models/word.dart';
import '../repositories/fav_repository.dart';
import '../services/learn_service.dart';
import '../services/audio_service.dart';

/// 学习状态 ViewModel
///
/// 负责管理学习队列、当前单词、4选1选项生成。
/// 通过 LearnService 和 AudioService 访问业务逻辑。
class LearnState extends ChangeNotifier {
  final LearnService _learnService;
  final AudioService _audioService;
  final FavRepository? _favRepository;

  LearnState({required LearnService learnService, required AudioService audioService, FavRepository? favRepository})
    : _learnService = learnService,
      _audioService = audioService,
      _favRepository = favRepository;

  Book? _currentBook;
  List<Word> _queue = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  List<WordChoicePair> _choices = [];

  // ✅ 错误处理与加载状态
  bool _isLoading = false;
  String? _errorMessage;

  // Leitner 学习引擎（4选1选词）
  final LeitnerCardEngine _leitnerEngine = LeitnerCardEngine();
  List<BBWordProcess> _processQueue = [];

  // FSRS 记忆卡片跟踪
  final Fsrs6Engine _fsrsEngine = Fsrs6Engine();
  final Map<String, FsrsCard> _cards = {};

  // 学习进度持久化
  static const _currentBookPrefKey = 'current_book_v1';
  static const _currentIndexPrefKey = 'current_index_v1';
  static const _queueSnapshotPrefKey = 'queue_snapshot_v1';

  Book? get currentBook => _currentBook;
  List<Word> get queue => _queue;
  int get currentIndex => _currentIndex;
  int get total => _queue.length;
  bool get showAnswer => _showAnswer;
  List<WordChoicePair> get choices => _choices;

  // ✅ 错误处理与加载状态 getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  Word? get currentWord => _queue.isEmpty ? null : _queue[_currentIndex.clamp(0, _queue.length - 1)];

  int get learnedNum => _leitnerEngine.learnedNumber;

  bool get hasMoreWords => _currentIndex < _queue.length - 1;

  (int current, int total) get progress => (_currentIndex + 1, _queue.length);

  /// 初始化：加载上次学习进度
  Future<void> init() async {
    await _loadProgress();
  }

  /// 加载词书进入学习队列
  Future<void> loadBook(Book book, {int limit = 50, bool shuffle = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentBook = book;
      // ✅ 架构修复：通过 Service 层加载，不再直接访问 Database
      await _learnService.loadBook(book.id, limit: limit, shuffle: shuffle);
      _queue = _learnService.queue;
      _currentIndex = 0;
      _showAnswer = false;

      _initLeitnerEngine();
      _regenerateChoices();
      _saveProgress();
    } catch (e) {
      _errorMessage = '加载词书失败：$e';
      debugPrint('[LearnState] loadBook error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 清除错误状态
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 从收藏单词本开始学习
  Future<void> loadFavoritesForLearning({int limit = 50}) async {
    final favWords = await _learnService.getFavoriteWords();
    if (favWords.isEmpty) return;

    _currentBook = null;
    _queue = favWords.take(limit).map((w) => Word(word: w)).toList();
    _currentIndex = 0;
    _showAnswer = false;

    _initLeitnerEngine();
    _regenerateChoices();
    notifyListeners();
  }

  void _initLeitnerEngine() {
    _processQueue = _queue
        .map(
          (w) => BBWordProcess(
            word: w.word,
            wordId: w.id,
            interpret: w.interpret,
            usPron: w.usPron,
            ukPron: w.ukPron,
            example: w.example,
          ),
        )
        .toList();
    _leitnerEngine.init(_processQueue);
  }

  /// 翻卡片（显示答案）
  void flip() {
    _showAnswer = !_showAnswer;
    notifyListeners();
  }

  /// 重新生成 4 选 1 选项。
  ///
  /// 候选去重、中文释义优先与兜底策略由领域层统一维护，状态层仅负责
  /// 将当前会话模型适配为 UI 使用的 [WordChoicePair]。
  void _regenerateChoices() {
    // UI 展示的当前词来自队列索引；Leitner 引擎在初始化时会随机组内顺序，
    // 因此不能把引擎当前词作为正确答案，否则题干和候选正确项可能不一致。
    final current = currentWord;
    if (current == null) {
      _choices = [];
      return;
    }

    final generated = ChoiceGenerator.generate(
      correct: ChoiceCandidate(word: current.word, interpret: current.interpret),
      candidates: _queue.map((word) => ChoiceCandidate(word: word.word, interpret: word.interpret)),
    );
    _choices = generated.map((choice) => WordChoicePair(choice.word, choice.interpret)).toList();
  }

  /// 用户评分（SRS）
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

    _currentIndex++;
    if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
    _regenerateChoices();
    notifyListeners();
  }

  /// 重学：将当前单词重新插入队列
  void relearn() {
    final word = currentWord;
    if (word == null) return;

    _queue.removeAt(_currentIndex);
    final insertAt = _currentIndex.clamp(0, _queue.length);
    _queue.insert(insertAt, word);

    if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
    _regenerateChoices();
    notifyListeners();
  }

  /// 下一个单词
  void next() {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _showAnswer = false;
    }
    _regenerateChoices();
    notifyListeners();
  }

  /// 跳转到指定索引
  void jumpTo(int index) {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _showAnswer = false;
    _regenerateChoices();
    notifyListeners();
    _saveProgress();
  }

  /// 上一个单词
  void previous() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _showAnswer = false;
    }
    _regenerateChoices();
    notifyListeners();
  }

  /// 播放当前单词音频
  Future<void> playCurrentAudio() async {
    final word = currentWord;
    if (word == null) return;
    await _audioService.playWordAudio(word.word);
  }

  /// 退出学习
  void exitLearning() {
    _audioService.stop();
    // ✅ 修复：重置学习状态，防止返回黑屏
    _queue.clear();
    _currentIndex = 0;
    _showAnswer = false;
    _currentBook = null;
    _choices.clear();
    _processQueue.clear();
    _cards.clear();
    notifyListeners();
  }

  /// 检查单词是否已收藏
  bool isFavorite(String word) {
    if (_favRepository == null) return false;
    return _favRepository.isFavorite(word);
  }

  /// 切换收藏状态
  Future<void> toggleFavorite(String word) async {
    if (_favRepository == null) return;
    await _favRepository.toggleFavorite(word);
    notifyListeners();
  }

  /// 获取单词的 FSRS 记忆卡片
  FsrsCard? getCard(String word) => _cards[word];

  /// 检查单词是否已掌握
  bool isMastered(String word) {
    final card = _cards[word];
    return card != null && !card.isNew && card.stability > 7;
  }

  /// 切换单词掌握状态
  Future<void> toggleMastered(String word) async {
    final card = _cards[word];
    if (card != null) {
      _cards[word] = card.isNew
          ? _fsrsEngine.learn(word, FsrsRating.good)
          : FsrsCard(word: word, lastReview: DateTime.now(), dueDate: DateTime.now());
      notifyListeners();
    }
  }

  /// 获取记忆状态描述文本
  String getStatusText(FsrsCard card) => _fsrsEngine.getStatusText(card);

  /// 获取难度描述文本
  String getDifficultyText(FsrsCard card) => _fsrsEngine.getDifficultyText(card);

  /// 保存学习进度
  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentBook != null) {
        await prefs.setString(_currentBookPrefKey, _currentBook!.id.toString());
        await prefs.setInt(_currentIndexPrefKey, _currentIndex);
        final queueIds = _queue.map((w) => w.id).toList();
        await prefs.setString(_queueSnapshotPrefKey, jsonEncode(queueIds));
      }
    } catch (e) {
      debugPrint('Save progress error: $e');
    }
  }

  /// 加载上次学习进度
  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookId = prefs.getString(_currentBookPrefKey);
      if (bookId != null) {
        _currentIndex = prefs.getInt(_currentIndexPrefKey) ?? 0;
      }
    } catch (e) {
      debugPrint('Load progress error: $e');
    }
  }
}
