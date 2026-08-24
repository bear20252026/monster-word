// 由 Claude 团队生成 | Monster Word App

// 统计分析扩展层：翻译自 statistics/（v3.2 源码 1:1）
// BBUMEvent（事件定义 + Dplus映射）+ ISKRuntimeWatchItem + ISKRuntimeWatch + BBStatistician
//
// 与 statistics.dart 的区别：
// - statistics.dart 是简化版，使用英文事件名
// - 本文件忠实翻译 Java 源码，保留中文事件名常量 + Dplus 映射 + 运行时计时

import 'dart:developer' as developer;

// ─────────────────────────────────────────────────────────────────────────────
// BBUMEvent — 友盟/统计事件名常量 + Dplus 事件 ID 映射
// 翻译自 BBUMEvent.java
// ─────────────────────────────────────────────────────────────────────────────

class BBUMEventExt {
  // 事件名常量（中文，与 Java 源码一致）
  static const String umEventBuy = '购买';
  static const String umEventCardAction = '卡片';
  static const String umEventDashboard = '仪表盘';
  static const String umEventDictSearch = '词典搜索';
  static const String umEventExtensiveListen = '随身听';
  static const String umEventFloatButton = '悬浮按钮';
  static const String umEventGlobal = '全局';
  static const String umEventLearnReview = '学习复习';
  static const String umEventLibrary = 'library';
  static const String umEventLoginEvent = '登录';
  static const String umEventMainPage = '首页';
  static const String umEventMessageCenter = '消息中心';
  static const String umEventMySpace = '个人中心';
  static const String umEventMyEvent = '测试日志';
  static const String umEventSentenceCard = '例句卡片';
  static const String umEventSettings = 'settings';
  static const String umEventStatistics = 'statistics';
  static const String umEventWordList = '单词列表';
  static const String umEventWordPanel = '查词面板';

  // Dplus 事件 ID 映射（中文事件名 → 英文事件 ID）
  static final Map<String, String> _dplusMapApp = {
    umEventMainPage: 'BB_mainview',
    umEventDictSearch: 'BB_dictionarysearch',
    umEventLearnReview: 'BB_learn_review',
    umEventWordPanel: 'BB_wordpannel',
    umEventGlobal: 'BB_global',
    umEventLibrary: 'BB_library',
    umEventStatistics: 'BB_statistics',
    umEventSettings: 'BB_settings',
    umEventBuy: 'BB_purchase',
    umEventWordList: 'BB_wordlist',
    umEventCardAction: 'BB_card',
    umEventMySpace: 'BB_mycenter',
    umEventMessageCenter: 'BB_messagecenter',
    umEventFloatButton: 'BB_floatbutton',
    umEventLoginEvent: 'BB_login',
    umEventExtensiveListen: 'BB_extensive_listen',
    umEventSentenceCard: 'BB_sentence_card',
    umEventDashboard: 'BB_dashboard',
  };

