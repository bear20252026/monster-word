// 由账号4生成
// 学习状态管理：当前词书、学习队列、进度、SRS 评分、4选1选词
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/wordbook_database.dart';
import '../engine/core_engine.dart';
import '../engine/fsrs5_engine.dart';
import '../engine/leitner_engine.dart';
import '../models/bb_word_process.dart';

/// 学习状态（ChangeNotifier，供 UI 监听）
class LearningState extends ChangeNotifier {
  Book? _currentBook;
  List<Word> _queue = [];
  int _currentIndex = 0;
  bool _showAnswer = false;

  // FSRS-5 SRS 相关
  final Fsrs5Engine _fsrsEngine = Fsrs5Engine();
  Map<String, FsrsCard> _cards = {};
  static const _cardsPrefKey = 'fsrs5_cards_v1';

  // 收藏 & 标记已掌握
  final Set<String> _favoriteWords = {};
  final Set<String> _masteredWords = {};
  static const _favoritesPrefKey = 'favorite_words_v1';
  static const _masteredPrefKey = 'mastered_words_v1';

  // ========== 学习统计（每日计数 + 连续天数） ==========
  // 格式: { "2026-08-24": {"learn": 15, "review": 30}, ... }
  Map<String, Map<String, int>> _dailyStats = {};
  // 有学习活动的日期集合，用于计算连续天数
  Set<String> _activeDates = {};
  static const _dailyStatsPrefKey = 'daily_stats_v1';
  static const _activeDatesPrefKey = 'active_learn_dates_v1';

  // ========== 每日新学词数设置 ==========
  int _dailyNewWords = 10; // 默认 10 词/天
  static const _dailyNewWordsPrefKey = 'daily_new_words_v1';

  /// 每日新学词数（5/10/15/20/30/50）
  int get dailyNewWords => _dailyNewWords;

