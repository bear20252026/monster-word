// 由 Claude 团队生成 | Monster Word App

// 由账号4生成
// 统计/事件层：翻译自 statistics/（v3.2 源码 1:1）
// BBStatistician（统计核心）+ BBUMEvent（事件定义）+ StatisticUtils

/// 统计事件类型（翻译自 BBUMEvent.java 常量）
class BBUMEvent {
  // 学习事件
  static const String learn = 'learn';
  static const String review = 'review';
  static const String wordClick = 'word_click';
  static const String wordPlay = 'word_play';
  static const String sentencePlay = 'sentence_play';
  static const String spellCheck = 'spell_check';
  static const String login = 'login';
  static const String register = 'register';
  static const String syncData = 'sync_data';
  static const String checkIn = 'check_in';
  static const String sharePage = 'share_page';
  static const String bookSelect = 'book_select';
  static const String appLaunch = 'app_launch';
  static const String pageView = 'page_view';
  static const String downloadZpk = 'download_zpk';
  static const String collinsClick = 'collins_click';
  static const String dictClick = 'dict_click';
  static const String wordRootClick = 'word_root_click';
  static const String purchase = 'purchase';
  static const String settingsChange = 'settings_change';

  // 事件参数
  static const String paramWord = 'word';
  static const String paramBookCode = 'book_code';
  static const String paramPageName = 'page_name';
  static const String paramDuration = 'duration';
  static const String paramCount = 'count';
  static const String paramLevel = 'level';
  static const String paramSuccess = 'success';
  static const String paramFail = 'fail';
  static const String paramSource = 'source';
  static const String paramType = 'type';
}

/// 统计器（翻译自 BBStatistician.java：单例，事件上报）
class BBStatistician {
  static final BBStatistician _instance = BBStatistician._();
  factory BBStatistician() => _instance;
  BBStatistician._();

  final List<Map<String, dynamic>> _eventQueue = [];

  /// 上报事件（原版 trackEvent）
  void trackEvent(String eventName, [Map<String, dynamic>? params]) {
    final event = {'event': eventName, 'timestamp': DateTime.now().toIso8601String(), ...?params};
    _eventQueue.add(event);
    _logEvent(event);
  }

  /// 学习开始（原版 trackLearnStart）
  void trackLearnStart(String bookCode, int totalWords) {
    trackEvent(BBUMEvent.learn, {
      BBUMEvent.paramBookCode: bookCode,
      BBUMEvent.paramCount: totalWords,
      'action': 'start',
    });
  }

  /// 学习完成（原版 trackLearnComplete）
  void trackLearnComplete(String bookCode, int studied, int success, int fail, int duration) {
    trackEvent(BBUMEvent.learn, {
      BBUMEvent.paramBookCode: bookCode,
      BBUMEvent.paramCount: studied,
      BBUMEvent.paramSuccess: success,
      BBUMEvent.paramFail: fail,
      BBUMEvent.paramDuration: duration,
      'action': 'complete',
    });
  }

  /// 复习开始
  void trackReviewStart(int totalWords) {
    trackEvent(BBUMEvent.review, {BBUMEvent.paramCount: totalWords, 'action': 'start'});
  }

  /// 复习完成
  void trackReviewComplete(int reviewed, int success, int fail, int duration) {
    trackEvent(BBUMEvent.review, {
      BBUMEvent.paramCount: reviewed,
      BBUMEvent.paramSuccess: success,
      BBUMEvent.paramFail: fail,
      BBUMEvent.paramDuration: duration,
      'action': 'complete',
    });
  }

  /// 单词点击
  void trackWordClick(String word) {
    trackEvent(BBUMEvent.wordClick, {BBUMEvent.paramWord: word});
  }

  /// 发音播放
  void trackWordPlay(String word, {bool isUK = false}) {
    trackEvent(BBUMEvent.wordPlay, {BBUMEvent.paramWord: word, BBUMEvent.paramType: isUK ? 'uk' : 'us'});
  }

  /// 签到
  void trackCheckIn() {
    trackEvent(BBUMEvent.checkIn);
  }

  /// 词书选择
  void trackBookSelect(String bookCode) {
    trackEvent(BBUMEvent.bookSelect, {BBUMEvent.paramBookCode: bookCode});
  }

  /// 应用启动
  void trackAppLaunch() {
    trackEvent(BBUMEvent.appLaunch);
  }

  /// 页面访问
  void trackPageView(String pageName) {
    trackEvent(BBUMEvent.pageView, {BBUMEvent.paramPageName: pageName});
  }

  void _logEvent(Map<String, dynamic> event) {
    // 输出到控制台（原版发送到友盟/统计平台）
    // print('[Stats] ${event['event']}: ${event..keys.where((k) => k != 'event' && k != 'timestamp')}');
  }

  /// 获取所有事件（调试用）
  List<Map<String, dynamic>> get events => List.unmodifiable(_eventQueue);

  /// 清空事件队列
  void clear() => _eventQueue.clear();
}

/// 统计工具（翻译自 StatisticUtils.java）
class StatisticUtils {
  /// 记录学习时长（原版 reportLearnDuration）
  static void reportLearnDuration(int seconds) {
    BBStatistician().trackEvent('learn_duration', {'seconds': seconds});
  }

  /// 记录今日学习完成
  static void reportTodayStudy(int count) {
    BBStatistician().trackEvent('today_study', {'count': count});
  }
}
