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
/// Score90：本类仍为 ChangeNotifier（评分后通知），但 **不再** 以
/// `Provider<ReviewScheduleRepository>` 暴露给 UI；展示侧统一经
/// `ReviewScheduleReader`（`RepositoryReviewScheduleReader` 监听本仓储）。
/// 评分写入经 `ReviewRatingWriter` 组合根注入。
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
  Future<void> _writeGate = Future<void>.value();

  // MEM/F3+异步化：SQLite 模式下 _cards 是【有界 LRU 缓存】而非全量事实来源——
  // 启动只装「到期子集」（复习关键路径 t0 正确），其余词经读穿填充/批量异步
  // 读取按需入缓存，超上限淘汰最久未用。
  // 计数（dueCount/memoryStats）始终来自 SQL 聚合并随评分增量维护，
  // 与缓存内容解耦。SP 降级模式 blob 全量载入，计数仍由 map 派生。
  FsrsCardCounts? _counts;
  final Map<String, Future<void>> _fillingWords = <String, Future<void>>{};

  /// 卡片缓存上限（LRU）：到期积压 + 会话工作集之上留足余量；
  /// 触顶后淘汰最久未访问项，常驻内存有界。
  static const int cardsCacheLimit = 4096;

  ReviewScheduleRepository({Fsrs6Engine? engine, ReviewScheduleStore? store})
    : _engine = engine ?? Fsrs6Engine(),
      _injectedStore = store;

  Future<void> initialize() => _initialization ??= _load();

  bool get isInitialized => _initialization != null;

  /// MEM：释放 SQLite 应用与句柄（由 DI disposeServiceLocator 调用）。
  Future<void> close() async {
    final store = _store;
    _store = null;
    _initializedReset();
    await store?.close();
  }

  void _initializedReset() {
    _useSqlite = false;
    _counts = null;
    _fillingWords.clear();
  }

  /// LRU 写入：重插到队尾，触顶淘汰最旧项。
  void _cachePut(String word, FsrsCard card) {
    _cards.remove(word);
    _cards[word] = card;
    while (_cards.length > cardsCacheLimit) {
      _cards.remove(_cards.keys.first);
    }
  }

  /// LRU 访问触碰（命中移到队尾）。
  void _cacheTouch(String word) {
    final card = _cards.remove(word);
    if (card != null) _cards[word] = card;
  }

  /// 当前缓存卡片数（诊断/测试用）。
  @visibleForTesting
  int get debugCacheSize => _cards.length;

  /// 当前是否运行在 SQLite 持久化模式（false = SP 降级模式）。
  /// 诊断与测试用。
  bool get usesSqlite => _useSqlite;

  /// MEM/F3：等待在途读穿填充（测试用）。
  @visibleForTesting
  Future<void> debugFlushFills() => Future.wait(_fillingWords.values.toList());

  int get dueCount => _counts?.due ?? _engine.getDueCards(_cards.values.toList()).length;
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

  FsrsCard? cardFor(String word) {
    final cached = _cards[word];
    if (cached != null) {
      _cacheTouch(word);
      return cached;
    }
    // MEM/异步化：LRU 缓存未命中（词确无卡或已被淘汰）→ 异步读穿填充。
    // 命中后 notifyListeners，同步调用方经监听链在下一帧拿到正确卡片。
    if (_useSqlite && _store != null && !_fillingWords.containsKey(word)) {
      unawaited(_fillCard(word));
    }
    return cached;
  }

  /// MEM/异步化：按词批量取卡（DB 直查 + LRU 预热），
  /// 供词表分类/详情页等异步读取面使用；不存在的词值为 null。
  Future<Map<String, FsrsCard?>> cardsForWords(Iterable<String> wordTexts) async {
    await initialize();
    final texts = wordTexts.toSet().toList();
    final result = <String, FsrsCard?>{for (final text in texts) text: _cards[text]};
    final store = _store;
    if (!_useSqlite || store == null) return result; // SP 模式：全量 map 即真相
    final missing = [
      for (final text in texts)
        if (!_cards.containsKey(text)) text,
    ];
    if (missing.isEmpty) return result;
    try {
      final fetched = await store.cardsForWords(missing);
      for (final entry in fetched.entries) {
        _cachePut(entry.key, entry.value);
        result[entry.key] = entry.value;
      }
    } catch (error, stack) {
      reportSwallowedError('FSRS cardsForWords', error, stack);
    }
    return result;
  }

  /// MEM/异步化：到期词过滤的 SQL 真相版（不依赖 LRU 缓存状态），保持入参顺序。
  Future<List<Word>> dueWordsForAsync(Iterable<Word> words) async {
    await initialize();
    final candidates = words.toList(growable: false);
    final store = _store;
    if (!_useSqlite || store == null) return dueWordsFor(candidates);
    try {
      final due = await store.dueWordTextsFor(candidates.map((w) => w.word).toList(), DateTime.now());
      return candidates.where((w) => due.contains(w.word)).toList(growable: false);
    } catch (error, stack) {
      reportSwallowedError('FSRS dueWordsForAsync', error, stack);
      return dueWordsFor(candidates);
    }
  }

  /// MEM/异步化：逐词读穿填充——单行索引查询，命中且缓存仍缺时入 LRU 并通知。
  Future<void> _fillCard(String word) {
    return _fillingWords.putIfAbsent(word, () => _fillCardInner(word));
  }

  Future<void> _fillCardInner(String word) async {
    try {
      final store = _store;
      if (store == null || !_useSqlite) return;
      final card = await store.cardForWord(word);
      if (card != null && !_cards.containsKey(word)) {
        _cachePut(word, card);
        notifyListeners();
      }
    } catch (error, stack) {
      reportSwallowedError('FSRS card read-through fill', error, stack);
    } finally {
      // remove 返回值即被移除的 Future 本身，非待等待任务
      unawaited(_fillingWords.remove(word));
    }
  }

  /// MEM/F3：评分/移除时按「前桶 → 后桶」增量维护 SQL 聚合计数。
  /// SP 模式（_counts == null）为空操作——getter 从全量 map 现算。
  void _applyCountsDelta(FsrsCard? before, FsrsCard? after) {
    final counts = _counts;
    if (counts == null) return;
    final from = _bucketOf(before);
    final to = _bucketOf(after);
    if (from == to) return;
    int dec(int v) => v - 1;
    int inc(int v) => v + 1;
    _counts = FsrsCardCounts(
      total: from == 'none' ? inc(counts.total) : (to == 'none' ? dec(counts.total) : counts.total),
      newCount: _bucketBump(counts.newCount, from, to, 'new'),
      due: _bucketBump(counts.due, from, to, 'due'),
      learning: _bucketBump(counts.learning, from, to, 'learning'),
      mature: _bucketBump(counts.mature, from, to, 'mature'),
    );
  }

  int _bucketBump(int value, String from, String to, String bucket) {
    if (from == bucket) return value - 1;
    if (to == bucket) return value + 1;
    return value;
  }

  String _bucketOf(FsrsCard? card) {
    if (card == null) return 'none';
    if (card.isNew) return 'new';
    if (card.isDue) return 'due';
    if (card.stability < 7) return 'learning';
    return 'mature';
  }

  String getStatusText(FsrsCard card) => _engine.getStatusText(card);

  String getDifficultyText(FsrsCard card) => _engine.getDifficultyText(card);

  Map<String, int> get memoryStats {
    final counts = _counts;
    if (counts != null) return counts.toStats();
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
    // MEM/F3：子集加载下 map 未命中不代表没学过——必须查库防「已学词被当新学」
    // 重置调度进度；同时保证计数增量的 before 口径正确。
    FsrsCard? prior = _cards[word];
    if (prior == null && _useSqlite && _store != null) {
      prior = await _store!.cardForWord(word);
    }
    final isLearn = prior == null;
    final card = isLearn ? _engine.learn(word, rating) : _engine.review(prior, rating);
    _cachePut(word, card);
    _applyCountsDelta(prior, card);

    final date = _todayKey();
    final counts = _dailyStats.putIfAbsent(date, () => {'learn': 0, 'review': 0});
    counts[isLearn ? 'learn' : 'review'] = (counts[isLearn ? 'learn' : 'review'] ?? 0) + 1;
    _activeDates.add(date);

    // MEM/C6：持久化写串行化，避免并发 rateWord 对同词/统计交错覆盖。
    final persist = _writeGate.then((_) async {
      if (_useSqlite && _store != null) {
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
    });
    _writeGate = persist.catchError((_) {});
    await persist;
    notifyListeners();
  }

  /// 移除一张卡片并持久化，供遗留学习会话的“重学”操作使用。
  Future<void> forget(String word) async {
    await initialize();
    // MEM/F3：与 rateWord 同理——map 未命中须查库，防子集加载下漏删。
    var removed = _cards.remove(word);
    if (removed == null && _useSqlite && _store != null) {
      removed = await _store!.cardForWord(word);
      if (removed == null) return;
    } else if (removed == null) {
      return;
    }
    _applyCountsDelta(removed, null);
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
      // MEM/F3+异步化：启动不再全表物化卡片——计数走 SQL 聚合，内存只装
      // 到期子集（LRU 有界）；其余词由 [cardFor] 读穿填充或 [cardsForWords]
      // 批量按需取库。
      final now = DateTime.now();
      _counts = await store.loadCounts(now);
      final dueCards = await store.loadDueCards(now);
      _cards = {for (final card in dueCards) card.word: card};
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
      // 降级路径：旧 SP blob 模式（迁移失败或无 SQLite 环境）。
      // R3：SP 活键为空时优先从 E2 应急备份恢复（fsrs6_emergency_backup_v1），
      // 避免「SQLite 损坏 + 已清 SP」导致学习记录在 UI 中不可见。
      _counts = null; // SP 模式全量 blob 进 map，计数由 getter 现算
      try {
        final prefs = await SharedPreferences.getInstance();
        var cardsRaw = prefs.getString(cardsPrefKey);
        var statsRaw = prefs.getString(dailyStatsPrefKey);
        var datesList = prefs.getStringList(activeDatesPrefKey);
        if (cardsRaw == null || cardsRaw.isEmpty) {
          final backup = prefs.getString(emergencyBackupKey);
          if (backup != null && backup.isNotEmpty) {
            final map = jsonDecode(backup) as Map<String, dynamic>;
            cardsRaw = map[cardsPrefKey] as String?;
            statsRaw = (map[dailyStatsPrefKey] as String?) ?? statsRaw;
            final dates = map[activeDatesPrefKey];
            if (dates is List) datesList = dates.cast<String>();
            debugPrint('[FSRS] degraded load restored from $emergencyBackupKey');
          }
        }
        _cards = _readCards(cardsRaw);
        _dailyStats = _readDailyStats(statsRaw);
        _activeDates = (datesList ?? const <String>[]).toSet();
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
