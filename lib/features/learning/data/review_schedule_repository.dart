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
/// - SQLite 模式就绪且迁移标记已写 → **E2：清除旧 SP 回滚快照**（降级模式不删）；
/// - 不做双写（双写仍是全量重写，等于没解决性能问题）。
///
/// 该仓储不持有当前学习队列，也不推进任何会话引擎；调用方必须显式提供需筛选的
/// 词条或要评分的实际词条。
///
/// N5（有意设计，非缺陷）：本类 extends ChangeNotifier，且 learning providers 以
/// 具体类型 `ChangeNotifierProvider<ReviewScheduleRepository>` 暴露给 UI——评分后
/// 直接通知 FSRS 仪表盘重建。长期若拆只读 Reader 适配器，须保持 rateWord 通知链路。
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
      // H3：库写失败必须可观测；内存态保留会话推进，避免评分中断卡死 UI。
      try {
        await _store!.recordRating(card: card, dateKey: date, isLearn: isLearn);
      } catch (error, stack) {
        reportSwallowedError('FSRS rateWord persist (sqlite)', error, stack);
      }
    } else {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cardsPrefKey, jsonEncode(_cards.map((word, card) => MapEntry(word, card.toJson()))));
        await prefs.setString(dailyStatsPrefKey, jsonEncode(_dailyStats));
        await prefs.setStringList(activeDatesPrefKey, _activeDates.toList());
      } catch (error, stack) {
        reportSwallowedError('FSRS rateWord persist (sp)', error, stack);
      }
    }
    notifyListeners();
  }

  /// 移除一张卡片并持久化，供遗留学习会话的“重学”操作使用。
  Future<void> forget(String word) async {
    await initialize();
    if (_cards.remove(word) == null) return;
    if (_useSqlite && _store != null) {
      try {
        await _store!.deleteCard(word);
      } catch (error, stack) {
        reportSwallowedError('FSRS forget persist', error, stack);
      }
    } else {
      try {
        await _saveCards();
      } catch (error, stack) {
        reportSwallowedError('FSRS forget persist (sp)', error, stack);
      }
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
      // E2：SQLite 模式就绪后清除旧 SP 回滚快照（降级模式保留 SP，供重试/旧版）。
      await _clearLegacySpSnapshotIfMigrated();
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
      } catch (error, stack) {
        debugPrint('Review schedule loading error: $error');
        reportSwallowedError('ReviewScheduleSP degraded load', error, stack);
        _cards = {};
        _dailyStats = {};
        _activeDates = {};
      }
    }
    notifyListeners();
  }

  /// 首启迁移：marker 未写完时从 SP **单事务** 导入 cards+stats+dates。
  ///
  /// H1：不再以 `cardCount()>0` 提前 return——那会在 cards 成功、stats 失败后
  /// 永久跳过迁移。仅 `migratedMarkerKey==done` 视为完成；未完成则从 SP 重放
  /// （E2 清 SP 前置条件是 marker=done，故未完成时 SP 仍在）。
  Future<void> _migrateFromSpIfNeeded(ReviewScheduleStore store) async {
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

    // H1：三表单事务；失败整体回滚且不写标记 → 下次启动从 SP 重试。
    await store.migrateFromSp(cards: cards, dailyStats: dailyStats, activeDates: activeDates);

    if (skipped > 0) {
      reportSwallowedError(
        'FSRS migration skipped corrupt rows',
        StateError('$skipped corrupt entries skipped during SP->SQLite migration'),
        StackTrace.current,
      );
    }

    await prefs.setString(migratedMarkerKey, 'done');
  }

  /// H2：E2 清 SP 前把快照挪到应急备份 key（不清除），供库损坏时人工恢复。
  ///
  /// 恢复路径见 docs/fsrs_sqlite_migration_plan.md「E2 恢复」。
  static const emergencyBackupKey = 'fsrs6_emergency_backup_v1';

  Future<void> _clearLegacySpSnapshotIfMigrated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(migratedMarkerKey) != 'done') return;
      // H2：若尚无应急备份且 SP 仍有数据，先打包到 emergencyBackupKey。
      final cardsRaw = prefs.getString(cardsPrefKey);
      if ((prefs.getString(emergencyBackupKey) ?? '').isEmpty && cardsRaw != null && cardsRaw.isNotEmpty) {
        await prefs.setString(
          emergencyBackupKey,
          jsonEncode({
            'savedAt': DateTime.now().toIso8601String(),
            cardsPrefKey: cardsRaw,
            dailyStatsPrefKey: prefs.getString(dailyStatsPrefKey),
            activeDatesPrefKey: prefs.getStringList(activeDatesPrefKey),
          }),
        );
      }
      await prefs.remove(cardsPrefKey);
      await prefs.remove(dailyStatsPrefKey);
      await prefs.remove(activeDatesPrefKey);
    } catch (error, stack) {
      reportSwallowedError('FSRS E2 clear legacy SP snapshot', error, stack);
    }
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
