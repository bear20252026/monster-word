// 使用统计的累计与上报决策。
//
// 这是本功能的「业务规则」所在，**刻意做成纯 Dart**：本仓 `flutter test` 受 365vpn
// 影响不可用，只有不 import flutter 的代码能在本机真跑断言（见 lib/features/telemetry/README.md）。
// 因此这里只依赖注入进来的端口与时钟，不碰 Flutter、不碰真实网络。
//
// 关于上报频率（业主问的「多久收几次合理」）：见 [uploadInterval] 的注释。

import 'package:word_app/features/telemetry/domain/usage_daily_stats.dart';
import 'package:word_app/features/telemetry/application/usage_stats_ports.dart';

class UsageStatsCollector {
  UsageStatsCollector({
    required this.store,
    required this.uploader,
    required this.environment,
    required this.settings,
    required this.clock,
    this.uploadInterval = const Duration(hours: 24),
    this.retryDelay = const Duration(hours: 2),
    this.retention = const Duration(days: 180),
  });

  final UsageStatsStore store;
  final UsageStatsUploader uploader;
  final UsageStatsEnvironment environment;
  final UsageStatsSettings settings;

  /// 时钟注入而不是内部直接 DateTime.now()：跨午夜切分与退避判断都要能测。
  final DateTime Function() clock;

  /// 两次成功上报之间的最小间隔。
  ///
  /// **每日一次是刻意的选择**，不是偷懒：
  ///   - 「使用时长 + 基本情况」本身就是日粒度数据，更高频率不增加任何信息量；
  ///   - 频率越高，越像一份高精度行为日志 —— 隐私代价上升而分析价值不变；
  ///   - 每设备每年约 365 次请求、每次几百字节，服务端与流量都可忽略。
  /// 想改频率就改这一个值；但改之前请确认隐私披露里的表述仍然成立。
  final Duration uploadInterval;

  /// 上报失败后的重试间隔。不做指数退避：调用点本来就稀疏（启动时一次），
  /// 固定间隔已足够避免「反复打一个挂掉的服务端」。
  final Duration retryDelay;

  /// 已上报数据的本地保留期（未上报的**不**清理，避免丢数据）。
  final Duration retention;

  bool _enabled = false;
  DateTime? _foregroundSince;

  /// 启动时调用一次：读开关。
  Future<void> initialize() async {
    _enabled = await settings.isEnabled();
  }

  bool get isEnabled => _enabled;

