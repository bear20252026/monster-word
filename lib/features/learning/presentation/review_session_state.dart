import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:word_app/core/engine/core_engine.dart' show WordChoicePair;
import 'package:word_app/core/engine/srs_engine.dart' show RecallRating;
import 'package:word_app/core/engine/super_memory_engine.dart';
import 'package:word_app/core/utils/boss_siege.dart';
import 'package:word_app/models/mw_word_process.dart';
import 'package:word_app/models/word.dart';
import 'package:word_app/features/learning/application/review_queue_reader.dart';
import 'package:word_app/features/learning/application/review_rating_writer.dart';
import 'package:word_app/features/learning/application/review_session_question_factory.dart';
import 'package:word_app/features/learning/application/review_session_rating_executor.dart';
import 'package:word_app/features/learning/application/review_session_snapshot.dart';
import 'package:word_app/features/learning/application/review_session_snapshot_store.dart';
import 'package:word_app/features/learning/presentation/review_session_answer_state.dart';
// M2：每日任务进度 + 埋点端口（跨 feature 只 import application 层，R4 允许）。
import 'package:word_app/features/missions/application/daily_mission_store.dart';
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';

/// 正式复习队列加载的当前阶段。
enum ReviewSessionLoadPhase { idle, loading, ready, failed }

/// 正式复习会话的展示状态。
///
/// 该状态负责 `/review` 的内存题目队列、加载阶段、候选项、答题反馈和会话
/// 进度。词源选择由 [ReviewQueueReader] 负责，FSRS 卡片、统计和持久化写入
/// 由 [ReviewRatingWriter] 负责；两者均不在此重复实现。
class ReviewSessionState extends ChangeNotifier {
  ReviewSessionState({
    required this._queueReader,
    required ReviewRatingWriter ratingWriter,
    this._usageStats,
    this._snapshotStore,
    this._dailyMissions,
    SuperMemoryEngine? engine,
    ReviewSessionQuestionFactory? questionFactory,
  }) : _engine = engine ?? SuperMemoryEngine(),
       _questionFactory = questionFactory ?? const ReviewSessionQuestionFactory() {
    _ratingExecutor = ReviewSessionRatingExecutor(engine: _engine, ratingWriter: ratingWriter);
  }

  final ReviewQueueReader _queueReader;
  final SuperMemoryEngine _engine;
  final ReviewSessionQuestionFactory _questionFactory;
  late final ReviewSessionRatingExecutor _ratingExecutor;

  /// 使用统计埋点端口；未注入时为 null，埋点静默跳过。
  final UsageStatsRecorder? _usageStats;

  /// 每日任务（D1）进度端口；未注入时静默跳过。
  final DailyMissionStore? _dailyMissions;

  /// 会话快照门面；未注入时不持久化（单元测试默认如此）。
  final ReviewSessionSnapshotStore? _snapshotStore;

  /// 本局完整词序（恢复后沿用存档顺序；新局取引擎洗牌后的顺序）。
  List<int> _sessionWordIds = const [];

  /// 已消费的词 id（评分落库 / 标记已掌握 / 恢复时已不再到期）。
  final Set<int> _ratedIds = <int>{};

  /// 已作答未提交的题（正确反馈驻留窗口内被杀进程时用于判定，不重复计分）。
  ReviewSessionPending? _pending;

  String _sessionId = '';
  int _dueAtStart = 0;

  /// 本局是否由快照恢复而来（供页面/测试观察）。
  bool _restored = false;

  /// 本会话中「首次作答即答错」的题数（同一题反复点错只算一次）。
  ///
  /// 口径说明：与学习页的错词口径对齐——「答对」指没点错过。用户点错后
  /// 看答案继续（good 评分）仍计入错题，因为那题他确实没能一次答对。
  int _wrongCount = 0;

  /// 当前这一题是否已经点错过（用于同一题去重）。
  bool _currentQuestionWrong = false;

  ReviewSessionLoadPhase _loadPhase = ReviewSessionLoadPhase.idle;
  Object? _loadError;
  late final ReviewSessionAnswerState _answerState = ReviewSessionAnswerState(
    onChanged: notifyListeners,
    // 答对反馈驻留（对勾+彩带）结束后再推进评分，体验对齐学习页的答对时刻
    onCorrectFeedbackElapsed: () => rate(RecallRating.good),
  );
  List<WordChoicePair> _choices = const [];
  int _total = 0;
  int _done = 0;

