// 由 Claude 团队生成 | events 包统一导出
// 移植自 v3.2 cn.com.langeasy.LangEasyLexis.events（共 25 个事件类）
//
// 原版使用 greenrobot EventBus，Flutter 版改用 StreamController.broadcast()
// 通过 EventBus.instance.fire() 发布，EventBus.instance.on<T>() 订阅

// 事件总线
export 'event_bus.dart';

// 学习相关事件（6 个）
export 'learning_events.dart';

// 用户相关事件（6 个）
export 'user_events.dart';

// 词库相关事件（2 个）
export 'lib_events.dart';

// UI/主题/网络相关事件（4 个）
export 'ui_events.dart';

// 媒体/播放相关事件（1 个）
export 'media_events.dart';

// 日历相关事件（2 个，含 CardActionClickInfo）
export 'calendar_events.dart';

// 授权/绑定相关事件（5 个）
export 'grant_events.dart';