  /// 将中文事件名转换为 Dplus 英文事件 ID
  /// 若无映射则返回原名
  static String convertDplusEventName2AppEventId(String name) {
    final result = _dplusMapApp[name];
    return (result == null || result.isEmpty) ? name : result;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ISKRuntimeWatchItem — 单个计时项
// 翻译自 ISKRuntimeWatchItem.java
// ─────────────────────────────────────────────────────────────────────────────

class ISKRuntimeWatchItem {
  final String name;
  final int started; // 毫秒时间戳
  int stopped; // 毫秒时间戳，0 表示未停止

  ISKRuntimeWatchItem._(this.name, this.started) : stopped = 0;

  /// 创建并启动一个计时项
  static ISKRuntimeWatchItem itemWithName(String name) {
    return ISKRuntimeWatchItem._(name, DateTime.now().millisecondsSinceEpoch);
  }

  /// 停止计时
  void stop() {
    stopped = DateTime.now().millisecondsSinceEpoch;
  }

  /// 获取运行时长（毫秒）
  /// - 若未开始返回 0
  /// - 若未停止返回当前时间 - 开始时间
  /// - 若已停止返回 停止时间 - 开始时间
  int runtimeMills() {
    if (started == 0) return 0;
    if (stopped == 0) {
      return DateTime.now().millisecondsSinceEpoch - started;
    }
    return stopped - started;
  }

  int getStopped() => stopped;

  @override
  String toString() {
    final runtime = runtimeMills() / 1000.0;
    return '\nISKRuntimeWatchItem\n\tname:$name\n\tstarted:$started\n\tstopped:$stopped\n\truntime:$runtime\n';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ISKRuntimeWatch — 运行时计时管理器（单例）
// 翻译自 ISKRuntimeWatch.java
// ─────────────────────────────────────────────────────────────────────────────

class ISKRuntimeWatch {
  static const String _logTag = 'ISKRuntimeWatch';
  static final ISKRuntimeWatch _instance = ISKRuntimeWatch._();
  final Map<String, ISKRuntimeWatchItem> _items = {};

  ISKRuntimeWatch._();

  static ISKRuntimeWatch get _getInstance => _instance;

  /// 开始计时
  static void start(String name) {
    _getInstance._add(name);
  }

  /// 停止计时
  static void stop(String name) {
    final item = _getInstance._get(name);
    if (item != null) {
      item.stop();
    }
  }

  /// 获取运行时长（毫秒），不存在返回 0
  static int getRuntime(String name) {
    final item = _getInstance._get(name);
    return item?.runtimeMills() ?? 0;
  }

  void _add(String? name) {
    if (name == null) {
      developer.log('\n----- ISKRuntimeWatch:The name is null !!!', name: _logTag);
      return;
    }
    _remove(name);
    _items[name] = ISKRuntimeWatchItem.itemWithName(name);
  }

  void _remove(String? name) {
    if (name == null) {
      developer.log(
        "\n----- ISKRuntimeWatch:The items doesn't include the item !!! name = null",
        name: _logTag,
      );
      return;
    }
    _items.remove(name);
  }

  ISKRuntimeWatchItem? _get(String? name) {
    if (name == null) {
      developer.log(
        '\n ----- ISKRuntimeWatch:The name is null, return null !!! ',
        name: _logTag,
      );
      return null;
    }
    return _items[name];
  }

  /// 调试：打印指定计时项
  void print(String name) {
    final item = _getInstance._get(name);
    if (item == null) {
      developer.log(
        '\n----- ISKRuntimeWatch:Not watch the 【$name】event !!! ',
        name: _logTag,
      );
      return;
    }
    if (item.getStopped() == 0) {
      developer.log(
        '\n----- item is running :${item.toString()}',
        name: _logTag,
      );
    } else {
      developer.log(
        '\n----- item :${item.toString()}',
        name: _logTag,
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BBStatisticianExt — 统计器（扩展版）
// 翻译自 BBStatistician.java：单例，管理 app/learn/review/listen 时长追踪
// ─────────────────────────────────────────────────────────────────────────────

class BBStatisticianExt {
  static const String _appTracking = 'BB_APP_TRACKING';
  static const String _detailedListenTracking = 'DETAILED_LISTEN_TRACKING';
  static const String _learnTracking = 'BB_LEARN_TRACKING';
  static const String _logTag = 'BBStatistician';
  static const String _reviewTracking = 'BB_REVIEW_TRACKING';

  static final BBStatisticianExt _instance = BBStatisticianExt._();
  final Set<String> _items = {};

  // 回调：外部注入的 LexisDaily 更新逻辑
  // Java 原版直接操作 LexisDaily 单例；Flutter 版通过回调解耦
  DurationCallback? _onAppDurationUpdate;
  DurationCallback? _onLearnDurationUpdate;
  DurationCallback? _onReviewDurationUpdate;
  DurationCallback? _onListenDurationUpdate;
  VoidCallback? _onAppEnd;
  bool Function()? _isUserIdEmpty;
  VoidCallback? _onTrackingAppStart;

  BBStatisticianExt._();

  static BBStatisticianExt get instance => _instance;

  // ── 回调注册 ──────────────────────────────────────────────────────────────

  /// 注册回调，用于连接 LexisDaily 等数据层
  void registerCallbacks({
    DurationCallback? onAppDurationUpdate,
    DurationCallback? onLearnDurationUpdate,
    DurationCallback? onReviewDurationUpdate,
    DurationCallback? onListenDurationUpdate,
    VoidCallback? onAppEnd,
    bool Function()? isUserIdEmpty,
    VoidCallback? onTrackingAppStart,
  }) {
    _onAppDurationUpdate = onAppDurationUpdate;
    _onLearnDurationUpdate = onLearnDurationUpdate;
    _onReviewDurationUpdate = onReviewDurationUpdate;
    _onListenDurationUpdate = onListenDurationUpdate;
    _onAppEnd = onAppEnd;
    _isUserIdEmpty = isUserIdEmpty;
    _onTrackingAppStart = onTrackingAppStart;
  }

  // ── App 时长追踪 ──────────────────────────────────────────────────────────

  /// 开始追踪 App 使用时长
  /// Java 原版会检查 userId 并初始化 LexisDaily
  void startTrackingApp() {
    if (_isUserIdEmpty?.call() ?? true) {
      developer.log(
        "\n----- startTrackingApp:Can't start! user is null !!! ",
        name: _logTag,
      );
      return;
    }
    _onTrackingAppStart?.call();
    _startTracking(_appTracking);
  }

  /// 结束追踪 App 使用时长
  void endTrackingApp() {
    _endTracing(_appTracking);
    final appDuration = ISKRuntimeWatch.getRuntime(_appTracking);
    _onAppDurationUpdate?.call(appDuration);
    _onAppEnd?.call();
  }

  // ── Learn 时长追踪 ────────────────────────────────────────────────────────

  /// 开始追踪学习时长
  void startTrackingLearn() {
    _startTracking(_learnTracking);
  }

  /// 结束追踪学习时长
  void endTrackingLearn() {
    _endTracing(_learnTracking);
    final learnDuration = ISKRuntimeWatch.getRuntime(_learnTracking);
    _onLearnDurationUpdate?.call(learnDuration);
  }

  /// 是否正在追踪学习
  bool get isTrackingLearn => _items.contains(_learnTracking);

  // ── Review 时长追踪 ───────────────────────────────────────────────────────

  /// 开始追踪复习时长
  void startTrackingReview() {
    _startTracking(_reviewTracking);
  }

  /// 结束追踪复习时长
  void endTrackingReview() {
    _endTracing(_reviewTracking);
    final reviewDuration = ISKRuntimeWatch.getRuntime(_reviewTracking);
    _onReviewDurationUpdate?.call(reviewDuration);
  }

  /// 是否正在追踪复习
  bool get isTrackingReview => _items.contains(_reviewTracking);

  // ── Listen 时长追踪 ───────────────────────────────────────────────────────

  /// 开始追踪随身听时长
  void startTrackingListen() {
    _startTracking(_detailedListenTracking);
  }

  /// 结束追踪随身听时长
  void endTrackingListen() {
    _endTracing(_detailedListenTracking);
    final listenDuration = ISKRuntimeWatch.getRuntime(_detailedListenTracking);
    _onListenDurationUpdate?.call(listenDuration);
  }

  // ── 内部方法 ──────────────────────────────────────────────────────────────

  void _startTracking(String? name) {
    if (name == null) {
      developer.log(
        "\n----- BBStatistician:The name is null !!! ",
        name: _logTag,
      );
      return;
    }
    if (_items.contains(name)) return;
    _items.add(name);
    ISKRuntimeWatch.start(name);
  }

  void _endTracing(String? name) {
    if (name == null) {
      developer.log(
        "\n----- BBStatistician:Are you kidding me! The name is null !!! ",
        name: _logTag,
      );
      return;
    }
    _items.remove(name);
    ISKRuntimeWatch.stop(name);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 类型定义
// ─────────────────────────────────────────────────────────────────────────────

typedef DurationCallback = void Function(int durationMills);
typedef VoidCallback = void Function();

// ─────────────────────────────────────────────────────────────────────────────
// 原版 Java 中的空方法（deleteNumAdd / learnNumAdd / reviewNumAdd / updateReviewTask）
// 在 Java 源码中这些方法体为空，保留签名以备后续扩展
// ─────────────────────────────────────────────────────────────────────────────

class BBStatisticianStub {
  static void deleteNumAdd(int i) {}
  static void learnNumAdd(int i) {}
  static void reviewNumAdd(int i) {}
  static void updateReviewTask(int i) {}
}
