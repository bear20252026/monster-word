// 由 Claude 团队生成 | 移植自 v3.2 events/ 词书/词库相关事件
// 词库模块事件：词书切换、词书购买成功

// ============================================================
// LibChangedEvent — 词书切换事件
// 原版：events/LibChangedEvent.java
// 触发源：词书选择 → 监听者：学习模块
// 事件类型：SELECT_LIB(1) 选择词书, REMOVE_LIB(2) 移除词书
// ============================================================
class LibChangedEvent {
  static const int selectLib = 1;
  static const int removeLib = 2;

  final int eventType;
  const LibChangedEvent({required this.eventType});
}

// ============================================================
// LibBookBuySucEvent — 词书购买成功事件
// 原版：events/LibBookBuySucEvent.java
// 触发源：支付模块 → 监听者：词书界面
// ============================================================
class LibBookBuySucEvent {
  final String bookCode;
  const LibBookBuySucEvent({required this.bookCode});
}