  /// 用户在设置里改开关。
  ///
  /// 关掉时**立即清除本地未上报的统计**：既然承诺「关了就不收集」，就不该把
  /// 关之前攒的数据留着等哪天又被打开。已上报到服务端的历史数据不在此处处理
  /// （那属于保留期策略，见 [retention]）。
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await settings.setEnabled(value);
    if (!value) {
      _foregroundSince = null;
      await store.clearAll();
    }
  }

  // ── 前台时长 ────────────────────────────────────────────────

  /// App 进入前台。重复调用幂等（不会重复计一次启动）。
  Future<void> onForeground() async {
    if (!_enabled || _foregroundSince != null) return;
    _foregroundSince = clock();
    await _mutateToday((s) => s.copyWith(sessionCount: s.sessionCount + 1));
  }

  /// App 离开前台：结算这段前台时长。
  Future<void> onBackground() async {
    if (!_enabled) return;
    await _flushForeground();
    _foregroundSince = null;
  }

  /// 把「当前这段前台时长」结算进按天桶，并把起点推到 now。
  ///
  /// 可重复调用（不会重复计）：这也让 [maybeUpload] 能先结算一次，
  /// 避免进程被直接杀掉时丢掉最后一截时长。
  Future<void> _flushForeground() async {
    final since = _foregroundSince;
    if (since == null) return;
    final now = clock();
    _foregroundSince = now;
    if (!now.isAfter(since)) return; // 时钟回拨：丢弃这段，不写负数
    await _addForegroundMs(since, now);
  }

  /// 按**本地午夜**把一段时长切开计入各自的日子。
  ///
  /// 为什么要切：用户可能 23:50 学到 00:20，整段算给任何一天都会让那天的数据
  /// 偏一小时。切开是唯一能让「每天的时长」对得上账的做法。
  Future<void> _addForegroundMs(DateTime from, DateTime to) async {
    var cursor = from;
    // 防御：系统时钟被往前跳时，别在这里循环几万次。
    for (var guard = 0; guard < 8 && cursor.isBefore(to); guard++) {
      final nextMidnight = DateTime(cursor.year, cursor.month, cursor.day).add(const Duration(days: 1));
      final segmentEnd = nextMidnight.isBefore(to) ? nextMidnight : to;
      final ms = segmentEnd.difference(cursor).inMilliseconds;
      if (ms > 0) {
        final day = dayKey(cursor);
        await _mutateDay(day, (s) => s.copyWith(foregroundMs: s.foregroundMs + ms));
      }
      cursor = segmentEnd;
    }
  }

  // ── 行为计数 ────────────────────────────────────────────────

  /// 打开某个模块（`learn` / `listen` / …）。未知模块由模型层白名单丢弃。
  Future<void> recordModuleOpen(String module) async {
    if (!_enabled) return;
    await _mutateToday((s) {
      final next = Map<String, int>.from(s.moduleOpenCounts);
      next[module] = (next[module] ?? 0) + 1;
      return s.copyWith(moduleOpenCounts: next);
    });
  }

  /// 完成一个学习会话。
  Future<void> recordStudySession() async {
    if (!_enabled) return;
    await _mutateToday((s) => s.copyWith(studySessionCount: s.studySessionCount + 1));
  }

  /// 记录一批答题结果。[reviewed] 是词次，[correct] 是其中答对的词次。
  Future<void> recordAnswers({required int reviewed, required int correct}) async {
    if (!_enabled || reviewed <= 0) return;
    await _mutateToday(
      (s) => s.copyWith(
        wordsReviewed: s.wordsReviewed + reviewed,
        wordsCorrect: s.wordsCorrect + correct.clamp(0, reviewed),
      ),
    );
  }

  /// 记录新学词数。
  Future<void> recordNewWordsLearned(int count) async {
    if (!_enabled || count <= 0) return;
    await _mutateToday((s) => s.copyWith(newWordsLearned: s.newWordsLearned + count));
  }

  /// 同步词书进度（覆盖写，不是累加 —— 它是状态量）。
  Future<void> syncBookProgress({required int wordCount, required int learned}) async {
    if (!_enabled) return;
    await _mutateToday((s) => s.copyWith(bookWordCount: wordCount, bookLearnedCount: learned));
  }

  /// 同步连续签到天数（状态量）。
  Future<void> syncStreak(int days) async {
    if (!_enabled) return;
    await _mutateToday((s) => s.copyWith(streakDays: days));
  }

  /// 记录获得的虚拟道具数量（累加）。
  Future<void> recordCoinsEarned(int count) async {
    if (!_enabled || count <= 0) return;
    await _mutateToday((s) => s.copyWith(coinsEarned: s.coinsEarned + count));
  }

  // ── 上报 ────────────────────────────────────────────────────

  /// 该不该现在上报。抽成独立方法是为了能直接对它写断言。
  ///
  /// 返回 null 表示「不该报」；否则返回不该报的原因（便于日志与测试）。
  Future<String?> skipReason() async {
    if (!_enabled) return 'disabled';

    final now = clock();
    final nextAttempt = await store.readNextAttemptAt();
    if (nextAttempt != null && now.isBefore(nextAttempt)) return 'backoff';

    final last = await store.readLastUploadAt();
    if (last != null && now.difference(last) < uploadInterval) return 'tooSoon';

    final pending = await store.readPending(limit: UsageDailyStats.maxDaysPerReport);
    if (pending.isEmpty) return 'nothingPending';

    return null;
  }

  /// 到点就上报一次。**任何失败都只记日志，不影响调用方**。
  Future<void> maybeUpload() async {
    if (!_enabled) return;
    // 先结算当前这段前台时长：进程可能下一秒就被杀掉，那截时长不该丢。
    await _flushForeground();

    if (await skipReason() != null) return;

    final pending = await store.readPending(limit: UsageDailyStats.maxDaysPerReport);
    final report = await _buildReport(pending);
    if (report.isEmpty) return;

    final ok = await uploader.upload(report);
    final now = clock();
    if (ok) {
      await store.markUploaded(report.days.map((d) => d.day));
      await store.writeLastUploadAt(now);
      await store.writeNextAttemptAt(null);
      // 清理过期明细。放在成功之后：失败时不动数据，下一轮还能补传。
      await store.pruneUploadedBefore(now.subtract(retention));
    } else {
      await store.writeNextAttemptAt(now.add(retryDelay));
    }
  }

  Future<UsageStatsReport> _buildReport(List<UsageDailyStats> days) async => UsageStatsReport(
    deviceId: await environment.deviceId(),
    appVersion: await environment.appVersion(),
    appBuild: await environment.appBuild(),
    platform: environment.platform(),
    osVersion: environment.osVersion(),
    locale: environment.locale(),
    days: days,
  ).sanitized();

  // ── 工具 ────────────────────────────────────────────────────

  /// 本地日期键 `YYYY-MM-DD`。
  ///
  /// 手写而不引入 intl：本文件必须保持零依赖（见文件头）。补零是必须的 ——
  /// 字典序排序与「按天比较」都依赖定长格式。
  static String dayKey(DateTime at) {
    final m = at.month.toString().padLeft(2, '0');
    final d = at.day.toString().padLeft(2, '0');
    return '${at.year}-$m-$d';
  }

  Future<void> _mutateToday(UsageDailyStats Function(UsageDailyStats) change) => _mutateDay(dayKey(clock()), change);

  Future<void> _mutateDay(String day, UsageDailyStats Function(UsageDailyStats) change) async {
    final current = await store.readDay(day) ?? UsageDailyStats(day: day);
    await store.writeDay(change(current));
  }
}
