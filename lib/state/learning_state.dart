// 由账号4生成
// 学习状态管理：当前词书、学习队列、进度、SRS 评分、4选1选词
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/wordbook_database.dart';
import '../engine/core_engine.dart';
import '../engine/distractor_engine.dart';
import '../engine/leitner_engine.dart';
import '../engine/srs_engine.dart';
import '../models/bb_word_process.dart';

/// 学习状态（ChangeNotifier，供 UI 监听）
class LearningState extends ChangeNotifier {
  Book? _currentBook;
  List<Word> _queue = [];
  int _currentIndex = 0;
  bool _showAnswer = false;

  // SRS 相关
  final SrsEngine _srsEngine = SrsEngine();
  Map<String, SrsCard> _cards = {};
  static const _cardsPrefKey = 'srs_cards_v1';

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
  int get dueCount => _srsEngine.getDueCards(_cards.values.toList()).length;

  Word? get currentWord =>
      _queue.isEmpty ? null : _queue[_currentIndex.clamp(0, _queue.length - 1)];

  LearningState() {
    _loadCards();
  }

  /// 从 shared_preferences 加载 SRS 卡片
  Future<void> _loadCards() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cardsPrefKey);
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _cards = map.map(
          (k, v) => MapEntry(k, SrsCard.fromJson(v as Map<String, dynamic>)),
        );
      }
    } catch (_) {
      _cards = {};
    }
  }

  /// 保存 SRS 卡片到 shared_preferences
  Future<void> _saveCards() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _cards.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_cardsPrefKey, jsonEncode(map));
  }

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

  /// 重新生成 4 选 1 选项（使用 DistractorEngine：编辑距离+首字母+尾字母+词长+LCS）
  /// 保证始终有 4 个选项：1 正确 + 3 干扰
  void _regenerateChoices() {
    final current = _leitnerEngine.currentWord();
    if (current == null) { _choices = []; return; }

    final correctInterpret = current.interpret;
    // 构建候选池
    final pool = <Map<String, String>>[];
    for (final w in _queue) {
      if (w.word != current.word && w.interpret.isNotEmpty) {
        pool.add({'word': w.word, 'interpret': w.interpret});
      }
    }
    // 用 DistractorEngine 生成 3 个干扰项
    final distractors = DistractorEngine().quickGenerate(
      targetWord: current.word,
      targetInterpret: correctInterpret,
      pool: pool,
      count: 3,
    );
    // 组装 4 个选项并打乱
    final choices = <WordChoicePair>[
      WordChoicePair(current.word, correctInterpret),
      ...distractors.map((d) => WordChoicePair(d['word']!, d['interpret']!)),
    ];
    _choices = choices.toList()..shuffle();
  }

  /// 用户评分（SRS）：不认识/模糊/认识/熟练
  Future<void> rate(RecallRating rating) async {
    final word = currentWord;
    if (word == null) return;

    // Leitner 引擎联动（原版 iDontKnow/iMayKnow/iReallyKnow）
    switch (rating) {
      case RecallRating.again:
        _leitnerEngine.iDontKnow();
      case RecallRating.hard:
        _leitnerEngine.iMayKnow();
      case RecallRating.good:
        _leitnerEngine.iReallyKnow();
      case RecallRating.easy:
        _leitnerEngine.tooEasy();
    }

    // SRS 卡片更新
    final existing = _cards[word.word];
    final updated = existing == null
        ? _srsEngine.learn(word.word, rating)
        : _srsEngine.review(existing, rating);
    _cards[word.word] = updated;
    await _saveCards();

    // 移动到下一个（引擎当前词已推进）
    _currentIndex++;
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
}