  /// 设置每日新学词数
  Future<void> setDailyNewWords(int value) async {
    if (value == _dailyNewWords) return;
    _dailyNewWords = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyNewWordsPrefKey, value);
  }

  // Leitner 学习引擎（4选1选词）
  final LeitnerCardEngine _leitnerEngine = LeitnerCardEngine();
  List<BBWordProcess> _processQueue = [];
  List<WordChoicePair> _choices = []; // 4 选 1 选项

  Book? get currentBook => _currentBook;
  List<Word> get queue => _queue;
  int get currentIndex => _currentIndex;
  int get total => _queue.length;
  bool get showAnswer => _showAnswer;

  /// 当前 4 选 1 选项
  List<WordChoicePair> get choices => _choices;

  /// 今日待复习数量
  int get dueCount => _fsrsEngine.getDueCards(_cards.values.toList()).length;

  Word? get currentWord =>
      _queue.isEmpty ? null : _queue[_currentIndex.clamp(0, _queue.length - 1)];

  LearningState() {
    _loadCards();
    _loadFavorites();
    _loadMastered();
    _loadDailyStats();
    _loadActiveDates();
    _loadDailyNewWords();
  }

  Future<void> _loadDailyNewWords() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_dailyNewWordsPrefKey);
      if (saved != null) {
        _dailyNewWords = saved;
        notifyListeners();
      }
    } catch (_) {
      // 数据损坏时使用默认值 10
    }
  }

  /// 从 shared_preferences 加载 FSRS-5 卡片
  Future<void> _loadCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cardsPrefKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _cards = map.map(
          (k, v) => MapEntry(k, FsrsCard.fromJson(v as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      debugPrint('FSRS-5 cards loading error: $e');
      _cards = {};
    }
  }

  /// 保存 FSRS-5 卡片到 shared_preferences
  Future<void> _saveCards() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _cards.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_cardsPrefKey, jsonEncode(map));
  }

  // ========== 收藏 & 标记已掌握 ==========

  /// 从 SharedPreferences 加载收藏列表
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_favoritesPrefKey);
      if (raw != null) _favoriteWords.addAll(raw);
    } catch (e) {
      debugPrint('Favorites loading error: $e');
    }
  }

  /// 从 SharedPreferences 加载已掌握列表
  Future<void> _loadMastered() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_masteredPrefKey);
      if (raw != null) _masteredWords.addAll(raw);
    } catch (e) {
      debugPrint('Mastered words loading error: $e');
    }
  }

  /// 保存收藏列表到 SharedPreferences
  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesPrefKey, _favoriteWords.toList());
  }

  /// 保存已掌握列表到 SharedPreferences
  Future<void> _saveMastered() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_masteredPrefKey, _masteredWords.toList());
  }

  // ========== 每日学习统计 + 连续天数 ==========

  /// 获取今天的日期字符串（YYYY-MM-DD）
  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 从 SharedPreferences 加载每日统计
  Future<void> _loadDailyStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_dailyStatsPrefKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _dailyStats = map.map((date, counts) {
          final m = counts as Map<String, dynamic>;
          return MapEntry(date, {
            'learn': m['learn'] as int? ?? 0,
            'review': m['review'] as int? ?? 0,
          });
        });
      }
    } catch (e) {
      debugPrint('Daily stats loading error: $e');
      _dailyStats = {};
    }
  }

  /// 保存每日统计到 SharedPreferences
  Future<void> _saveDailyStats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyStatsPrefKey, jsonEncode(_dailyStats));
  }

  /// 从 SharedPreferences 加载活跃日期集合
  Future<void> _loadActiveDates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_activeDatesPrefKey);
      if (raw != null) _activeDates = raw.toSet();
    } catch (e) {
      debugPrint('Active dates loading error: $e');
      _activeDates = {};
    }
  }

  /// 保存活跃日期集合到 SharedPreferences
  Future<void> _saveActiveDates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_activeDatesPrefKey, _activeDates.toList());
  }

  /// 记录一次学习活动（learn=true 为新学，learn=false 为复习）
  Future<void> _recordActivity({required bool isLearn}) async {
    final today = _todayStr();
    _dailyStats.putIfAbsent(today, () => {'learn': 0, 'review': 0});
    if (isLearn) {
      _dailyStats[today]!['learn'] = (_dailyStats[today]!['learn'] ?? 0) + 1;
    } else {
      _dailyStats[today]!['review'] = (_dailyStats[today]!['review'] ?? 0) + 1;
    }
    _activeDates.add(today);
    await _saveDailyStats();
    await _saveActiveDates();
  }

  // ========== 学习统计 Getter ==========

  /// 今日学习单词数（首次学习的新词）
  int get todayLearnCount {
    return _dailyStats[_todayStr()]?['learn'] ?? 0;
  }

  /// 今日复习单词数（已有 SRS 卡片的词）
  int get todayReviewCount {
    return _dailyStats[_todayStr()]?['review'] ?? 0;
  }

  /// 连续学习天数（从今天往回数，有学习活动的连续天数）
  int get consecutiveDays {
    if (_activeDates.isEmpty) return 0;
    int count = 0;
    var date = DateTime.now();
    while (true) {
      final ds = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      if (_activeDates.contains(ds)) {
        count++;
        date = date.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return count;
  }

  /// 单词是否已收藏
  bool isFavorite(String word) => _favoriteWords.contains(word);

  /// 单词是否已标记掌握
  bool isMastered(String word) => _masteredWords.contains(word);

  /// 切换收藏状态（返回切换后的状态）
  Future<bool> toggleFavorite(String word) async {
    if (_favoriteWords.contains(word)) {
      _favoriteWords.remove(word);
    } else {
      _favoriteWords.add(word);
    }
    await _saveFavorites();
    notifyListeners();
    return _favoriteWords.contains(word);
  }

  /// 切换已掌握状态（返回切换后的状态）
  Future<bool> toggleMastered(String word) async {
    if (_masteredWords.contains(word)) {
      _masteredWords.remove(word);
    } else {
      _masteredWords.add(word);
    }
    await _saveMastered();
    notifyListeners();
    return _masteredWords.contains(word);
  }

  /// 获取收藏单词列表（从完整词库查询，不仅限当前队列）
  Future<List<Word>> getFavoriteWords() async {
    if (_favoriteWords.isEmpty) return [];
    // 从完整词库批量查询收藏的单词
    final words = await WordBookDatabase.instance.getWordsByNames(_favoriteWords);
    if (words.isNotEmpty) return words;
    // 回退：从当前队列过滤
    return _queue.where((w) => _favoriteWords.contains(w.word)).toList();
  }

  /// 从收藏单词本开始学习
  Future<void> loadFavoritesForLearning({int limit = 50}) async {
    final favWords = await getFavoriteWords();
    if (favWords.isEmpty) return;

    _currentBook = null; // 非词书模式
    _queue = favWords.take(limit).toList();
    _currentIndex = 0;
    _showAnswer = false;

    // 初始化 Leitner 引擎
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
    _regenerateChoices();
    notifyListeners();
  }

  /// 获取已掌握单词列表
  Future<List<Word>> getMasteredWords() async {
    return _queue.where((w) => _masteredWords.contains(w.word)).toList();
  }

  /// 收藏单词数量
  int get favoriteCount => _favoriteWords.length;

  /// 已掌握单词数量
  int get masteredCount => _masteredWords.length;

  /// 加载一本书进入学习队列
  Future<void> loadBook(Book book, {int limit = 50}) async {
    _currentBook = book;
    _queue = await WordBookDatabase.instance
        .getWordsByBook(book.id, limit: limit, offset: 0);
    _currentIndex = 0;
    _showAnswer = false;

    // 初始化 Leitner 引擎（4选1选词逻辑 1:1）
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
    _regenerateChoices();
    notifyListeners();
  }

  /// 翻卡片（显示答案）
  void flip() {
    _showAnswer = !_showAnswer;
    notifyListeners();
  }

  /// 重新生成 4 选 1 选项（保证始终 4 个：1 正确 + 3 干扰）
  void _regenerateChoices() {
    final current = _leitnerEngine.currentWord();
    if (current == null) { _choices = []; return; }

    final correctInterpret = current.interpret;
    final correctWord = current.word;

    // 构建候选池（去重释义）
    final seenInterprets = <String>{correctInterpret};
    final pool = <Map<String, String>>[];
    for (final w in _queue) {
      if (w.word != correctWord && w.interpret.isNotEmpty && !seenInterprets.contains(w.interpret)) {
        seenInterprets.add(w.interpret);
        pool.add({'word': w.word, 'interpret': w.interpret});
      }
    }

    // 打乱候选池，取前 3 个不同释义
    pool.shuffle();
    final distractors = <Map<String, String>>[];
    for (final w in pool) {
      if (distractors.length >= 3) break;
      distractors.add(w);
    }

    // 如果不够 3 个，用占位释义补齐
    final fallbacks = [
      {'word': '', 'interpret': '非标准用法'},
      {'word': '', 'interpret': '罕用释义'},
      {'word': '', 'interpret': '非正式表达'},
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

    // 组装 4 个选项并打乱
    final choices = <WordChoicePair>[
      WordChoicePair(correctWord, correctInterpret),
      ...distractors.map((d) => WordChoicePair(d['word'] ?? '', d['interpret'] ?? '')),
    ];
    _choices = choices.toList()..shuffle();
  }

  /// 用户评分（SRS）：不认识/模糊/认识/熟练
  Future<void> rate(FsrsRating rating) async {
    final word = currentWord;
    if (word == null) return;

    // Leitner 引擎联动（原版 iDontKnow/iMayKnow/iReallyKnow）
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

    // SRS 卡片更新
    final existing = _cards[word.word];
    final isLearn = existing == null; // 新词=learn，已有卡片=review
    final updated = isLearn
        ? _fsrsEngine.learn(word.word, rating)
        : _fsrsEngine.review(existing, rating);
    _cards[word.word] = updated;
    await _saveCards();

    // 记录每日学习统计
    await _recordActivity(isLearn: isLearn);

    // 移动到下一个（引擎当前词已推进）
    _currentIndex++;
    if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
    _regenerateChoices();
    notifyListeners();
  }

  /// 重学：将当前单词重新插入队列（当前位置之后），稍后再次出现
  void relearn() {
    final word = currentWord;
    if (word == null) return;

    // 从当前位置移除
    _queue.removeAt(_currentIndex);
    // 插入到当前位置之后（保证很快再次出现）
    final insertAt = _currentIndex.clamp(0, _queue.length);
    _queue.insert(insertAt, word);

    // 重置 SRS 卡片，让该词回到初始学习状态
    _cards.remove(word.word);

    // 推进到下一个词
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

  /// 跳转到指定索引（供 PageView 翻页使用）
  void jumpTo(int index) {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _showAnswer = false;
    _regenerateChoices();
    notifyListeners();
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

  /// 已学数量（Leitner 引擎）
  int get learnedNum => _leitnerEngine.learnedNumber;

  // ========== 登录状态 ==========

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  Future<bool> login(String username, String password) async {
    // TODO: 调用 SignInWithCool API
    _isLoggedIn = true;
    notifyListeners();
    return true;
  }

  Future<bool> phoneLogin(String phone, String code) async {
    // TODO: 调用 PhoneLoginService API
    _isLoggedIn = true;
    notifyListeners();
    return true;
  }

  void logout() {
    _isLoggedIn = false;
    notifyListeners();
  }

  // ========== 引导页 ==========

  bool _hasShownInitGuide = false;
  bool get hasShownInitGuide => _hasShownInitGuide;

  Future<void> setHasShownInitGuide(bool value) async {
    _hasShownInitGuide = value;
    // TODO: 持久化到 SharedPreferences
  }

  // ========== 单词分类查询 ==========

  int get newWordNum => _queue.where((w) => !_cards.containsKey(w.word)).length;
  int get masteredNum => _masteredWords.length;
  int get notLearnedNum => _queue.length - learnedNum;
  int get reviewingNum => _fsrsEngine.getDueCards(_cards.values.toList()).length;
  int get totalLearnedDays => _activeDates.length;

  Future<List<Word>> getLearnedWords() async {
    // TODO: 从数据库查询已学单词
    return _queue.where((w) => _cards.containsKey(w.word)).toList();
  }

  Future<List<Word>> getNewWords() async {
    // TODO: 从数据库查询生词本
    return [];
  }

  Future<List<Word>> getMasteredWordsBySrs() async {
    return _queue.where((w) {
      final card = _cards[w.word];
      return card != null && card.difficulty > 5.0;
    }).toList();
  }

  Future<List<Word>> getNotLearnedWords() async {
    // TODO: 从数据库查询未学习单词
    return _queue.where((w) => !_cards.containsKey(w.word)).toList();
  }

  Future<List<Word>> getReviewingWords() async {
    // TODO: 从数据库查询复习中单词
    return _queue.where((w) {
      final card = _cards[w.word];
      return card != null && card.difficulty <= 5.0;
    }).toList();
  }

  Future<List<Word>> getWordsByBook(int bookId) async {
    // TODO: 从数据库查询指定词书的单词
    return await WordBookDatabase.instance.getWordsByBook(bookId, limit: 1000);
  }

}
