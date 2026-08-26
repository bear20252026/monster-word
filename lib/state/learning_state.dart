// 由账号4生成
// 学习状态管理：当前词书、学习队列、进度、SRS 评分、4选1选词
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/wordbook_database.dart';
import '../engine/core_engine.dart';
import '../engine/fsrs6_engine.dart';
import '../engine/leitner_engine.dart';
import '../features/learning/domain/choice_generator.dart';
import '../models/bb_word_process.dart';
import '../repositories/fav_repository.dart';
import '../repositories/mastered_repository.dart';

/// 学习状态（ChangeNotifier，供 UI 监听）
class LearningState extends ChangeNotifier {
  Book? _currentBook;
  List<Word> _queue = [];
  int _currentIndex = 0;
  bool _showAnswer = false;

  // FSRS-6 SRS 相关（升级自 FSRS-5，支持短时记忆模型和更精确的记忆预测）
  final Fsrs6Engine _fsrsEngine = Fsrs6Engine();
  Map<String, FsrsCard> _cards = {};
  static const _cardsPrefKey = 'fsrs6_cards_v1';

  // 单词收藏与掌握标记均委托给独立仓储。
  final FavRepository _favRepository;
  final MasteredRepository _masteredRepository;

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

  // 音频播放（学习页面的发音）
  StreamSubscription<void>? _audioSub;
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

  Word? get currentWord => _queue.isEmpty ? null : _queue[_currentIndex.clamp(0, _queue.length - 1)];

  // 学习进度持久化
  static const _currentBookPrefKey = 'current_book_v1';
  static const _currentIndexPrefKey = 'current_index_v1';
  static const _queueSnapshotPrefKey = 'queue_snapshot_v1';

