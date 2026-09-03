import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/models/word.dart';

import 'package:word_app/features/learning/data/review_schedule_store.dart';

/// 正式复习的 FSRS 调度与统计事实来源。
///
/// 批次 E（v2.7.56）起持久化层切换为独立 SQLite 库文件
/// review_schedule.db（见 [ReviewScheduleStore] 与
/// docs/fsrs_sqlite_migration_plan.md），写路径从"每次评分 3 次全量
/// jsonEncode 重写 SP blob"变为单事务 O(1)。
///
/// 迁移与降级策略（最保守路径）：
/// - 首启检测 SQLite 空且旧 SP key 非空 → 事务导入（损坏行跳过并上报）；
/// - 迁移任何一步失败 → 本机继续 SP 模式 + Sentry 上报，下次启动重试；
/// - 旧 SP key 保留为只读回滚快照（清理另列 E2 小批）；
/// - 不做双写（双写仍是全量重写，等于没解决性能问题）。
///
/// 该仓储不持有当前学习队列，也不推进任何会话引擎；调用方必须显式提供需筛选的
/// 词条或要评分的实际词条。
class ReviewScheduleRepository extends ChangeNotifier {
  static const cardsPrefKey = 'fsrs6_cards_v1';
  static const dailyStatsPrefKey = 'daily_stats_v1';
  static const activeDatesPrefKey = 'active_learn_dates_v1';
  static const migratedMarkerKey = 'fsrs6_migrated_v1';

  final Fsrs6Engine _engine;
  final ReviewScheduleStore? _injectedStore;
  ReviewScheduleStore? _store;
  Map<String, FsrsCard> _cards = {};
  Map<String, Map<String, int>> _dailyStats = {};
  Set<String> _activeDates = {};
  Future<void>? _initialization;
  bool _useSqlite = false;

  ReviewScheduleRepository({Fsrs6Engine? engine, ReviewScheduleStore? store})
    : _engine = engine ?? Fsrs6Engine(),
      _injectedStore = store;

  Future<void> initialize() => _initialization ??= _load();

  bool get isInitialized => _initialization != null;

  /// 当前是否运行在 SQLite 持久化模式（false = SP 降级模式）。
  /// 诊断与测试用。
  bool get usesSqlite => _useSqlite;

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
    final card = isLearn ? _engine.learn(word, rating) : _engine.review(existing, rating);
    _cards[word] = card;

    final date = _todayKey();
    final counts = _dailyStats.putIfAbsent(date, () => {'learn': 0, 'review': 0});
    counts[isLearn ? 'learn' : 'review'] = (counts[isLearn ? 'learn' : 'review'] ?? 0) + 1;
    _activeDates.add(date);

    if (_useSqlite && _store != null) {
      await _store!.recordRating(card: card, dateKey: date, isLearn: isLearn);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cardsPrefKey, jsonEncode(_cards.map((word, card) => MapEntry(word, card.toJson()))));
      await prefs.setString(dailyStatsPrefKey, jsonEncode(_dailyStats));
      await prefs.setStringList(activeDatesPrefKey, _activeDates.toList());
    }
    notifyListeners();
  }

  /// 移除一张卡片并持久化，供遗留学习会话的“重学”操作使用。
  Future<void> forget(String word) async {
    await initialize();
    if (_cards.remove(word) == null) return;
    if (_useSqlite && _store != null) {
      await _store!.deleteCard(word);
    } else {
      await _saveCards();
    }
    notifyListeners();
  }

  // ============================================================
  // 加载与迁移
  // ============================================================

  Future<void> _load() async {
    var sqliteReady = false;
    try {
      final store = _injectedStore ?? await ReviewScheduleStore.open();
      await _migrateFromSpIfNeeded(store);
      final cards = await store.loadCards();
      _cards = {for (final card in cards) card.word: card};
      _dailyStats = await store.loadDailyStats();
      _activeDates = await store.loadActiveDates();
      _store = store;
      _useSqlite = true;
      sqliteReady = true;
    } catch (error, stack) {
      debugPrint('Review schedule SQLite init error: $error');
      reportSwallowedError('ReviewScheduleSQLite init', error, stack);
    }
    if (!sqliteReady) {
      // 降级路径：旧 SP blob 模式（迁移失败或无 SQLite 环境的机器）。
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
    }
    notifyListeners();
  }

  /// 首启迁移：SQLite 空 且 未写过迁移标记 且 旧 SP 有数据 → 事务导入。
  ///
  /// - 损坏卡片行逐条跳过（debugPrint + 聚合上报），不中断整体迁移；
  /// - 卡片行数校验在事务提交前完成（不达标整体回滚）；
  /// - 全部成功才写 SP 迁移标记；任何异常向上抛出（调用方降级 SP 模式）。
  Future<void> _migrateFromSpIfNeeded(ReviewScheduleStore store) async {
    if (await store.cardCount() > 0) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(migratedMarkerKey) == 'done') return;

    final rawCards = prefs.getString(cardsPrefKey);
    if (rawCards == null || rawCards.isEmpty) {
      // 无历史数据可迁：直接写标记，避免每次启动空转检查。
      await prefs.setString(migratedMarkerKey, 'done');
      return;
    }

    // 逐行解析，损坏行跳过（学习记录不可再生产，能救一行是一行）。
    final decodedCards = jsonDecode(rawCards) as Map<String, dynamic>;
    final cards = <FsrsCard>[];
    var skipped = 0;
    for (final entry in decodedCards.entries) {
      try {
        cards.add(FsrsCard.fromJson(entry.value as Map<String, dynamic>));
      } catch (_) {
        skipped++;
        debugPrint('FSRS migration: skip corrupt card "${entry.key}"');
      }
    }

    final dailyStats = <String, Map<String, int>>{};
    final rawStats = prefs.getString(dailyStatsPrefKey);
    if (rawStats != null && rawStats.isNotEmpty) {
      final decodedStats = jsonDecode(rawStats) as Map<String, dynamic>;
      for (final entry in decodedStats.entries) {
        try {
          final map = entry.value as Map<String, dynamic>;
          dailyStats[entry.key] = {'learn': map['learn'] as int? ?? 0, 'review': map['review'] as int? ?? 0};
        } catch (_) {
          skipped++;
          debugPrint('FSRS migration: skip corrupt daily stat "${entry.key}"');
        }
      }
    }

    final activeDates = (prefs.getStringList(activeDatesPrefKey) ?? const <String>[]).toSet();

    // 提交前校验行数（见 store.insertCardsInTransaction），失败整体回滚。
    await store.insertCardsInTransaction(cards);
    await store.mergeDailyStatsInTransaction(dailyStats);
    await store.insertActiveDatesInTransaction(activeDates);

    if (skipped > 0) {
      reportSwallowedError(
        'FSRS migration skipped corrupt rows',
        StateError('$skipped corrupt entries skipped during SP->SQLite migration'),
        StackTrace.current,
      );
    }

    // 全部成功才写标记；失败路径不写标记 → 下次启动重试。
    await prefs.setString(migratedMarkerKey, 'done');
  }

  // ============================================================
  // 旧 SP blob 解析（降级模式专用）
  // ============================================================

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

  String _todayKey() => _dateKey(DateTime.now());

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
