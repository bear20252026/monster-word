import 'package:word_app/core/utils/calendar_days.dart';
import 'package:word_app/core/utils/debug_log.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/models/word.dart';

import 'package:word_app/features/learning/application/review_schedule_writer_port.dart'
    show FsrsRatingOutcome, FsrsRatingPersistException;
import 'package:word_app/features/learning/data/review_schedule_store.dart';

/// 正式复习的 FSRS 调度与统计事实来源。
///
/// 批次 E（v2.7.56）起持久化层切换为独立 SQLite 库文件
/// review_schedule.db（见 [ReviewScheduleStore] 与
/// 原 docs/fsrs_sqlite_migration_plan.md，文件已不存在），写路径从"每次评分 3 次全量
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
/// 评分持久化内部阶段信号（failed 由上层转 FsrsRatingPersistException）。
enum _PersistPhase { saved, pendingRetry, failed }

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

  // MW-03：按词互斥锁——同一单词的「读取→FSRS 计算→持久化→内存提交」
  // 全程串行；不同单词互不阻塞。并发同词评分按到达顺序依次完整执行。
  final Map<String, Future<void>> _wordLocks = <String, Future<void>>{};
  int _ratingSeq = 0;

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
  ///
  /// MW-59：先等 _writeGate 排空在途评分写，再关库；同时清空 _initialization
  /// 与 _writeGate——同实例 initialize→close→initialize 必须能重新加载，
  /// 不再进入「store 已关但 _initialization 仍完成态」的半关闭状态。
  Future<void> close() async {
    await _writeGate;
    final store = _store;
    _store = null;
    _initialization = null;
    _writeGate = Future<void>.value();
    _cards = {};
    _dailyStats = {};
    _activeDates = {};
    _initializedReset();
    await store?.close();
  }

  void _initializedReset() {
    _useSqlite = false;
    _counts = null;
    _fillingWords.clear();
    _wordLocks.clear();
  }

  /// MW-03：按词串行执行 [action]；同一 word 的调用按到达顺序链式执行。
  /// action 的异常直接向本次调用方传播，不污染后继。
  Future<T> _withWordLock<T>(String word, Future<T> Function() action) {
    final prev = _wordLocks[word] ?? Future<void>.value();
    final completer = Completer<void>();
    _wordLocks[word] = completer.future;
    return prev.then((_) => action()).whenComplete(() {
      if (identical(_wordLocks[word], completer.future)) {
        _wordLocks.remove(word);
      }
      completer.complete();
    });
  }

  String _nextRatingId(String word) {
    _ratingSeq++;
    return 'r${DateTime.now().microsecondsSinceEpoch}-$_ratingSeq-$word';
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
      // 日历日分量递减（DST 安全）：24h 绝对减法在夏令时切换日会跳日断计。
      date = calendarDayBefore(date);
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

  /// P1-02 Durable Command：先持久化成功，再提交内存并通知 UI。
  ///
  /// 返回 [FsrsRatingOutcome.saved]（已落库）或 [FsrsRatingOutcome.pendingRetry]
  /// （落库暂失败但评分意图已写入 SP 降级日志，恢复后幂等回放）；连降级日志
  /// 都写不进时抛 [FsrsRatingPersistException]（内存不提交，无假成功）。
  Future<FsrsRatingOutcome> rateWord({required String word, required FsrsRating rating}) {
    return _withWordLock(word, () => _rateWordLocked(word, rating));
  }

  Future<FsrsRatingOutcome> _rateWordLocked(String word, FsrsRating rating) async {
    await initialize();
    // MEM/F3：子集加载下 map 未命中不代表没学过——必须查库防「已学词被当新学」
    // 重置调度进度；同时保证计数增量的 before 口径正确。
    FsrsCard? prior = _cards[word];
    if (prior == null && _useSqlite && _store != null) {
      try {
        prior = await _store!.cardForWord(word);
      } catch (error, stack) {
        reportSwallowedError('FSRS rateWord cardForWord', error, stack);
      }
    }
    final isLearn = prior == null;
    final card = isLearn ? _engine.learn(word, rating) : _engine.review(prior, rating);
    final date = _todayKey();
    final ratingId = _nextRatingId(word);

    // ── 持久化阶段（durable first）──
    final persist = _writeGate.then((_) => _persistRating(word, rating, card, date, isLearn, ratingId));
    _writeGate = persist.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    final stored = await persist;
    if (stored == _PersistPhase.failed) {
      // 硬失败：内存不提交，调用方明确知道评分未落任何持久层。
      throw FsrsRatingPersistException('FSRS 评分持久化失败且降级日志不可写（word=$word）');
    }

    // ── 提交内存（仅在持久化成功或已安全入日志后）──
    _commitRatingToMemory(word, prior, card, date, isLearn);
    notifyListeners();
    return stored == _PersistPhase.saved ? FsrsRatingOutcome.saved : FsrsRatingOutcome.pendingRetry;
  }

  void _commitRatingToMemory(String word, FsrsCard? prior, FsrsCard card, String date, bool isLearn) {
    _cachePut(word, card);
    _applyCountsDelta(prior, card);
    final counts = _dailyStats.putIfAbsent(date, () => {'learn': 0, 'review': 0});
    counts[isLearn ? 'learn' : 'review'] = (counts[isLearn ? 'learn' : 'review'] ?? 0) + 1;
    _activeDates.add(date);
  }

  /// 持久化单次评分。SQLite 模式有界重试 1 次；仍失败或 SP 模式写失败时把
  /// 评分意图写入 SP 降级日志（P1-01），SQLite 恢复后幂等回放。
  Future<_PersistPhase> _persistRating(
    String word,
    FsrsRating rating,
    FsrsCard card,
    String date,
    bool isLearn,
    String ratingId,
  ) async {
    if (_useSqlite && _store != null) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          await _store!.recordRating(card: card, dateKey: date, isLearn: isLearn, ratingId: ratingId);
          return _PersistPhase.saved;
        } catch (error, stack) {
          reportSwallowedError('FSRS rateWord persist (sqlite, attempt ${attempt + 1})', error, stack);
        }
      }
      // 有界重试耗尽 → 降级日志兜底。
      final journaled = await _appendDegradedJournal(word, rating, date, ratingId, isLearn);
      return journaled ? _PersistPhase.pendingRetry : _PersistPhase.failed;
    }

    // ── SP 降级模式：日志先行（评分意图先落 SP），再写「前瞻 blob 快照」──
    // 快照临时并入本次评分（内存正式提交在上层），保证旧版装回时能从旧 key
    // 读到含本次评分的完整历史（回归契约：SP 降级评分仍写旧 key）。
    final journaled = await _appendDegradedJournal(word, rating, date, ratingId, isLearn);
    if (!journaled) {
      return _PersistPhase.failed;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final prospectiveCards = <String, FsrsCard>{};
      _cards.forEach((k, v) => prospectiveCards[k] = v);
      prospectiveCards[word] = card;
      final prospectiveStats = <String, Map<String, int>>{};
      _dailyStats.forEach((k, v) => prospectiveStats[k] = Map<String, int>.from(v));
      final dayCounts = prospectiveStats.putIfAbsent(date, () => {'learn': 0, 'review': 0});
      dayCounts[isLearn ? 'learn' : 'review'] = (dayCounts[isLearn ? 'learn' : 'review'] ?? 0) + 1;
      final prospectiveDates = Set<String>.from(_activeDates)..add(date);
      await prefs.setString(cardsPrefKey, jsonEncode(prospectiveCards.map((w, c) => MapEntry(w, c.toJson()))));
      await prefs.setString(dailyStatsPrefKey, jsonEncode(prospectiveStats));
      await prefs.setStringList(activeDatesPrefKey, prospectiveDates.toList());
      return _PersistPhase.saved;
    } catch (error, stack) {
      reportSwallowedError('FSRS rateWord persist (sp blob；日志已保底)', error, stack);
      return _PersistPhase.pendingRetry;
    }
  }

  /// 移除一张卡片并持久化，供遗留学习会话的“重学”操作使用。
  Future<void> forget(String word) {
    return _withWordLock(word, () => _forgetLocked(word));
  }

  Future<void> _forgetLocked(String word) async {
    await initialize();
    // MEM/F3：与 rateWord 同理——map 未命中须查库，防子集加载下漏删。
    FsrsCard? removed = _cards.remove(word);
    if (removed == null && _useSqlite && _store != null) {
      try {
        removed = await _store!.cardForWord(word);
      } catch (error, stack) {
        reportSwallowedError('FSRS forget cardForWord', error, stack);
      }
      if (removed == null) return;
    } else if (removed == null) {
      return;
    }
    _applyCountsDelta(removed, null);
    // MEM/C6 同款：forget 也走 _writeGate——SP 模式下与 rateWord 的全量
    // jsonEncode 交错会互相覆写（删掉的卡被评分写复活）；SQLite 模式下
    // deleteCard 与排队的 recordRating 无序执行同样能复活已删卡片。
    final persist = _writeGate.then((_) async {
      if (_useSqlite && _store != null) {
        await _store!.deleteCard(word);
      } else {
        await _saveCards();
      }
    });
    _writeGate = persist.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    try {
      await persist;
    } catch (error, stack) {
      // R2-11：持久化失败必须**回滚内存**。此前只上报并外抛，而内存里的卡
      // 已经删掉了 ⇒ DB 仍有卡、内存没有卡，两者分叉到下次启动才自愈；
      // 注释虽写「内存不提交语义与 rateWord 对齐」，但删除方向上并未实现。
      // 现在先恢复内存与计数再外抛：「调用方看到失败」与「内存/DB 一致」
      // 同时成立（卡被删前若已被移除，此处即还原为删除前状态）。
      _cards[word] = removed;
      _applyCountsDelta(null, removed);
      notifyListeners();
      reportSwallowedError('FSRS forget persist（内存已回滚）', error, stack);
      rethrow;
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
      // P1-01：SQLite 恢复后先回放降级期间的评分日志（幂等），再清旧快照——
      // 否则降级期新数据会被 marker=done 跳过迁移而静默消失（MW-22）。
      final replayed = await _replayDegradedJournal(store);
      // 审计 P1-03：回放写的是**库**，而上面的 `_counts` / `_cards` /
      // `_dailyStats` / `_activeDates` 是回放**之前**读的快照 ⇒ 不重读的话，
      // 本次启动全程看到的统计、到期集、连续天数都缺了刚回放的那批评分
      // （用户会觉得「昨天学的没算进去」），要等下次启动才自愈。
      // 只在真有写入时重读，避免无日志时白跑四次查询。
      if (replayed > 0) {
        final nowAfterReplay = DateTime.now();
        _counts = await store.loadCounts(nowAfterReplay);
        final dueAfterReplay = await store.loadDueCards(nowAfterReplay);
        _cards = {for (final card in dueAfterReplay) card.word: card};
        _dailyStats = await store.loadDailyStats();
        _activeDates = await store.loadActiveDates();
      }
      // E2：SQLite 模式就绪后清除旧 SP 回滚快照（降级模式保留 SP，供重试/旧版）。
      await _clearLegacySpSnapshotIfMigrated();
    } catch (error, stack) {
      debugLog('Review schedule SQLite init error: $error');
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
            debugLog('[FSRS] degraded load restored from $emergencyBackupKey');
          }
        }
        _cards = _readCards(cardsRaw);
        _dailyStats = _readDailyStats(statsRaw);
        _activeDates = (datesList ?? const <String>[]).toSet();
      } catch (error, stack) {
        debugLog('Review schedule loading error: $error');
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

    // 顶层 jsonDecode 先兑一层：SP blob 整体损坏时抛出会让每次启动重复失败并永久卡在 SP 降级模式
    //（降级路径同样解不动→空表→下一次评分用近空 map 覆写）。改为：记录为空迁入并写标记，
    // 原 blob 由 E2 应急备份保留（供人工恢复）——损坏数据本就不可读，不能拿它阻塞启动。
    Map<String, dynamic> decodedCards;
    try {
      decodedCards = jsonDecode(rawCards) as Map<String, dynamic>;
    } catch (error, stack) {
      reportSwallowedError('FSRS migration: SP cards blob corrupt; migrate as empty', error, stack);
      decodedCards = const <String, dynamic>{};
    }

    // 逐行解析，损坏行跳过（学习记录不可再生产，能救一行是一行）。
    final cards = <FsrsCard>[];
    var skipped = 0;
    for (final entry in decodedCards.entries) {
      try {
        cards.add(FsrsCard.fromJson(entry.value as Map<String, dynamic>));
      } catch (_) {
        // 吞错豁免: 逐行跳过损坏卡片，循环结束后按 skipped 聚合 reportSwallowedError
        skipped++;
        debugLog('FSRS migration: skip corrupt card "${entry.key}"');
      }
    }

    final dailyStats = <String, Map<String, int>>{};
    final rawStats = prefs.getString(dailyStatsPrefKey);
    if (rawStats != null && rawStats.isNotEmpty) {
      Map<String, dynamic> decodedStats;
      try {
        decodedStats = jsonDecode(rawStats) as Map<String, dynamic>;
      } catch (error, stack) {
        reportSwallowedError('FSRS migration: SP stats blob corrupt; skip', error, stack);
        decodedStats = const <String, dynamic>{};
      }
      for (final entry in decodedStats.entries) {
        try {
          final map = entry.value as Map<String, dynamic>;
          dailyStats[entry.key] = {'learn': map['learn'] as int? ?? 0, 'review': map['review'] as int? ?? 0};
        } catch (_) {
          // 吞错豁免: 同上——逐行跳过，循环后聚合上报
          skipped++;
          debugLog('FSRS migration: skip corrupt daily stat "${entry.key}"');
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
  /// 恢复路径：SP 快照回放（原 docs/fsrs_sqlite_migration_plan.md「E2 恢复」，文件已不存在）。
  static const emergencyBackupKey = 'fsrs6_emergency_backup_v1';

  /// P1-01：SQLite 故障降级期间的评分意图日志（SP StringList，逐条 JSON）。
  /// SQLite 恢复后按序幂等回放（fsrs_rating_log 主键去重），成功后清空。
  static const degradedJournalKey = 'fsrs6_degraded_journal_v1';
  static const int degradedJournalCap = 5000;

  /// 把一次评分意图追加进 SP 降级日志（P1-01）。
  /// 返回 false = 日志都写不进（磁盘满/SP 不可用）——上层按硬失败处理。
  Future<bool> _appendDegradedJournal(
    String word,
    FsrsRating rating,
    String date,
    String ratingId,
    bool isLearn,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final journal = prefs.getStringList(degradedJournalKey) ?? <String>[];
      journal.add(
        jsonEncode({
          'ratingId': ratingId,
          'word': word,
          'rating': rating.value,
          'date': date,
          'isLearn': isLearn,
          'savedAt': DateTime.now().toIso8601String(),
        }),
      );
      // 容量上限：极端积压时丢最旧（上报可见），保护 SP 体积。
      var kept = journal;
      if (kept.length > degradedJournalCap) {
        kept = kept.sublist(kept.length - degradedJournalCap);
        reportSwallowedError(
          'FSRS 降级日志超上限，丢弃最旧 ${journal.length - kept.length} 条',
          StateError('degraded journal overflow'),
          StackTrace.current,
        );
      }
      return await prefs.setStringList(degradedJournalKey, kept);
    } catch (error, stack) {
      reportSwallowedError('FSRS 降级日志写入失败（评分硬失败）', error, stack);
      return false;
    }
  }

  /// SQLite 恢复后回放降级日志：按序重算卡片并落库，fsrs_rating_log 主键
  /// 幂等去重（重复回放不会重复计数）；任一条失败保留整个日志下次重试。
  Future<int> _replayDegradedJournal(ReviewScheduleStore store) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final journal = prefs.getStringList(degradedJournalKey);
      if (journal == null || journal.isEmpty) return 0;
      var applied = 0;
      var duplicates = 0;
      for (final entry in journal) {
        try {
          final map = jsonDecode(entry) as Map<String, dynamic>;
          final word = map['word'] as String;
          final rating = FsrsRating.values[(map['rating'] as num).toInt() - 1];
          final dateKey = map['date'] as String;
          final ratingId = map['ratingId'] as String;
          final isLearn = (map['isLearn'] as bool?) ?? false;
          // 审计 P1-02：**必须按原答题时间重算**，不能用「回放当天」。
          // FSRS 的间隔由 elapsedDays（距 lastReview 的天数）决定 —— 若拿
          // DateTime.now() 当 reviewedAt，三天前那次评分会被当成「刚刚」，
          // 于是间隔被重新拉长/缩短，卡片到期日与用户实际学习历史脱节。
          // journal 里一直写着 `savedAt`（评分发生时刻），此前只用于排障，
          // 没喂给引擎。老条目可能没有该键 ⇒ 退回 dateKey 当日零点。
          final reviewedAt = _journalReviewedAt(map, dateKey);
          final prior = await store.cardForWord(word);
          final card = prior == null
              ? _engine.learn(word, rating, reviewedAt: reviewedAt)
              : _engine.review(prior, rating, reviewedAt: reviewedAt);
          final ok = await store.recordRating(
            card: card,
            dateKey: dateKey,
            isLearn: isLearn || prior == null,
            ratingId: ratingId,
          );
          if (ok) {
            applied++;
          } else {
            duplicates++;
          }
        } catch (error, stack) {
          reportSwallowedError('FSRS 降级日志回放单条失败（保留日志下次重试）', error, stack);
          return applied;
        }
      }
      await prefs.remove(degradedJournalKey);
      reportSwallowedError(
        'FSRS 降级日志回放完成（applied=$applied duplicate=$duplicates）',
        StateError('degraded journal replayed'),
        StackTrace.current,
      );
      return applied;
    } catch (error, stack) {
      reportSwallowedError('FSRS 降级日志回放读取失败（保留日志下次重试）', error, stack);
      return 0;
    }
  }

  /// 从 journal 条目取出**原答题时刻**（审计 P1-02）。
  ///
  /// 优先 `savedAt`（评分发生的那一刻，ISO 串）；老条目没有该键时退回
  /// `dateKey` 当日零点 —— 精度差一天，但方向正确（至少不把「三天前」
  /// 当成「刚刚」）。解析失败也退回 dateKey，绝不抛。
  DateTime? _journalReviewedAt(Map<String, dynamic> map, String dateKey) {
    final savedAt = map['savedAt'];
    if (savedAt is String) {
      final parsed = DateTime.tryParse(savedAt);
      if (parsed != null) return parsed;
    }
    return DateTime.tryParse(dateKey);
  }

  Future<void> _clearLegacySpSnapshotIfMigrated() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(migratedMarkerKey) != 'done') return;
      // H2：若尚无应急备份且 SP 仍有数据，先打包到 emergencyBackupKey。
      final cardsRaw = prefs.getString(cardsPrefKey);
      final hasBackup = (prefs.getString(emergencyBackupKey) ?? '').isNotEmpty;
      if (!hasBackup && cardsRaw != null && cardsRaw.isNotEmpty) {
        // 写返回 false（磁盘满等）不抛错：此时绝不能删主键——唯一可恢复
        // 快照还不存在，删了学习记录就永久丢失。留原键，下次启动重试打包。
        final saved = await prefs.setString(
          emergencyBackupKey,
          jsonEncode({
            'savedAt': DateTime.now().toIso8601String(),
            cardsPrefKey: cardsRaw,
            dailyStatsPrefKey: prefs.getString(dailyStatsPrefKey),
            activeDatesPrefKey: prefs.getStringList(activeDatesPrefKey),
          }),
        );
        if (!saved) {
          reportSwallowedError(
            'FSRS E2 emergency backup write returned false; keep legacy keys',
            StateError('setString($emergencyBackupKey) returned false'),
            StackTrace.current,
          );
          return;
        }
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

  /// 降级路径逐行解析：单行损坏只丢该行，不再整表清空
  ///（整表清空后任意评分会用近空 map 覆写 SP blob，把可救的行也葬掉）。
  Map<String, FsrsCard> _readCards(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (error, stack) {
      reportSwallowedError('FSRS degraded _readCards: blob corrupt', error, stack);
      return {};
    }
    final cards = <String, FsrsCard>{};
    for (final entry in decoded.entries) {
      try {
        cards[entry.key] = FsrsCard.fromJson(entry.value as Map<String, dynamic>);
      } catch (error, stack) {
        reportSwallowedError('FSRS degraded _readCards: skip corrupt "${entry.key}"', error, stack);
      }
    }
    return cards;
  }

  Map<String, Map<String, int>> _readDailyStats(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (error, stack) {
      reportSwallowedError('FSRS degraded _readDailyStats: blob corrupt', error, stack);
      return {};
    }
    final stats = <String, Map<String, int>>{};
    for (final entry in decoded.entries) {
      try {
        final map = entry.value as Map<String, dynamic>;
        stats[entry.key] = {'learn': map['learn'] as int? ?? 0, 'review': map['review'] as int? ?? 0};
      } catch (error, stack) {
        reportSwallowedError('FSRS degraded _readDailyStats: skip corrupt "${entry.key}"', error, stack);
      }
    }
    return stats;
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
