// 学习状态 ViewModel — 学习队列、当前词、4选1逻辑
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/wordbook_database.dart';
import '../engine/core_engine.dart' show WordChoicePair;
import '../engine/fsrs6_engine.dart' show Fsrs6Engine, FsrsCard, FsrsRating;
import '../engine/leitner_engine.dart';
import '../models/bb_word_process.dart';
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

  LearnState({
    required LearnService learnService,
    required AudioService audioService,
    FavRepository? favRepository,
  })  : _learnService = learnService,
        _audioService = audioService,
        _favRepository = favRepository;

  Book? _currentBook;
  List<Word> _queue = [];
  int _currentIndex = 0;
  bool _showAnswer = false;
  List<WordChoicePair> _choices = [];

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

  Word? get currentWord =>
      _queue.isEmpty ? null : _queue[_currentIndex.clamp(0, _queue.length - 1)];

  int get learnedNum => _leitnerEngine.learnedNumber;

  bool get hasMoreWords => _currentIndex < _queue.length - 1;

  (int current, int total) get progress => (_currentIndex + 1, _queue.length);

  /// 初始化：加载上次学习进度
  Future<void> init() async {
    await _loadProgress();
  }

  /// 加载词书进入学习队列
  Future<void> loadBook(Book book, {int limit = 50, bool shuffle = true}) async {
    _currentBook = book;
    _queue = await WordBookDatabase.instance
        .getWordsByBook(book.id, limit: limit, offset: 0);
    _currentIndex = 0;
    _showAnswer = false;

    if (shuffle) _queue.shuffle();

    _initLeitnerEngine();
    _regenerateChoices();
    notifyListeners();
    _saveProgress();
  }

  /// 从收藏单词本开始学习
  Future<void> loadFavoritesForLearning({int limit = 50}) async {
    final favWords = await _learnService.getFavoriteWords();
    if (favWords.isEmpty) return;

    _currentBook = null;
    _queue = favWords
        .take(limit)
        .map((w) => Word(word: w))
        .toList();
    _currentIndex = 0;
    _showAnswer = false;

    _initLeitnerEngine();
    _regenerateChoices();
    notifyListeners();
  }

  void _initLeitnerEngine() {
    _processQueue = _queue
        .map((w) => BBWordProcess(
              word: w.word,
              wordId: w.id,
              interpret: w.interpret,
              usPron: w.usPron,
              ukPron: w.ukPron,
              example: w.example,
            ))
        .toList();
    _leitnerEngine.init(_processQueue);
  }

  /// 翻卡片（显示答案）
  void flip() {
    _showAnswer = !_showAnswer;
    notifyListeners();
  }

  /// 重新生成 4 选 1 选项
  void _regenerateChoices() {
    final current = _leitnerEngine.currentWord();
    if (current == null) {
      _choices = [];
      return;
    }

    final correctInterpret = current.interpret;
    final correctWord = current.word;

    final seenInterprets = <String>{correctInterpret};
    final pool = <Map<String, String>>[];
    for (final w in _queue) {
      if (w.word != correctWord &&
          w.interpret.isNotEmpty &&
          !seenInterprets.contains(w.interpret)) {
        seenInterprets.add(w.interpret);
        final cn = _extractCn(w.interpret);
        pool.add({'word': w.word, 'interpret': w.interpret, 'cn': cn});
      }
    }

    pool.shuffle();
    final withCn = pool.where((w) => (w['cn'] ?? '').isNotEmpty).toList();
    final withoutCn = pool.where((w) => (w['cn'] ?? '').isEmpty).toList();

    final distractors = <Map<String, String>>[];
    for (final w in withCn) {
      if (distractors.length >= 3) break;
      distractors.add(w);
    }
    for (final w in withoutCn) {
      if (distractors.length >= 3) break;
      distractors.add(w);
    }

    final fallbacks = [
      {'word': '', 'interpret': '非标准用法', 'cn': '非标准用法'},
      {'word': '', 'interpret': '罕用释义', 'cn': '罕用释义'},
      {'word': '', 'interpret': '非正式表达', 'cn': '非正式表达'},
    ];
    int fb = 0;
    while (distractors.length < 3 && fb < fallbacks.length) {
      final fbInterpret = fallbacks[fb]['interpret']!;
      if (!seenInterprets.contains(fbInterpret)) {
        distractors.add(fallbacks[fb]);
        seenInterprets.add(fbInterpret);
      }
      fb++;
    }

    final choices = <WordChoicePair>[
      WordChoicePair(correctWord, correctInterpret),
      ...distractors.map(
          (d) => WordChoicePair(d['word'] ?? '', d['interpret'] ?? '')),
    ];
    _choices = choices.toList()..shuffle();
  }

  String _extractCn(String interpret) {
    try {
      final decoded = jsonDecode(interpret);
      if (decoded is List && decoded.isNotEmpty) {
        final first = decoded.first;
        if (first is Map) {
          final defList = first['def'];
          if (defList is List && defList.isNotEmpty) {
            final firstDef = defList.first;
            if (firstDef is Map) {
              return ((firstDef['cn'] ?? firstDef['cndef'] ?? '') as String)
                  .trim();
            }
          }
        }
      }
    } catch (_) {}
    return '';
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
          : FsrsCard(
              word: word,
              lastReview: DateTime.now(),
              dueDate: DateTime.now(),
            );
      notifyListeners();
    }
  }

  /// 获取记忆状态描述文本
  String getStatusText(FsrsCard card) => _fsrsEngine.getStatusText(card);

  /// 获取难度描述文本
  String getDifficultyText(FsrsCard card) =>
      _fsrsEngine.getDifficultyText(card);

  /// 保存学习进度
  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentBook != null) {
        await prefs.setString(
            _currentBookPrefKey, _currentBook!.id.toString());
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
