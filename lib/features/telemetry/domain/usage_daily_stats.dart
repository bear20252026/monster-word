// 使用统计的领域模型（R2-01 之后的新能力：使用遥测）。
//
// 设计原则（决定了字段取舍，改之前请先读）：
//   1. **只上报「多少」，不上报「什么」**。时长、次数、数量、正确率是聚合量；
//      具体学了哪些词、搜索词、笔记与收藏正文、逐条答题记录一律不上报 ——
//      那才是隐私政策里承诺「不上传学习内容」所指的东西。
//   2. **日粒度**。使用时长与基本情况本身就是按天看的数据，更细的时间分辨率
//      不增加信息量，只增加隐私代价。
//   3. 本文件**必须是纯 Dart**（不得 import flutter/*）：这样它能被普通 Dart VM
//      直接执行，本机就能跑真断言（本仓 flutter test 受 365vpn 影响不可用）。
//
// 字段命名与 `deploy/telemetry/schema.sql` 的列一一对应，改这里要同步改那边。

/// 单日的使用统计（聚合量）。
class UsageDailyStats {
  const UsageDailyStats({
    required this.day,
    this.foregroundMs = 0,
    this.sessionCount = 0,
    this.studySessionCount = 0,
    this.wordsReviewed = 0,
    this.wordsCorrect = 0,
    this.newWordsLearned = 0,
    this.bookWordCount = 0,
    this.bookLearnedCount = 0,
    this.streakDays = 0,
    this.coinsEarned = 0,
    this.moduleOpenCounts = const {},
  });

  /// 本地日期，`YYYY-MM-DD`。用本地日期而非 UTC：用户感知的「今天」是本地今天。
  final String day;

  /// 当天应用处于前台的累计毫秒数。
  final int foregroundMs;

  /// 当天进入前台的次数（近似「打开了几次」）。
  final int sessionCount;

  /// 当天完成的学习会话数。
  final int studySessionCount;

  /// 当天复习/答题的词次（不是去重后的词数 —— 去重后的词数属于「学习内容」）。
  final int wordsReviewed;

  /// 其中答对的词次。服务端可用 wordsCorrect / wordsReviewed 算正确率。
  final int wordsCorrect;

  /// 当天新学的词数。
  final int newWordsLearned;

  /// 当前词书总词数与已学数 —— 用于算进度百分比。
  /// **只传数字不传词书名**：书名属于「学习内容」。
  final int bookWordCount;
  final int bookLearnedCount;

  /// 连续签到天数。
  final int streakDays;

  /// 当天获得的虚拟道具数量。
  final int coinsEarned;

  /// 各模块当天被打开的次数，如 `{'learn': 3, 'listen': 1}`。
  ///
  /// 「基本情况」里最有用的部分：能看出用户到底在用哪些功能，而不必上报任何内容。
  /// key 是固定的模块标识（见 [knownModules]），不是用户输入，故不构成内容泄露。
  final Map<String, int> moduleOpenCounts;

  /// 允许出现在 [moduleOpenCounts] 里的模块标识。白名单而非黑名单：
  /// 万一哪天有人往这里塞了用户可见的字符串，也上不去。
  static const List<String> knownModules = [
    'learn',
    'review',
    'listen',
    'dict',
    'whiteboard',
    'book',
    'content',
    'community',
    'profile',
  ];

  /// 单条上报里 moduleOpenCounts 的最大键数（服务端也会独立校验一次）。
  static const int maxModules = 20;

  /// 单条上报里最多带几天的数据（一次最多补传这么多天）。
  static const int maxDaysPerReport = 31;

  /// 前台时长的合理上限（24 小时）。超过即视为时钟异常或累计 bug，上传前夹紧。
  static const int maxForegroundMsPerDay = 24 * 60 * 60 * 1000;

  /// 夹紧到服务端契约允许的范围。
  ///
  /// 为什么需要：本地累计依赖系统时钟。用户改系统时间、或进程被挂起很久后恢复，
  /// 都可能算出荒谬的值；**宁可上报一个被夹紧的数，也不要让服务端因为一条脏数据
  /// 拒绝整批**（那样会连带丢掉同批里正常的日期）。
  UsageDailyStats clamped() => UsageDailyStats(
    day: day,
    foregroundMs: _clampNonNegative(foregroundMs, maxForegroundMsPerDay),
    sessionCount: _clampNonNegative(sessionCount, 100000),
    studySessionCount: _clampNonNegative(studySessionCount, 100000),
    wordsReviewed: _clampNonNegative(wordsReviewed, 1000000),
    // 答对数不得超过复习词次 —— 否则服务端算出的正确率会 >100%
    wordsCorrect: _clampNonNegative(wordsCorrect, 1000000).clamp(0, _clampNonNegative(wordsReviewed, 1000000)),
    newWordsLearned: _clampNonNegative(newWordsLearned, 1000000),
    bookWordCount: _clampNonNegative(bookWordCount, 1000000),
    bookLearnedCount: _clampNonNegative(bookLearnedCount, 1000000).clamp(0, _clampNonNegative(bookWordCount, 1000000)),
    streakDays: _clampNonNegative(streakDays, 100000),
    coinsEarned: _clampNonNegative(coinsEarned, 10000000),
    moduleOpenCounts: {
      for (final entry in moduleOpenCounts.entries.take(maxModules))
        if (knownModules.contains(entry.key)) entry.key: _clampNonNegative(entry.value, 1000000),
    },
  );

  static int _clampNonNegative(int value, int max) => value < 0 ? 0 : (value > max ? max : value);

