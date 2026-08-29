import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/models/word.dart';

/// 正式复习的 FSRS 调度与统计事实来源。
///
/// 保留既有 FSRS 持久化键，以兼容用户已有卡片与每日统计数据。
/// 该仓储不持有当前学习队列，也不推进任何会话引擎；调用方必须显式提供需筛选的
/// 词条或要评分的实际词条。
class ReviewScheduleRepository extends ChangeNotifier {
  static const cardsPrefKey = 'fsrs6_cards_v1';
  static const dailyStatsPrefKey = 'daily_stats_v1';
  static const activeDatesPrefKey = 'active_learn_dates_v1';

  final Fsrs6Engine _engine;
  Map<String, FsrsCard> _cards = {};
  Map<String, Map<String, int>> _dailyStats = {};
  Set<String> _activeDates = {};
  Future<void>? _initialization;

  ReviewScheduleRepository({Fsrs6Engine? engine}) : _engine = engine ?? Fsrs6Engine();

  Future<void> initialize() => _initialization ??= _load();

  bool get isInitialized => _initialization != null;
  int get dueCount => _engine.getDueCards(_cards.values.toList()).length;
  int get activeDateCount => _activeDates.length;

  /// 从今天向前连续有学习活动的天数。
  int get consecutiveDays {
    var count = 0;
    var date = DateTime.now();
    while (_activeDates.contains(_dateKey(date))) {
      count++;
      date = date.subtract(const Duration(days: 1));
    }
    return count;
  }

  int get todayLearnCount => _dailyStats[_todayKey()]?['learn'] ?? 0;
  int get todayReviewCount => _dailyStats[_todayKey()]?['review'] ?? 0;

  FsrsCard? cardFor(String word) => _cards[word];

  String getStatusText(FsrsCard card) => _engine.getStatusText(card);

  String getDifficultyText(FsrsCard card) => _engine.getDifficultyText(card);

  Map<String, int> get memoryStats {
    var newCount = 0;
    var dueCount = 0;
    var learningCount = 0;
    var matureCount = 0;
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

  Map<String, dynamic>? predictionFor(String word) {
    final card = cardFor(word);
    return card == null ? null : _engine.getPrediction(card);
  }

  List<Word> dueWordsFor(Iterable<Word> words) {
    return words
        .where((word) {
          final card = _cards[word.word];
          return card != null && !card.isNew && card.isDue;
        })
        .toList(growable: false);
  }

  Future<void> rateWord({required String word, required FsrsRating rating}) async {
    await initialize();
    final existing = _cards[word];
    final isLearn = existing == null;
    _cards[word] = isLearn ? _engine.learn(word, rating) : _engine.review(existing, rating);
    await _saveCards();
    await _recordActivity(isLearn: isLearn);
    notifyListeners();
  }

  /// 移除一张卡片并持久化，供遗留学习会话的“重学”操作使用。
  Future<void> forget(String word) async {
    await initialize();
    if (_cards.remove(word) == null) return;
    await _saveCards();
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cards = _readCards(prefs.getString(cardsPrefKey));
      _dailyStats = _readDailyStats(prefs.getString(dailyStatsPrefKey));
      _activeDates = (prefs.getStringList(activeDatesPrefKey) ?? const <String>[]).toSet();
    } catch (error) {
      debugPrint('Review schedule loading error: $error');
      _cards = {};
      _dailyStats = {};
      _activeDates = {};
    }
    notifyListeners();
  }

  Map<String, FsrsCard> _readCards(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((word, card) => MapEntry(word, FsrsCard.fromJson(card as Map<String, dynamic>)));
  }

  Map<String, Map<String, int>> _readDailyStats(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((date, counts) {
      final map = counts as Map<String, dynamic>;
      return MapEntry(date, {'learn': map['learn'] as int? ?? 0, 'review': map['review'] as int? ?? 0});
    });
  }

  Future<void> _saveCards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cardsPrefKey, jsonEncode(_cards.map((word, card) => MapEntry(word, card.toJson()))));
  }

  Future<void> _recordActivity({required bool isLearn}) async {
    final date = _todayKey();
    final counts = _dailyStats.putIfAbsent(date, () => {'learn': 0, 'review': 0});
    counts[isLearn ? 'learn' : 'review'] = (counts[isLearn ? 'learn' : 'review'] ?? 0) + 1;
    _activeDates.add(date);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(dailyStatsPrefKey, jsonEncode(_dailyStats));
    await prefs.setStringList(activeDatesPrefKey, _activeDates.toList());
  }

  String _todayKey() => _dateKey(DateTime.now());

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
