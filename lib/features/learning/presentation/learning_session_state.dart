import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:word_app/core/engine/core_engine.dart';
import 'package:word_app/core/utils/swallowed_error_report.dart';
import 'package:word_app/core/engine/fsrs6_engine.dart';
import 'package:word_app/core/engine/leitner_engine.dart';
import 'package:word_app/core/application/word_lookup_reader.dart';
import 'package:word_app/features/learning/application/choice_generator_port.dart';
import 'package:word_app/features/learning/application/extra_choice_pool.dart';
import 'package:word_app/core/application/presentation_prefs.dart';
import 'package:word_app/core/application/restore_cache_reset.dart';
import 'package:word_app/core/application/today_progress_store.dart';
import 'package:word_app/features/learning/application/alphabet_spread_shuffle.dart';
import 'package:word_app/features/learning/application/learning_progress_port.dart';
import 'package:word_app/features/learning/application/learning_queue_port.dart';
import 'package:word_app/features/learning/application/learning_rating_executor.dart';
import 'package:word_app/features/learning/application/learning_resume_planner.dart';
import 'package:word_app/features/learning/application/learning_reward_service.dart';
import 'package:word_app/features/learning/application/review_schedule_writer_port.dart';
import 'package:word_app/features/learning/application/session_completion_reporter.dart';
import 'package:word_app/features/learning/domain/definition_formatter.dart';
// M2：每日任务进度（跨 feature 只 import application 层，架构守卫 R4 允许）。
import 'package:word_app/features/missions/application/daily_mission_store.dart';
// 埋点端口（跨 feature 只 import 对方的 application 层，架构守卫 R4 允许）。
// 用窄接口 UsageStatsRecorder 而不是 UsageStatsCollector：本类只需要「记一笔」，
// 不需要上报调度/开关读写；测试传 null 即可（可选参数，既有测试不受影响）。
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';
import 'package:word_app/models/mw_word_process.dart';
import 'package:word_app/models/book.dart';
import 'package:word_app/models/word.dart';

/// 遗留学习流程的专用会话状态。
///
/// 该状态拥有可变学习队列、Leitner 推进、当前索引、翻卡结果和四选一候选；词书与
/// 收藏词加载、FSRS 排程和进度持久化均经专用端口完成。它不处理账号、收藏切换、
/// 手动掌握或正式复习会话。
class LearningSessionState extends ChangeNotifier {
  // 审计 I28：app 根 scope 状态仅应用销毁时 dispose，异步写路径在 await 后
  // 可能对已 dispose 的 notifier 调 notifyListeners（debug 断言崩溃）。
  // 统一在 notifyListeners 入口拦截，覆盖全部异步路径。
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  LearningSessionState({
    required this._queuePort,
    required this._progressPort,
    required this._reviewSchedulePort,
    required this._choicePort,
    required TodayProgressStore todayStore,
    required this._prefs,
    this._usageStats,
    this._dailyMissions,
    this._wordRepository,
    List<Word> Function(List<Word>)? shuffler,
  }) : _today = todayStore,
       _shuffler = shuffler ?? alphabetSpreadShuffle {
    _extraPool = ExtraChoicePool(_onExtraPoolReady, repository: _wordRepository);
    unawaited(_loadProgress());
    // 第四轮审计 M18（2026-11-17）：备份恢复后清会话（词对象来自旧库）。
    RestoreCacheResetBus.register(resetForRestore);
  }

  @override
  void dispose() {
    RestoreCacheResetBus.unregister(resetForRestore);
    _disposed = true;
    super.dispose();
  }

  // M4（2026-11-18）：本回调与复习侧逐行同构，但只是 ExtraChoicePool（已共享）
  // 就绪后的「再生+通知」投影，仅 2 行；抽共享需传入两个回调反增间接层，保留。
  void _onExtraPoolReady() {
    _regenerateChoices();
    notifyListeners();
  }

  final LearningQueuePort _queuePort;
  final LearningProgressPort _progressPort;
  final List<Word> Function(List<Word>) _shuffler;
  final ReviewScheduleWriterPort _reviewSchedulePort;
  final ChoiceGeneratorPort _choicePort;
  final TodayProgressStore _today;
  final PresentationPrefs _prefs;