  /// 保存当前学习进度
  Future<void> _saveProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentBook != null) {
        await prefs.setString(_currentBookPrefKey, _currentBook!.id.toString());
        await prefs.setInt(_currentIndexPrefKey, _currentIndex);
        // 保存队列快照（单词ID列表）
        final queueIds = _queue.map((w) => w.id).toList();
        await prefs.setString(_queueSnapshotPrefKey, jsonEncode(queueIds));
      }
    } catch (e) {
      debugPrint('Save progress error: $e');
    }
  }

  /// 加载上次的学习进度
  Future<void> _loadProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookId = prefs.getString(_currentBookPrefKey);
      if (bookId != null) {
        _currentIndex = prefs.getInt(_currentIndexPrefKey) ?? 0;
        final queueStr = prefs.getString(_queueSnapshotPrefKey);
        if (queueStr != null) {
          // 队列将在 loadBook 时重建，此处仅保存快照标记
        }
      }
    } catch (e) {
      debugPrint('Load progress error: $e');
    }
  }

  /// 构造函数：加载遗留持久化数据。
  ///
  /// 收藏和掌握标记分别由仓储负责加载和保存，因此不再在此重复维护。
  LearningState({required FavRepository favRepository, required MasteredRepository masteredRepository})
    : _favRepository = favRepository,
      _masteredRepository = masteredRepository {
    _loadCards();
    _loadDailyStats();
    _loadActiveDates();
    _loadDailyNewWords();
    _loadProgress();
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
        _cards = map.map((k, v) => MapEntry(k, FsrsCard.fromJson(v as Map<String, dynamic>)));
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
          return MapEntry(date, {'learn': m['learn'] as int? ?? 0, 'review': m['review'] as int? ?? 0});
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

  /// 单词是否已收藏。
  ///
  /// 收藏的唯一事实来源是 [FavRepository]，与新学习状态及学习服务保持一致。
  bool isFavorite(String word) => _favRepository.isFavorite(word);

  /// 单词是否已标记掌握。
  bool isMastered(String word) => _masteredRepository.isMastered(word);

  /// 切换收藏状态（返回切换后的状态）。
  Future<bool> toggleFavorite(String word) async {
    await _favRepository.toggleFavorite(word);
    notifyListeners();
    return _favRepository.isFavorite(word);
  }

  /// 切换已掌握状态（返回切换后的状态）。
  Future<bool> toggleMastered(String word) async {
    await _masteredRepository.toggleMastered(word);
    notifyListeners();
    return _masteredRepository.isMastered(word);
  }

  /// 获取收藏单词列表（从完整词库查询，不仅限当前队列）。
  Future<List<Word>> getFavoriteWords() async {
    final favoriteWords = await _favRepository.getFavoriteWords();
    if (favoriteWords.isEmpty) return [];
    // 从完整词库批量查询收藏的单词。
    final words = await WordBookDatabase.instance.getWordsByNames(favoriteWords);
    if (words.isNotEmpty) return words;
    // 回退：从当前队列过滤。
    return _queue.where((w) => favoriteWords.contains(w.word)).toList();
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
    _regenerateChoices();
    notifyListeners();
  }

  /// 获取已掌握单词列表。
  Future<List<Word>> getMasteredWords() async {
    final masteredWords = await _masteredRepository.getMasteredWords();
    return _queue.where((word) => masteredWords.contains(word.word)).toList();
  }

  /// 收藏单词数量。
  int get favoriteCount => _favRepository.favoriteCount;

  /// 已掌握单词数量。
  int get masteredCount => _masteredRepository.masteredCount;

  /// 加载一本书进入学习队列（乱序版：单词顺序随机打乱）
  Future<void> loadBook(Book book, {int limit = 50, bool shuffle = true}) async {
    _currentBook = book;
    _queue = await WordBookDatabase.instance.getWordsByBook(book.id, limit: limit, offset: 0);
    _currentIndex = 0;
    _showAnswer = false;

    // 乱序版：打乱单词顺序，避免每次都从 A 开始
    if (shuffle) {
      _queue.shuffle();
    }

    // 初始化 Leitner 引擎（4选1选词逻辑 1:1）
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
    _regenerateChoices();
    notifyListeners();
    _saveProgress();
  }

  /// 翻卡片（显示答案）
  void flip() {
    _showAnswer = !_showAnswer;
    notifyListeners();
  }

  /// 重新生成 4 选 1 选项。
  ///
  /// 旧状态仍承担词书、统计和持久化职责；候选去重、中文优先与兜底策略
  /// 则统一委托给学习领域规则，避免继续与 [LearnState] 漂移。
  void _regenerateChoices() {
    // 页面展示的当前词以队列索引为准；Leitner 引擎会随机组内顺序，
    // 不能把引擎当前词作为正确答案，否则题干和候选正确项可能不一致。
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

  /// 退出学习：清除当前学习状态，释放音频资源
  void exitLearning() {
    _audioSub?.cancel();
    _audioSub = null;
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
    final updated = isLearn ? _fsrsEngine.learn(word.word, rating) : _fsrsEngine.review(existing, rating);
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

  /// 已学数量（Leitner 引擎）
  int get learnedNum => _leitnerEngine.learnedNumber;

  // ========== FSRS-6 数据访问 ==========

  /// 获取当前单词的 FSRS 卡片
  FsrsCard? get currentCard {
    final word = currentWord;
    if (word == null) return null;
    return _cards[word.word];
  }

  /// 获取任意单词的 FSRS 卡片
  FsrsCard? getCard(String word) => _cards[word];

  /// 获取当前单词的记忆预测信息
  Map<String, dynamic>? get currentPrediction {
    final card = currentCard;
    if (card == null) return null;
    return _fsrsEngine.getPrediction(card);
  }

  /// 获取记忆统计（用于仪表盘）
  Map<String, int> get memoryStats {
    int newCount = 0, dueCount = 0, learningCount = 0, matureCount = 0;
    for (final card in _cards.values) {
      if (card.isNew) {
        newCount++;
      } else if (card.isDue) {
        dueCount++;
      } else if (card.stability < 7) {
        learningCount++;
      } else {
        matureCount++;
      }
    }
    return {'new': newCount, 'due': dueCount, 'learning': learningCount, 'mature': matureCount, 'total': _cards.length};
  }

  /// 获取今日学习统计
  Map<String, int> get todayStats {
    final stats = memoryStats;
    return {
      'learned': _queue.length - (stats['new'] ?? 0),
      'due': stats['due'] ?? 0,
      'total': stats['total'] ?? 0,
      'mature': stats['mature'] ?? 0,
    };
  }

  /// 获取所有到期需要复习的单词
  List<Word> get dueWords {
    return _queue.where((w) {
      final card = _cards[w.word];
      return card != null && !card.isNew && card.isDue;
    }).toList();
  }

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
  int get masteredNum => _masteredRepository.masteredCount;
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