  /// 开局快照里是否真的有到期词（false = 读到的可能是「整本队列」兜底）。
  ///
  /// 头目战触发口径的一半：没有到期词时绝不能让兜底队列冒充「大军压境」。
  /// 该值只在 [initialize] 里按开局快照定一次，会话中途不变。
  bool _hadDueAtStart = false;

  ReviewSessionLoadPhase get loadPhase => _loadPhase;
  bool get isLoading => _loadPhase == ReviewSessionLoadPhase.idle || _loadPhase == ReviewSessionLoadPhase.loading;
  bool get isReady => _loadPhase == ReviewSessionLoadPhase.ready;
  bool get hasLoadError => _loadPhase == ReviewSessionLoadPhase.failed;
  Object? get loadError => _loadError;
  bool get showAnswer => _answerState.showAnswer;
  String? get selectedWrongChoice => _answerState.selectedWrongChoice;
  List<WordChoicePair> get choices => _choices;
  int get total => _total;
  int get done => _done;

  /// 本局答错词次数（M3：复习结算 XP 用它折算答对数）。
  int get wrongCount => _wrongCount;

  /// 本局唯一标识（M3：复习 XP 的幂等事件键用；恢复存档时沿用原 id）。
  String get sessionId => _sessionId;

  /// 开局是否有到期词（供头目战判定用；语义见 [_hadDueAtStart]）。
  bool get hadDueAtStart => _hadDueAtStart;

  /// 本局是否由上次中断的快照恢复（恢复可用才允许出现「进度已保存」类文案）。
  bool get wasRestored => _restored;

  MwWordProcess? get currentWord => _engine.currentWord();

  void updateRatingWriter(ReviewRatingWriter ratingWriter) {
    _ratingExecutor.updateRatingWriter(ratingWriter);
  }

