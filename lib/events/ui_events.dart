// 由 Claude 团队生成 | 移植自 v3.2 events/UI/主题/网络相关事件
// UI 模块事件：主题变更、网络状态、消息状态、悬浮按钮

// ============================================================
// UIThemeChangedEvent — UI 主题变更事件
// 原版：events/UIThemeChangedEvent.java
// 触发源：设置模块 → 监听者：全局（所有页面应刷新主题）
// ============================================================
class UIThemeChangedEvent {
  final int curUITheme;
  const UIThemeChangedEvent({required this.curUITheme});
}

// ============================================================
// NetStateEvent — 网络状态变更事件
// 原版：events/NetStateEvent.java
// 触发源：网络模块 → 监听者：全局
// ============================================================
class NetStateEvent {
  final bool isAvailable;
  const NetStateEvent({required this.isAvailable});
}

// ============================================================
// MessageStatusEvent — 消息状态变更事件
// 原版：events/MessageStatusEvent.java
// 触发源：消息模块 → 监听者：主界面
// ============================================================
class MessageStatusEvent {
  static const int typeHasNew = 1;

  final int type;
  final int unReadNum;

  const MessageStatusEvent({required this.type, this.unReadNum = 0});

  /// 工厂方法：创建"有新消息"事件
  factory MessageStatusEvent.hasNew(int unReadNum) {
    return MessageStatusEvent(type: typeHasNew, unReadNum: unReadNum);
  }
}

// ============================================================
// FloatButtonActionEvent — 悬浮按钮动作事件
// 原版：events/FloatButtonActionEvent.java
// 触发源：悬浮按钮 → 监听者：主界面
// ============================================================
class FloatButtonActionEvent {
  final FloatButtonAction action;
  const FloatButtonActionEvent({required this.action});
}

/// 悬浮按钮动作类型（对应原版 bean/FloatButtonAction）
enum FloatButtonActionType {
  unknown,
  search,     // 搜索
  settings,   // 设置
  help,       // 帮助
  feedback,   // 反馈
}

/// 悬浮按钮动作数据
class FloatButtonAction {
  final FloatButtonActionType type;
  final String? rawAction;

  const FloatButtonAction({required this.type, this.rawAction});

  /// 从字符串转换（兼容原版 FloatButtonAction.covertFloatButtonAction）
  static FloatButtonAction fromString(String str) {
    final lower = str.toLowerCase();
    FloatButtonActionType type;
    switch (lower) {
      case 'search':
        type = FloatButtonActionType.search;
      case 'settings':
        type = FloatButtonActionType.settings;
      case 'help':
        type = FloatButtonActionType.help;
      case 'feedback':
        type = FloatButtonActionType.feedback;
      default:
        type = FloatButtonActionType.unknown;
    }
    return FloatButtonAction(type: type, rawAction: str);
  }
}