  /// 词库只读端口（可选注入）：会话级随机取样真实词扩充干扰项候选池。
  /// 未注入（测试/未装配）时不扩充，选项宁少勿假。
  final WordLookupReader? _wordRepository;

  /// 结构修复步骤3：额外干扰词池编排下沉 application 共享（原两 State 同构）。
  late final ExtraChoicePool _extraPool;

  /// 使用统计埋点端口；未注入（测试/未装配）时为 null，全部埋点静默跳过。
  final UsageStatsRecorder? _usageStats;

  /// 每日任务（D1）进度端口；未注入时静默跳过。
  final DailyMissionStore? _dailyMissions;
  final LeitnerCardEngine _leitnerEngine = LeitnerCardEngine();

  /// 第四轮 M4：评分编排下沉 application（先落盘后推进引擎）。
  late final LearningRatingExecutor _ratingExecutor = LearningRatingExecutor(
    engine: _leitnerEngine,
    writerPort: _reviewSchedulePort,
  );

  /// 第四轮 M4：会话完成上报（会话数/答题词次/正确率任务）下沉 application 共享，
  /// 与复习侧 ReviewSessionState 共用同一报告器与幂等闸；学习侧独有的待结算
  /// 奖励登记仍留在 [_reportSessionCompleted]。
  late final SessionCompletionReporter _completionReporter = SessionCompletionReporter(
    usageStats: _usageStats,
    dailyMissions: _dailyMissions,
  );

  Book? _currentBook;
  List<Word> _queue = [];
  int _currentIndex = 0;

  // MW-27 断点②：启动恢复快照暂存区——构造时队列必然为空，原实现直接把
  // 恢复索引写 _currentIndex 会被随后的 loadBook/_replaceQueue 重置为 0，
  // 「继续上次学习」从未真正生效。现在：启动只加载快照到 pendingResume，
  // 用户加载同一本词书（bookId 匹配）时在队列就绪后应用恢复索引。
  LearningProgress? _pendingResume;
  @visibleForTesting
  LearningProgress? get debugPendingResume => _pendingResume;
  bool _showAnswer = false;
  // 防止 rate() 异步 await 期间被连点二次进入，导致索引被双重推进而跳词/越界。
  bool _isRating = false;
  List<WordChoicePair> _choices = [];

  // 完成页总结数据
  final List<Word> _errorWords = [];
  int _totalAnswered = 0;

  // 连击：连续首选答对计数（错一次即断；错后重选答对不续杯）。
  // 最佳连击进完成页总结＋战报海报。
  int _combo = 0;
  int _bestCombo = 0;
  int get combo => _combo;
  int get bestCombo => _bestCombo;

  /// 本题是否已点错过（用户反馈修复 2026-11-14：错后重选不续杯、答错入错词簿）。
  bool _currentWordWrong = false;
  int? _lastWrongWordId;

  /// 本题是否已点错过（详解页据此分流 again/good）。
  bool get currentWordWrong => _currentWordWrong;

  /// 记录一次选项作答（首选语义）：对→连击+1（本题点错过则不续杯），错→清零。
  void recordAnswer(bool correct) {
    if (correct) {
      if (!_currentWordWrong) {
        _combo++;
        if (_combo > _bestCombo) _bestCombo = _combo;
      }
    } else {
      _combo = 0;
      _currentWordWrong = true;
    }
    notifyListeners();
  }

  /// 学习页点错候选时登记：当前词入错词簿（去重），供完成页回顾与正确率口径。
  ///
  /// M4（2026-11-18）：与复习侧 _currentQuestionWrong 计数**有意不合并**——
  /// 学习侧要存错词对象列表（完成页回顾用）且按 word.id 跨题去重；复习侧只计数、
  /// 按题去重（无回顾列表）。两者「答对=没点错过」的正确率口径已对齐（见复习侧
  /// 注释），但数据形态不同，强行共享会抹掉错词簿。完成上报口径已经共享报告器统一。
  void noteChoiceWrong() {
    final word = currentWord;
    if (word == null || _lastWrongWordId == word.id) return;
    _lastWrongWordId = word.id;
    _errorWords.add(word);
    _currentWordWrong = true;
  }

  /// 今日已学计数（跨会话持久化，跨天自动清零）——Learning 卡剩余联动
  int _todayLearned = 0;
  String _todayLearnedDate = '';
  int get todayLearned => _todayLearned;