  /// 按既有正式复习队列优先级初始化本地会话。
  ///
  /// [restore] 非空时先尝试恢复上次中断的一局（词序与步数以存档为准）；
  /// 任何一项对不上（词已不在当前到期集合、存档损坏、剩余为空）就退回新局。
  Future<void> initialize(ReviewQueueSnapshot snapshot, {ReviewSessionSnapshot? restore}) async {
    _answerState.reset();
    _loadPhase = ReviewSessionLoadPhase.loading;
    _loadError = null;
    _choices = const [];
    _total = 0;
    _done = 0;
    // 开局事实先冻结：判定只认这一刻，中途不再重算。
    _hadDueAtStart = snapshot.dueWords.isNotEmpty;
    _dueAtStart = snapshot.dueWords.length;
    _sessionWordIds = const [];
    _ratedIds.clear();
    _pending = null;
    _sessionId = '';
    _restored = false;
    _wrongCount = 0;
    _currentQuestionWrong = false;
    notifyListeners();

    try {
      final loaded = await _queueReader.loadWords(snapshot);
      final plan = restore == null ? null : _planRestore(restore, loaded);
      if (plan != null && restore != null) {
        _applyRestore(restore, plan);
      } else {
        // 单局上限（reviewSessionCap）：只截「到期词」，让一局有界、可预期。
        // 注意 reader 在 due 为空时会回退整本队列——那不是到期词，不属于头目战
        // 口径，必须原样放过（保持该适配器的既有行为，其他调用方依赖它）。
        // 截断口径统一走 sessionDueCount 单源（v2 收尾：消除内联双写）。
        final cap = sessionDueCount(dueAtStart: loaded.length);
        final pool = _hadDueAtStart && loaded.length > cap ? loaded.take(cap).toList(growable: false) : loaded;
        _engine.init(_questionFactory.createProcesses(pool));
        _total = _engine.totalNum;
        _sessionWordIds = List<int>.unmodifiable(_engine.reviewList.map((word) => word.wordId));
        _sessionId = '${DateTime.now().millisecondsSinceEpoch}-${_sessionWordIds.isEmpty ? 0 : _sessionWordIds.first}';
      }
      _loadPhase = ReviewSessionLoadPhase.ready;
      _regenerateChoices();
      _persistSnapshot();
    } catch (error) {
      _loadError = error;
      _loadPhase = ReviewSessionLoadPhase.failed;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// 恢复可行性判定：返回还要继续走的那批词 + 已消费的词 id；不可恢复时返回 null。
  ///
  /// 「不在当前到期集合里」的词按已完成计——它要么评分已经落库（所以不再 due），
  /// 要么已从词书删除；两种都不该再出现，更不能重答一次造成双计。
  ({List<Word> remaining, Set<int> doneIds})? _planRestore(ReviewSessionSnapshot saved, List<Word> loaded) {
    if (!saved.hadDueAtStart || !_hadDueAtStart) return null;
    final byId = {for (final word in loaded) word.id: word};
    final rated = saved.ratedIds.toSet();
    final remaining = <Word>[];
    final doneIds = <int>{};
    for (final id in saved.wordIds) {
      if (rated.contains(id)) {
        doneIds.add(id);
        continue;
      }
      final word = byId[id];
      if (word == null) {
        doneIds.add(id);
        continue;
      }
      remaining.add(word);
    }
    if (remaining.isEmpty) return null;
    return (remaining: remaining, doneIds: doneIds);
  }

  /// 按存档词序重建引擎；顺序必须保持，否则「上次做到第几步」会错位。
  void _applyRestore(ReviewSessionSnapshot saved, ({List<Word> remaining, Set<int> doneIds}) plan) {
    _hadDueAtStart = saved.hadDueAtStart;
    _dueAtStart = saved.dueAtStart;
    _sessionId = saved.sessionId;
    _sessionWordIds = List<int>.unmodifiable(saved.wordIds);
    _ratedIds
      ..clear()
      ..addAll(plan.doneIds);
    // 已作答未提交（pending）的词仍在 remaining 里：让用户重答一次，
    // 若其实已落库则该词已不在 due 集合中，上面已经计为完成，不会双计。
    _pending = null;
    _engine.init(_questionFactory.createProcesses(plan.remaining), shuffle: false);
    _total = saved.wordIds.length;
    _done = plan.doneIds.length;
    _restored = true;
  }

  /// 写会话快照；走完一局（done == total）或本就不该恢复时清掉旧存档。
  void _persistSnapshot() {
    final store = _snapshotStore;
    if (store == null) return;
    if (!_hadDueAtStart || _sessionWordIds.isEmpty || _total <= 0 || _done >= _total) {
      unawaited(store.clear());
      return;
    }
    final snapshot = ReviewSessionSnapshot(
      sessionId: _sessionId,
      wordIds: _sessionWordIds,
      index: _done,
      ratedIds: _ratedIds.toList(growable: false),
      pending: _pending,
      hadDueAtStart: true,
      dueAtStart: _dueAtStart,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    unawaited(store.write(snapshot));
  }

  /// 处理一个候选项选择；错误选择会显示 300 毫秒的反馈，正确选择视作 good。
  void selectChoice(String selectedWord) {
    final reviewedWord = currentWord;
    if (reviewedWord == null) return;

    // 答对进入反馈驻留，驻留结束经 onCorrectFeedbackElapsed → rate(good) 推进；
    // 此处不再立即评分，避免对勾/彩带未展示即切题。
    final wasRevealed = _answerState.correctRevealed;
    final selection = _answerState.selectChoice(selectedWord: selectedWord, correctWord: reviewedWord.word);
    // 埋点口径：同一题只记一次错（反复点错不重复计）。
    if (selection == ReviewChoiceSelection.wrong && !_currentQuestionWrong) {
      _currentQuestionWrong = true;
      _wrongCount++;
    }
    // 已作答、尚未提交：记进快照，进程若在 600ms 反馈窗口内被杀，
    // 恢复时据此知道「这题答过但没落库」——是否双计由该词还在不在 due 集合决定。
    if (selection == ReviewChoiceSelection.correct && !wasRevealed) {
      _pending = ReviewSessionPending(wordId: reviewedWord.wordId, correct: true);
      _persistSnapshot();
    }
  }

  bool isWrongChoiceSelected(String word) => _answerState.isWrongChoiceSelected(word);

  /// 本题已答对并处于反馈驻留窗口。
  bool get correctRevealed => _answerState.correctRevealed;

  /// 记录本题评分，推进本地引擎，并异步提交同一题目的 FSRS 持久化请求。
  /// 评分并推进（**先落盘、成功才翻页**，业主 2026-10-17 选定「甲」）。
  ///
  /// 返回 `true` = 已保存并进入下一题；`false` = 没保存成功，**本题原地不动**，
  /// 由 UI 提示用户重试。审计 P1-04：原实现先推进引擎再后台写库，写失败时
  /// 用户看到的是「复习完成」，记录其实丢了。
  ///
  /// 连点处理：写入进行中再次调用会**复用同一次写入**（返回同一个 Future），
  /// 既不会重复落库，也不会把「正在保存」误报成失败。
  Future<bool> rate(RecallRating rating) {
    final inflight = _inflightRating;
    if (inflight != null) return inflight;
    final future = _persistThenAdvance(rating).whenComplete(() => _inflightRating = null);
    _inflightRating = future;
    return future;
  }

  Future<bool>? _inflightRating;

  Future<bool> _persistThenAdvance(RecallRating rating) async {
    final reviewedWord = currentWord;
    if (reviewedWord == null) return false;

    final ok = await _ratingExecutor.rate(reviewedWord: reviewedWord, rating: rating);
    if (!ok) {
      // 不推进、不重置作答态：用户仍停在本题，可以再点一次。
      notifyListeners();
      return false;
    }

    _completeStep(reviewedWord);
    _regenerateChoices();
    notifyListeners();
    return true;
  }

  /// 一题走完的公共收尾：推进 done、记消费 id、清 pending、写快照（走完则清档）。
  ///
  /// `rate()` 与 `markAsKnown()` 两条路径都必须经过这里，头目护盾只挂 `done`，
  /// 这样「标记已掌握」也能掉怪、裂盾。
  void _completeStep(MwWordProcess reviewedWord) {
    _answerState.reset();
    _currentQuestionWrong = false;
    _done++;
    _ratedIds.add(reviewedWord.wordId);
    _pending = null;
    _persistSnapshot();
    // M2/D1：复习到期词任务。只有「开局确实有到期词」的正式复习队列才计数；
    // 无到期词时的兜底队列不算复习，避免把新学/兜底词混进复习口径。
    final missions = _dailyMissions;
    if (missions != null && _hadDueAtStart) unawaited(missions.recordReviewedWord());
    _reportSessionCompletedIfDone();
  }

  void revealAnswer() {
    _answerState.revealAnswer();
  }

  /// 「看答案后继续」。
  ///
  /// ⚠️ 审计 P1-05（2026-10-17）：原实现**无条件** `rate(RecallRating.good)`，
  /// 于是「答错 → 看答案 → 继续」这条最需要记 `again` 的路径反而记了 `good`
  /// ⇒ 同一份数据里**报表记的是错题、FSRS 记的是记忆良好**，两边互相矛盾，
  /// 而且 FSRS 会因此高估记忆程度、把该词的下次到期日推远。
  /// 现在按本次作答的真实对错分流：答错记 `again`，答对仍记 `good`。
  Future<bool> continueWithGoodRating() => rate(_currentQuestionWrong ? RecallRating.again : RecallRating.good);

  /// 「熟」：仅推进会话计数，**有意不提交 FSRS 评分**（产品语义，非遗漏）。
  ///
  /// 与 continueWithGoodRating（good→FSRS）区分：用户认为该词已掌握时跳过
  /// 复习队列即可，不改 stability/due。若未来拍板要记 FSRS，应映射 easy 并补测试。
  bool markAsKnown() {
    final reviewedWord = currentWord;
    if (reviewedWord == null) return false;
    _ratingExecutor.markAsKnown();
    _completeStep(reviewedWord);
    _regenerateChoices();
    notifyListeners();
    return true;
  }

  /// 队列走完时上报一次会话（会话数 + 答题词次与答对数）。
  ///
  /// 为什么放在这里而不是页面里：`_done`/`_total`/错题数都在本类，
  /// 页面再算一遍就会有两套口径。`currentWord == null` 之后 [rate] 会提前返回，
  /// 所以本方法在一次会话里只会命中一次。
  void _reportSessionCompletedIfDone() {
    if (_total <= 0 || _done < _total) return;
    final recorder = _usageStats;
    if (recorder != null) {
      unawaited(recorder.recordStudySession());
      unawaited(recorder.recordAnswers(reviewed: _done, correct: (_done - _wrongCount).clamp(0, _done)));
    }
    // M2/D1：一局正确率 ≥80%（复习同计；错题口径与上方 usageStats 一致）。
    final missions = _dailyMissions;
    final percent = sessionAccuracyPercent(answered: _done, correct: (_done - _wrongCount).clamp(0, _done));
    if (missions != null && percent != null) unawaited(missions.recordSessionAccuracyPercent(percent));
  }

  void _regenerateChoices() {
    final current = currentWord;
    if (current == null) {
      _choices = const [];
      return;
    }

    _choices = _questionFactory.createChoices(currentWord: current, reviewWords: _engine.reviewList);
  }

  @override
  void dispose() {
    _answerState.dispose();
    super.dispose();
  }
}