  UsageDailyStats copyWith({
    String? day,
    int? foregroundMs,
    int? sessionCount,
    int? studySessionCount,
    int? wordsReviewed,
    int? wordsCorrect,
    int? newWordsLearned,
    int? bookWordCount,
    int? bookLearnedCount,
    int? streakDays,
    int? coinsEarned,
    Map<String, int>? moduleOpenCounts,
  }) => UsageDailyStats(
    day: day ?? this.day,
    foregroundMs: foregroundMs ?? this.foregroundMs,
    sessionCount: sessionCount ?? this.sessionCount,
    studySessionCount: studySessionCount ?? this.studySessionCount,
    wordsReviewed: wordsReviewed ?? this.wordsReviewed,
    wordsCorrect: wordsCorrect ?? this.wordsCorrect,
    newWordsLearned: newWordsLearned ?? this.newWordsLearned,
    bookWordCount: bookWordCount ?? this.bookWordCount,
    bookLearnedCount: bookLearnedCount ?? this.bookLearnedCount,
    streakDays: streakDays ?? this.streakDays,
    coinsEarned: coinsEarned ?? this.coinsEarned,
    moduleOpenCounts: moduleOpenCounts ?? this.moduleOpenCounts,
  );

  /// 当天是否有任何值得上报的活动。
  ///
  /// 用途：避免为「装了但没打开」的日子也占一行 —— 那既浪费存储，
  /// 也让「日活」这类指标失真。
  bool get hasActivity =>
      foregroundMs > 0 || sessionCount > 0 || studySessionCount > 0 || wordsReviewed > 0 || newWordsLearned > 0;

  Map<String, Object?> toJson() => {
    'day': day,
    'foreground_ms': foregroundMs,
    'session_count': sessionCount,
    'study_session_count': studySessionCount,
    'words_reviewed': wordsReviewed,
    'words_correct': wordsCorrect,
    'new_words_learned': newWordsLearned,
    'book_word_count': bookWordCount,
    'book_learned_count': bookLearnedCount,
    'streak_days': streakDays,
    'coins_earned': coinsEarned,
    'module_open_counts': moduleOpenCounts,
  };

  /// 容错解析：任何字段类型不对或缺席都退回默认值，**不抛异常**。
  /// 本地库里的历史数据可能来自旧版本，读不出来就当作 0，不要让整条记录失败。
  factory UsageDailyStats.fromJson(Map<String, Object?> json) => UsageDailyStats(
    day: _asString(json['day']) ?? '',
    foregroundMs: _asInt(json['foreground_ms']),
    sessionCount: _asInt(json['session_count']),
    studySessionCount: _asInt(json['study_session_count']),
    wordsReviewed: _asInt(json['words_reviewed']),
    wordsCorrect: _asInt(json['words_correct']),
    newWordsLearned: _asInt(json['new_words_learned']),
    bookWordCount: _asInt(json['book_word_count']),
    bookLearnedCount: _asInt(json['book_learned_count']),
    streakDays: _asInt(json['streak_days']),
    coinsEarned: _asInt(json['coins_earned']),
    moduleOpenCounts: _asIntMap(json['module_open_counts']),
  );

  static String? _asString(Object? value) => value is String && value.isNotEmpty ? value : null;

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static Map<String, int> _asIntMap(Object? value) {
    if (value is! Map) return const {};
    return {
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: _asInt(entry.value),
    };
  }
}

/// 一次上报的完整报文：环境信息 + 若干天的日统计。
///
/// 为什么把环境信息放在**信封**而不是每天一行：App 可能在一天内升级，
/// 版本号属于「上报这一刻的事实」，不该散落在按天的行里各说各话。
class UsageStatsReport {
  const UsageStatsReport({
    required this.deviceId,
    required this.appVersion,
    required this.appBuild,
    required this.platform,
    required this.osVersion,
    required this.locale,
    required this.days,
    this.schemaVersion = currentSchemaVersion,
  });

  /// 当前上报格式版本。改字段语义时递增，服务端据此兼容旧客户端。
  static const int currentSchemaVersion = 1;

  /// 随机生成、稳定不变的设备标识。
  ///
  /// ⚠️ **刻意不与账号 user_id 绑定**：本功能的目的是「使用时长 + 基本情况」，
  /// 不需要知道是谁。不绑定意味着这批数据不可识别到个人，合规压力最小。
  /// 若日后确实要按人看，必须同步改隐私披露（属于可识别到个人的行为记录）。
  final String deviceId;

  final String appVersion;
  final int appBuild;

  /// `windows` / `android` / `linux` / `macos`。
  final String platform;

  /// 系统版本串（来自 `Platform.operatingSystemVersion`，非设备唯一标识）。
  final String osVersion;

  /// 界面语言，如 `zh_CN`。
  final String locale;

  final List<UsageDailyStats> days;
  final int schemaVersion;

  /// 上传前的最终形态：夹紧数值、丢掉无活动的日子、按天上限截断。
  UsageStatsReport sanitized() {
    final cleaned = days.where((d) => d.day.isNotEmpty && d.hasActivity).map((d) => d.clamped()).toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    final trimmed = cleaned.length > UsageDailyStats.maxDaysPerReport
        ? cleaned.sublist(cleaned.length - UsageDailyStats.maxDaysPerReport)
        : cleaned;
    return UsageStatsReport(
      deviceId: deviceId,
      appVersion: appVersion,
      appBuild: appBuild,
      platform: platform,
      osVersion: osVersion,
      locale: locale,
      days: trimmed,
      schemaVersion: schemaVersion,
    );
  }

  bool get isEmpty => days.isEmpty;

  Map<String, Object?> toJson() => {
    'schema_version': schemaVersion,
    'device_id': deviceId,
    'app_version': appVersion,
    'app_build': appBuild,
    'platform': platform,
    'os_version': osVersion,
    'locale': locale,
    'days': days.map((d) => d.toJson()).toList(),
  };
}