  /// 每日学习目标（个），来自偏好设置（经 application 门面，R-prefs）
  int get dailyGoal => _prefs.dailyGoal;

  /// 今日目标是否已达成（今日已学 >= 目标）——完成页庆祝横幅依据
  bool get dailyGoalAchieved => _todayLearned >= dailyGoal;

  Future<void> _loadTodayLearned() async {
    try {
      final prefs = _today;
      final today = DateTime.now().toIso8601String().substring(0, 10);
      _todayLearnedDate = today;
      _todayLearned = prefs.learned;
      final savedDate = prefs.todayLearnedDate;
      if (savedDate != today) _todayLearned = 0; // 跨天清零
    } catch (e, s) {
      reportSwallowedError('今日学习数恢复失败', e, s);
    }
  }

  Future<void> _incrementTodayLearned(String word) async {
    // ⚠️ 审计 P1-06（2026-10-17）：`_todayLearnedDate` 是**加载时**记下的日期，
    // 原先写入直接沿用它 ⇒ 应用跨午夜还开着时，今天的进度会被写到**昨天**的键上：
    // 用户看到的「今日已学」继续在昨天累加，今天的目标进度反而从 0 开始，
    // 次日启动时又被「跨天清零」抹掉。这里按**写入时刻**重新取日期，一变就归零。
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_todayLearnedDate != today) {
      _todayLearnedDate = today;
      _todayLearned = 0;
    }
    // 用户反馈修复（2026-11-14）：同一词当天只计一次（重答/复习不重复刷目标）。
    final words = _today.todayLearnedWords;
    if (words.contains(word)) return;
    words.add(word);
    unawaited(_today.setTodayLearnedWords(words));
    _todayLearned++;
    // 埋点：新学一个词。开关关闭时实现方空转，这里不需要自己判断。
    final recorder = _usageStats;
    if (recorder != null) unawaited(recorder.recordNewWordsLearned(1));
    // M2/D1：新学 10 词任务。今日已学口径与 TodayProgressStore 一致（只算新词）。
    final missions = _dailyMissions;
    if (missions != null) unawaited(missions.recordNewWordLearned());
    try {
      await _today.setTodayLearned(_todayLearned, date: _todayLearnedDate);
    } catch (e, s) {
      reportSwallowedError('今日学习数写入失败', e, s);
    }
  }

  /// 会话完成埋点：会话数 + 本会话答题词次与答对数。
  ///
  /// 答对数 = 总词次 − 错词数（与 [accuracy] 同口径，不另立一套算法）。
  /// 2026-10-17 审计 P2：会话完成时**先登记待结算**，不直接发币。
  ///
  /// 为什么不能在这里直接结算：`learning` 的 scope 在 `scare_coin` **外层**
  /// （app.dart 的链序 [4] 学习 → [9] 尖叫币，且 `app_structure_test.dart` 对
  /// 该顺序有断言），状态层读不到账本 `ScareCoinStore`。
  ///
  /// 登记走的是 SharedPreferences（不需要账本），于是「答完最后一题」这一刻
  /// 奖励意图就**落盘**了：之后哪怕完成页挂载失败、应用被杀，下次启动
  /// 由 [LearningRewardService.settlePendingSessions] 补发，不会静默丢。
  void _reportSessionCompleted() {
    // 幂等闸：走完队列与「今天到这儿」都可能触发，本局只上报一次（报告器内置）。
    if (_completionReporter.hasReported) return;
    // 第四轮 M4：会话数/答题词次/正确率任务下沉共享报告器（与复习侧同口径）。
    _completionReporter.report(answered: _totalAnswered, wrong: _errorWords.length);
    // 学习侧独有：待结算奖励登记（复习侧不发币）。learning scope 在 scare_coin
    // 外层读不到账本，故先落盘奖励意图，下次启动由 LearningRewardService 补发。
    unawaited(
      LearningRewardService.enqueuePendingSession(wordsLearned: _totalAnswered, dailyGoalAchieved: dailyGoalAchieved),
    );
  }

  DateTime? _sessionStartTime;

  /// 本局唯一标识（M3：学习 XP 的幂等事件键）。
  ///
  /// 每开一局重新生成（loadBook「再来一组」/收藏新局/错题复习都会重置）；
  /// 同一局内重复挂载完成页拿到的是同一个键 ⇒ XP 不会重复发。
  String _sessionId = _newSessionId();

  static String _newSessionId() => '${DateTime.now().microsecondsSinceEpoch}';

  /// 本局唯一标识（M3：XP 幂等事件键用）。
  String get sessionId => _sessionId;

  /// 队列代际计数：每当用户主动加载新的词库/收藏（`_replaceQueue`）时自增，
  /// 用于防止 `_loadProgress()` 异步返回的过期索引覆盖新会话的当前索引。

  Book? get currentBook => _currentBook;

  /// MEM-02：直接暴露内部列表只读视图，避免每次 get 复制整表。
  /// 调用方不得 mutate；会话内部修改仍走 setState/notifyListeners。
  // 审计 B6（2026-11-15）：Reader 契约只读快照，返回不可变视图防跨域消费方 mutate 会话队列。
  List<Word> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  int get total => _queue.length;
  bool get hasMoreWords => _currentIndex < _queue.length - 1;

  /// 本局还差多少个词没答（退出确认框用它说明后果，不改完成判定）。
  int get remainingWords => _queue.isEmpty ? 0 : (_queue.length - _currentIndex).clamp(0, _queue.length);

  /// M4 中途收工检查点：答满这个词数后给一次「继续 / 今天到这儿」的选择。
  static const int midSessionCheckpointWords = 5;

  /// 本局是否已给过中途收工提示（每局只提示一次）。
  bool _midSessionPromptShown = false;

  /// 是否该显示中途收工提示：答满检查点、且本局还有词没答。
  /// 提示非阻塞（页面画一条可关闭的轻量提示条），点「继续」即收起。
  bool get shouldOfferMidSessionBreak =>
      !_midSessionPromptShown && _totalAnswered >= midSessionCheckpointWords && _currentIndex < _queue.length;

  /// 收起中途收工提示（本局不再出现）。
  void markMidSessionPromptShown() {
    if (_midSessionPromptShown) return;
    _midSessionPromptShown = true;
    notifyListeners();
  }

  /// M4「今天到这儿」：不等走完队列，按本局已答数据直接进完成页。
  ///
  /// 会话统计/奖励只结算一次（见 [_reportSessionCompleted] 的幂等闸）；
  /// 退出本身不扣币、不扣连胜。
  void finishSessionEarly() {
    if (_queue.isEmpty || _currentIndex >= _queue.length) return;
    _currentIndex = _queue.length;
    _showAnswer = false;
    _midSessionPromptShown = true;
    _reportSessionCompleted();
    notifyListeners();
    unawaited(_saveProgress());
  }

  /// 是否有未保存的学习进度（已翻过至少 1 张卡且未完成全部）。
  /// 用于 SessionExitGuard 智能拦截：无进度时不打扰用户。
  bool get hasProgress => _queue.isNotEmpty && _currentIndex > 0 && _currentIndex < _queue.length;
  (int current, int total) get progress =>
      _queue.isEmpty ? (0, 0) : ((_currentIndex.clamp(0, _queue.length - 1)) + 1, _queue.length);
  bool get showAnswer => _showAnswer;
  List<WordChoicePair> get choices => _choices;
  int get learnedNum => _leitnerEngine.learnedNumber;

  /// 本次学习答错的单词列表（用于完成页回顾）
  List<Word> get errorWords => List.unmodifiable(_errorWords);

  /// 本次学习已答题数
  int get totalAnswered => _totalAnswered;

  /// 本次学习用时（秒），未开始为 null
  int? get sessionDurationSeconds =>
      _sessionStartTime == null ? null : DateTime.now().difference(_sessionStartTime!).inSeconds;

  /// 本次学习正确率（0.0 ~ 1.0），无答题记录为 null
  double? get accuracy => _totalAnswered == 0 ? null : (_totalAnswered - _errorWords.length) / _totalAnswered;

  Word? get currentWord => (_queue.isEmpty || _currentIndex >= _queue.length) ? null : _queue[_currentIndex];

  Future<void> loadFavorites({int limit = 50}) async {
    // 审计 I87：收藏复习会话漏斗
    unawaited(Sentry.addBreadcrumb(Breadcrumb(message: '学习会话加载收藏复习', category: 'learning')));
    final favorites = await _queuePort.loadFavoriteWords(currentQueue: _queue);
    if (favorites.isEmpty) return;

    _currentBook = null;
    _replaceQueue(favorites.take(limit).toList(growable: false));
    // 用户反馈修复（2026-11-14）：收藏局是新的一局，清上局错词/正确率/连击/
    // 发币标记，避免沿用上一局统计与漏发本局奖励。
    _resetSessionProgress();
  }

  Future<void> loadBook(Book book, {int? limit, bool shuffle = true}) async {
    // 审计 I87：Sentry breadcrumb——词书切换漏斗（未启用 DSN 时为 no-op）
    unawaited(Sentry.addBreadcrumb(Breadcrumb(message: '学习会话切换词书: ${book.name}', category: 'learning')));
    _currentBook = book;
    // 使用每日学习目标作为默认限制
    final queue = await _queuePort.loadBook(book, limit: limit, shuffle: shuffle);
    // shuffle=false（测试/确定场景）跳过字母分散洗牌
    _replaceQueue(queue, shuffle: shuffle);
    // MW-27 断点②闭合：同书恢复。决策已下沉 application 纯函数（步骤3b）：
    // 按词身份反查（R2-06 禁止复用旧数字 index）；快照词不在新抽样时按快照
    // 队列原序重建。此处只应用计划并通知。
    final resume = _pendingResume;
    if (resume != null) {
      final plan = planLearningResume(resume: resume, book: book, newQueue: _queue);
      switch (plan) {
        case LearningResumeAtIndex(:final index):
          _currentIndex = index;
          _regenerateChoices();
        case LearningResumeRebuild(:final queue, :final index):
          _replaceQueue(queue, shuffle: false);
          if (_queue.isNotEmpty) {
            // 第三轮 T29：planner 的 index 钳到快照队列长度，但 _replaceQueue
            // 会再过滤空壳词——旧版未过滤快照升级时队列可缩短，须对**过滤后**
            // 长度二次钳制，否则 index 越界 → currentWord=null 假完成。
            _currentIndex = index.clamp(0, _queue.length - 1);
            _regenerateChoices();
          }
        case LearningResumeNone():
          break;
      }
      // 快照一次性消费（无论是否应用）——旧书快照不应在新会话再次生效。
      _pendingResume = null;
      notifyListeners();
    }
    // 新会话开始，重置完成页数据
    _resetSessionProgress();
    unawaited(_saveProgress());
  }

  /// 结算页「再来一组」：沿用同一词书（收藏会话则重载收藏）开新的一局。
  ///
  /// 返回是否真的装载了新词；装载失败（如收藏为空）时什么都不清，
  /// 调用方的结算页保持原数据，不会闪成 0。
  Future<bool> startAnotherGroup() async {
    final book = _currentBook;
    if (book != null) {
      await loadBook(book);
      return currentWord != null;
    }
    await loadFavorites();
    if (currentWord == null) return false;
    // loadFavorites 历史上不重置本局统计；「再来一组」是新的一局，需要清账。
    _resetSessionProgress();
    notifyListeners();
    return true;
  }

  /// 本局统计与发币标记归零（loadBook / 收藏会话开新局共用）。
  /// 尖叫币会话奖励每会话只结算一次；复习错题（relearn）不重置此标记。
  void _resetSessionProgress() {
    _errorWords.clear();
    _totalAnswered = 0;
    _combo = 0;
    _bestCombo = 0;
    _sessionStartTime = DateTime.now();
    _sessionId = _newSessionId();
    _sessionRewardSettled = false;
    _midSessionPromptShown = false;
    _completionReporter.reset();
  }

  /// 本会话尖叫币奖励是否已结算（防复习错题后二次完成页重复发币）
  bool _sessionRewardSettled = false;
  bool get sessionRewardSettled => _sessionRewardSettled;
  void markSessionRewardSettled() => _sessionRewardSettled = true;

  void flip() {
    _showAnswer = !_showAnswer;
    notifyListeners();
  }

  /// 结束当前学习会话，但不触碰收藏、手动掌握、FSRS 排程或音频播放状态。
  void exitLearning() {
    _currentBook = null;
    _queue = [];
    _currentIndex = 0;
    _showAnswer = false;
    _choices = [];
    _leitnerEngine.init(const <MwWordProcess>[]);
    _errorWords.clear();
    _totalAnswered = 0;
    _sessionStartTime = null;
    _midSessionPromptShown = false;
    _completionReporter.reset();
    notifyListeners();
  }

  /// 第四轮审计 M18（2026-11-17）：备份恢复后会话复位——队列词对象来自
  /// 恢复前的库（词 id/释义可能已变），继续答会把评分写进恢复后的新库造成
  /// 错配。清会话与恢复暂存，用户下次进学习页重新取词。
  Future<void> resetForRestore() async {
    exitLearning();
    _pendingResume = null;
    _combo = 0;
    _bestCombo = 0;
    _currentWordWrong = false;
    _lastWrongWordId = null;
    _sessionRewardSettled = false;
    _extraPool.reset();
  }

  Future<void> rate(FsrsRating rating) async {
    final word = currentWord;
    if (word == null) return;
    // 重入保护：rate() 在 await 评分间隙是异步的，快速连点会二次进入并重复推进索引。
    if (_isRating) return;
    _isRating = true;

    try {
      // P1-02 Durable Command：FSRS 持久化成功才推进会话与计数——
      // 硬失败（连降级日志都写不进）时 UI 停留当前词，绝无「假成功」。
      // 第四轮 M4：「FSRS 写 → Leitner 推进」编排下沉 application 执行器
      // （镜像 review 侧 ReviewSessionRatingExecutor）；错词记录经回调交还。
      await _ratingExecutor.rate(word: word.word, rating: rating, onAgain: () => _errorWords.add(word));
      _totalAnswered++;
      // 用户反馈修复（2026-11-14）：跳过/答错(again)不计「今日已学」，
      // 防止空手刷每日目标/任务/会话奖；按词去重防重答重复计数。
      if (rating != FsrsRating.again) {
        unawaited(_incrementTodayLearned(word.word));
      }

      // MW-40：wasLastWord 判定修正——原 `_currentIndex < _queue.length` 恒真、
      // `> _queue.length` 永不触发，最后一词的会话完成 breadcrumb 从未记录。
      final wasLastWord = _currentIndex == _queue.length - 1;
      _currentIndex++;
      _currentWordWrong = false;
      _lastWrongWordId = null;
      // 完成整个队列：让 currentWord 变为 null，触发学习完成界面，而不是永远停在最后一个词。
      if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.length;
        // 审计 I87：会话完成漏斗（过转变守卫，完成后的重复评分不重复记录）
        if (wasLastWord) {
          unawaited(Sentry.addBreadcrumb(Breadcrumb(message: '学习会话完成: ${_queue.length} 词', category: 'learning')));
          // 使用统计：与 breadcrumb 同一守卫，保证一次会话只记一次。
          _reportSessionCompleted();
        }
      }
      _regenerateChoices();
      notifyListeners();
      // MW-27 断点①：每次评分后持久化索引（原实现只在 loadBook/jumpTo 保存）。
      unawaited(_saveProgress());
    } on FsrsRatingPersistException catch (error, stack) {
      // 持久化硬失败：不推进索引、不计数、不推进引擎，UI 停留当前词。
      reportSwallowedError('FSRS 评分持久化硬失败（会话未推进）', error, stack);
      notifyListeners();
    } finally {
      _isRating = false;
    }
  }

  /// 从指定单词列表加载学习队列（用于错题复习）。
  void loadFromWords(List<Word> words, {Book? book}) {
    if (words.isEmpty) return;
    // 打乱顺序，避免按错误顺序重复
    final shuffled = List<Word>.from(words)..shuffle();
    _replaceQueue(shuffled);
    _errorWords.clear();
    _totalAnswered = 0;
    _sessionStartTime = DateTime.now();
    _sessionId = _newSessionId();
    _midSessionPromptShown = false;
    _completionReporter.reset();
    notifyListeners();
  }

  void relearn() {
    final word = currentWord;
    if (word == null) return;

    _queue.removeAt(_currentIndex);
    _queue.insert(_currentIndex.clamp(0, _queue.length), word);
    unawaited(_reviewSchedulePort.forget(word.word));
    if (_currentIndex >= _queue.length) {
      _currentIndex = _queue.length - 1;
    }
    _regenerateChoices();
    notifyListeners();
  }

  void next() {
    if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      _showAnswer = false;
    }
    _regenerateChoices();
    notifyListeners();
  }

  void previous() {
    if (_currentIndex > 0) {
      _currentIndex--;
      _showAnswer = false;
    }
    _regenerateChoices();
    notifyListeners();
  }

  void jumpTo(int index) {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    _showAnswer = false;
    _regenerateChoices();
    notifyListeners();
    unawaited(_saveProgress());
  }

  Future<void> _loadProgress() async {
    await _loadTodayLearned();
    try {
      final saved = await _progressPort.load();
      // MW-27：启动时队列必然为空，快照只暂存不直接应用——应用时机在
      // [loadBook] 队列就绪后（同书匹配）。原实现「队列非空才恢复」在
      // 冷启动路径永远为假，「继续上次学习」形同虚设。
      if (saved != null) {
        _pendingResume = saved;
      }
    } catch (error, stack) {
      // 错误处理审计 P3：进度属 A 级持久化路径，debugPrint 在 release 不可见
      // 且 Sentry 无感知，改走统一吞错上报通道。
      reportSwallowedError('学习进度读取失败', error, stack);
    }
  }

  Future<void> _saveProgress() async {
    try {
      if (_currentBook == null) return;
      await _progressPort.save(currentBook: _currentBook!, currentIndex: _currentIndex, queue: _queue);
    } catch (error, stack) {
      // A 级持久化路径（进度丢失用户可感知），须上报
      reportSwallowedError('学习进度写入失败', error, stack);
    }
  }

  void _replaceQueue(List<Word> rawQueue, {bool shuffle = true}) {
    // 用户反馈修复（2026-11-14）：扩池原先每 App 生命周期只取一次，整天共用
    // 同一批 24 干扰词。换书/换收藏时重置，下一题重新随机取样。
    _extraPool.reset();
    // 过滤无中文释义的空壳词：词库约 55% 词条缺 interpret（数据源如此），
    // 空词进队列会导致四选一残缺、详情页空白。宁少勿缺。
    final filtered = rawQueue
        .where((w) => DefinitionFormatter.extractChinese(w.interpret).isNotEmpty)
        .toList(growable: false);
    // 用户需求：单词顺序打乱，避免同一首字母连续出现
    final queue = shuffle ? _shuffler(filtered) : filtered;
    _queue = queue;
    _currentIndex = 0;
    _showAnswer = false;
    _leitnerEngine.init(
      _queue
          .map(
            (word) => MwWordProcess(
              word: word.word,
              wordId: word.id,
              interpret: word.interpret,
              usPron: word.usPron,
              ukPron: word.ukPron,
              example: word.example,
            ),
          )
          .toList(growable: false),
    );
    _regenerateChoices();
    notifyListeners();
  }

  // M4（2026-11-18）：与复习侧同走 ChoiceGenerator，但候选源类型不同——学习侧
  // 候选是 Word 队列（_queue）+ 额外池，复习侧是 MwWordProcess 余池（reviewList）
  // + 额外池（经 ReviewSessionQuestionFactory）。统一需引入候选适配层，反增复杂度，
  // 保留各自投影；共享部分（额外池编排、正确率口径）已分别下沉。
  void _regenerateChoices() {
    final current = currentWord;
    if (current == null) {
      _choices = [];
      return;
    }

    // 用户反馈修复（2026-11-14）：会话队列过小（或复习余池收缩）时干扰项
    // 反复重复、甚至补假占位。从词库随机取真实词扩充候选池；首题异步加载，
    // 就绪后再生一次，其后各题复用同一池（释义去重由 ChoiceGenerator 负责）。
    _extraPool.ensureLoaded();
    final generated = _choicePort.generate(
      correct: ChoiceCandidate(word: current.word, interpret: DefinitionFormatter.normalizeDisplay(current.interpret)),
      candidates: [
        ..._queue.map(
          (word) => ChoiceCandidate(word: word.word, interpret: DefinitionFormatter.normalizeDisplay(word.interpret)),
        ),
        ..._extraPool.words.map(
          (word) => ChoiceCandidate(word: word.word, interpret: DefinitionFormatter.normalizeDisplay(word.interpret)),
        ),
      ],
    );
    _choices = generated.map((c) => WordChoicePair(c.word, c.interpret)).toList(growable: false);
  }
}
